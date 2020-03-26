--The chip thread

--TODO: Make sure the parameters explaination is correct after testing them.

--[[
- path (string): The library require path.
- dir (string): The directory of the library.
- channels (number): (unsigned int) The number of channels to have, by default it's 4.
- sampleRate (number): (unsigned int) The sample rate to operate on, by default it's 44100 on PC, and 22050 on mobile.
- bitDepth (number): (unsigned int) The bitdepth of the generated samples, by default it's 8 (for fantasy reasons).
- bufferLength (number): (unsigned float) The length of the buffer in seconds, affects responsivity and pops/clicks, by default it's 1/15.
- piecesCount (number): (unsigned int) The number of pieces to divide the buffer into, affects pops/clicks, by default it's 4.
- inChannels (array of userdata): (love channels) The input channels, recieves data from the main thread, one for each audio channel.
- outChannels (array of userdata): (love channels) The output channels, send data to the main thread, one for each audio channel.
]]
local path, dir, channels, sampleRate, bitDepth, bufferLength, piecesCount, inChannels, outChannels = ...

--Load love modules
require("love.timer")
require("love.sound")
require("love.audio")

--== Load sub modules ==--
local waveforms = love.filesystem.load(dir.."/waveforms.lua")(channels)

--== Localize Lua APIs ==--
local floor, min, max = math.floor, math.min, math.max

--== Constants ==--
local pieceSamplesCount = floor((bufferLength*sampleRate)/piecesCount) --The length of buffer pieces in samples.
local bufferSamplesCount = pieceSamplesCount*piecesCount --The length of the buffer in samples.
--Please note that the bufferSamplesCount is not the same of (bufferLength*sampleRate),
--The buffersSamplesCount makes sure that the buffer is perfect multiplication of the pieceSamplesCount.

--== Variables ==--
local channelStore = {} --Stores each channel parameters.
local soundDatas = {} --The generated soundData pieces.
local currentSoundData = 0 --The index of the sounddata piece to override next.
local queueableSource = love.audio.newQueueableSource(sampleRate, bitDepth, 2, piecesCount) --Create the queueable source.

--== Initialize ==--
math.randomseed(love.timer.getTime()) --Set the random seed, for the noise generators to work.

--Create the buffer's sounddata pieces.
for i=0, piecesCount-1 do
	soundDatas[i] = love.sound.newSoundData(pieceSamplesCount, sampleRate, bitDepth, 2)
end

--Setup the initial channels states
for i=0, channels-1 do
	channelStore[i] = {
		id = i, --The index of the channel
		enabled = false, --Whether the channel is muted or not
		waveform = 0, --The waveform to generate
		panning = 0, --The panning of the channel output, [-1]: Left, [+1]: Right, [0]: Center
		amplitude = 1, --The amplitude of the generated wave
		frequency = 440, --The frequency of the wave to generate
		period = 0, --The period of the wave cycle
		periodStep = 1/(sampleRate/440), --The period step between each sample for the current frequency
		reset = true, --Whether the period has been reset this sample or not

		panningSlideRate = false, --(Number/false) The step to add to the amplitude each second inorder to reach the target
		panningSlideTarget = false, --(Number/false) The target amplitude of the slide

		amplitudeSlideRate = false, --(Number/false) The step to add to the amplitude each second inorder to reach the target
		amplitudeSlideTarget = false, --(Number/false) The target amplitude of the slide

		frequencySlideRate = false, --(Number/false) The step to add to the frequency each second inorder to reach the target
		frequencySlideTarget = false, --(Number/false) The target frequency of the slide

		wait = false --How many sample to wait before applying further commands
	}
end


local function requestCommands(channelID)
	outChannels[channelID]:push("request")
end


--== Parameters Controller ==--

local actions = {}

actions.enable = function(channelData)
	channelData.enabled = true
end
actions.disable = function(channelData)
	channelData.enabled = false
end
actions.frequency = function(channelData, value)
	channelData.frequency = value
	channelData.periodStep = channelData.frequency/sampleRate --1/(sampleRate/channelData.frequency)
end
actions.frequencySlide = function(channelData, value, target)
	channelData.frequencySlideRate = value and value/sampleRate or false
	channelData.frequencySlideTarget = target or false
end
actions.amplitude = function(channelData, value, force)
	if force then --Force set the amplitude without a slide
		channelData.amplitude = value
	else
		--Automatically slide into the new amplitude during 2 milliseconds
		--value/0.002 == value*500 (/0.002 -> / 2/1000 -> * 1000/2 -> * 500)
		channelData.amplitudeSlideTarget = value
		channelData.amplitudeSlideRate = ((value - channelData.amplitude) * 500)/sampleRate
	end
end
actions.amplitudeSlide = function(channelData, value, target)
	channelData.amplitudeSlideRate = value and value/sampleRate or false
	channelData.amplitudeSlideTarget = target or false
end
actions.waveform = function(channelData, value)
	channelData.waveform = value
end
actions.panning = function(channelData, value, force)
	if force then --Force set the panning without a slide
		channelData.panning = value
	else
		--Automatically slide into the new panning during 2 milliseconds
		--value/0.002 == value*500 (/0.002 -> / 2/1000 -> * 1000/2 -> * 500)
		channelData.panningSlideTarget = value
		channelData.panningSlideRate = ((value - channelData.panning) * 500)/sampleRate
	end
end
actions.panningSlide = function(channelData, value, target)
	channelData.panningSlideRate = value and value/sampleRate or false
	channelData.panningSlideTarget = target or false
end
actions.wait = function(channelData, value)
	channelData.wait = value*sampleRate
	return true
end
actions.enableAndWait = function(channelData, value)
	channelData.enabled = true
	channelData.wait = value*sampleRate
	return true
end
actions.request = function(channelData)
	requestCommands(channelData.id)
end

--Return the parameters for the next sample to generate.
--Parameters: The chunnel ID.
--Returns: period, waveform, panning.
local function nextParameters(channelID)
	local channelData = channelStore[channelID]

	local enabled = channelData.enabled
	local waveform = channelData.waveform
	local panning = channelData.panning
	local amplitude = channelData.amplitude
	local period = channelData.period
	local reset = channelData.reset

	local panningSlideRate = channelData.panningSlideRate
	local panningSlideTarget = channelData.panningSlideTarget

	local amplitudeSlideRate = channelData.amplitudeSlideRate
	local amplitudeSlideTarget = channelData.amplitudeSlideTarget

	local frequencySlideRate = channelData.frequencySlideRate
	local frequencySlideTarget = channelData.frequencySlideTarget

	local inChannel = inChannels[channelID]

	if enabled then
		--Panning update--

		if panningSlideRate then
			local nextPanning = channelData.panning + panningSlideRate

			--Check if the slide is complete
			if panningSlideTarget then
				if panningSlideRate > 0 then --Slide up
					if nextPanning >= panningSlideTarget then
						nextPanning = panningSlideTarget
						channelData.panningSlideRate = false
						channelData.panningSlideTarget = false
					end
				else --Slide down
					if nextPanning <= panningSlideTarget then
						nextPanning = panningSlideTarget
						channelData.panningSlideRate = false
						channelData.panningSlideTarget = false
					end
				end
			end

			--Clamp the panning value just in-case
			nextPanning = min(max(-1, nextPanning), 1)

			channelData.panning = nextPanning
		end

		--Amplitude update--
		
		if amplitudeSlideRate then
			local nextAmplitude = channelData.amplitude + amplitudeSlideRate

			--Check if the slide is complete
			if amplitudeSlideTarget then
				if amplitudeSlideRate > 0 then --Slide up
					if nextAmplitude >= amplitudeSlideTarget then
						nextAmplitude = amplitudeSlideTarget
						channelData.amplitudeSlideRate = false
						channelData.amplitudeSlideTarget = false
					end
				else --Slide down
					if nextAmplitude <= amplitudeSlideTarget then
						nextAmplitude = amplitudeSlideTarget
						channelData.amplitudeSlideRate = false
						channelData.amplitudeSlideTarget = false
					end
				end
			end

			--Clamp the amplitude value just in-case
			nextAmplitude = min(max(0, nextAmplitude), 1)

			channelData.amplitude = nextAmplitude
		end

		--Frequency update--

		if frequencySlideRate then
			local nextFrequency = channelData.frequency + frequencySlideRate

			--Check if the slide is complete
			if frequencySlideTarget then
				if frequencySlideRate > 0 then --Slide up
					if nextFrequency >= frequencySlideTarget then
						nextFrequency = frequencySlideTarget
						channelData.frequencySlideRate = false
						channelData.frequencySlideTarget = false
					end
				else --Slide down
					if nextFrequency <= frequencySlideTarget then
						nextFrequency = frequencySlideTarget
						channelData.frequencySlideRate = false
						channelData.frequencySlideTarget = false
					end
				end
			end

			--Clamp the frequency value just in-case
			nextFrequency = min(max(0, nextFrequency), 20000)

			channelData.frequency = nextFrequency
			channelData.periodStep = channelData.frequency/sampleRate
		end
	end

	if channelData.wait then
		local command = inChannel:peek()
		if command and command[1] == "interrupt" then --Check if there is an interrupt
			channelData.wait = false
		else --Decrease the wait time until it reaches 0
			channelData.wait = channelData.wait - 1
			if channelData.wait <= 0 then channelData.wait = false end
		end
	end

	if not channelData.wait then --Execute further commands
		local command = inChannel:pop()

		while command do
			local action, value, other = command[1], command[2], command[3]

			print("Command", action, value, other)

			local actionFunc = actions[action]
			local waiting = false
			if actionFunc 
				and actionFunc(channelData, value, other) then break end

			command = inChannel:pop()
		end
	end

	--==Parameters update==--

	if not enabled then return 0, false, -1, 0, 0 end

	--Pariod update--

	channelData.reset = false

	local nextPeriod = period + channelData.periodStep
	if nextPeriod >= 1 then --Reset the period once it reaches 1
		nextPeriod = nextPeriod-floor(nextPeriod)
		channelData.reset = true
	end
	channelData.period = nextPeriod

	return period, reset, waveform, panning, amplitude
end

--== Thread Loop ==--
while true do
	--Override played sounddatas
	for i=1, queueableSource:getFreeBufferCount() do
		local soundData = soundDatas[currentSoundData] --The sounddata to override
		currentSoundData = (currentSoundData+1)%piecesCount --The id of the next sounddata to override

		--Loop for each sample in this sounddata
		for j=0, pieceSamplesCount-1 do
			local leftSample, rightSample = 0, 0 --Holds the sum of all the channels for each side

			for k=0, channels-1 do --K is the current channel we're generating
				--Get the parameters
				local period, reset, waveform, panning, amplitude = nextParameters(k)
				
				--Generate the sample
				local sample = waveforms[waveform](period, reset, k)*amplitude

				--Sum the channel values
				panning = (panning+1)*0.5
				leftSample = leftSample + sample*(1-panning)
				rightSample = rightSample + sample*panning
			end

			leftSample = max(min(leftSample,1),-1) --Clamp the sum
			rightSample = max(min(rightSample,1),-1) --Clamp the sum

			--Set the samples
			soundData:setSample(j,1,leftSample) --Left
			soundData:setSample(j,2,rightSample) --Right
		end

		queueableSource:queue(soundData) --Queue the overridden sounddata
	end

	queueableSource:play() --Make sure that the queueableSource is playing.

	--TODO: The sleep time should be dynamic
	love.timer.sleep(bufferLength/4) --Give the CPU some reset
end