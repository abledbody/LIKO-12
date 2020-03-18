--LSynth by RamiLego4Game & LIKO-12's Organization
--The portable fantasy audio chip made for LIKO-12 which could be used in any LÖVE project.

--[[
Required love modules:
love.thread

Optional love modules:
love.system (Used to know if running on mobile)

Love modules used by threads:
love.timer (Used to calculate the sleeping time)
love.sound (Used for creating sounddatas)
love.audio (Used for playing the generated sounddatas)
]]

local path = (...) --The library require path.
local dir = string.gsub(path, "%.", "/") --The directory of the library.

local LSynth = {}

--==Private Fields==--
--Those fields should not be modified by external code.

LSynth.initialized = false --Has the LSynth chip been initialized ?
LSynth.isMobile = false --Is the chip running on a mobile device ?

LSynth.channels = 4 --Default channels count.
LSynth.sampleRate = 44100 --Default sample rate (samples per second), 22050 on mobile (if detected).
LSynth.bitDepth = 8 --Default sample bitdepth, 8 for fantasy reasons, could be either 8 or 16.
LSynth.bufferLength = 1/15 --Default buffer length (in seconds).
LSynth.piecesCount = 4 --Default count of buffer pieces (affects responsivity).

LSynth.thread = nil --The LSynth chip thread.
LSynth.outChannels = {} --The channels which sends data into the LSynth thread, each audio channel has one.

--==Public Methods==--

--[[ Initialize the LSynth chip.
Call before any other method !

Arguments:
- channels (number/nil): (unsigned int) The number of channels to have, by default it's 4.
- sampleRate (number/nil): (unsigned int) The sample rate to operate on, by default it's 44100 on PC, and 22050 on mobile.
- bitDepth (number/nil): (unsigned int) The bit depth of the generated samples, by default it's 8 (for fantasy reasons).
- bufferLength (number/nil): (unsigned float) The length of the buffer in seconds, by default it's 1/60.
- piecesCount (number/nil): (unsigned int) The number of pieces to divide the buffer into, affects responsivity, by default it's 4.
]]
function LSynth:initialize(channels, sampleRate, bitDepth, bufferLength, piecesCount)
	if self.initialized then error("Already initialized!") end

	--Check if running on mobile, if love.system is available.
	self.isMobile = love.system and ((love.system.getOS() == "Android") or (love.system.getOS() == "iOS"))

	--Lower the sample rate if running on mobile.
	if self.isMobile then LSynth.sampleRate = 22050 end

	--Override the channels count.
	if channels then self.channels = channels end
	--Override the sample rate.
	if sampleRate then self.sampleRate = sampleRate end
	--Override the bitdepth.
	if bitDepth then self.bitDepth = bitDepth end
	--Override the buffer length.
	if bufferLength then self.bufferLength = bufferLength end
	--Override the pieces count.
	if piecesCount then self.piecesCount = piecesCount end
	
	--Create the communication channels
	for i=0, self.channels-1 do self.outChannels[i] = love.thread.newChannel() end

	--Load the thread
	self.thread = love.thread.newThread(dir.."/thread.lua")
	--Start the thread
	self.thread:start(path, dir, self.channels, self.sampleRate, self.bitDepth, self.bufferLength, self.piecesCount, self.outChannels)

	self.initialized = true
end

--Set the waveform of a channel
function LSynth:setWaveform(channel, waveform)
	return self.outChannels[channel]:push({"waveform", waveform})
end

--Force set the panning of a channel
function LSynth:forceSetPanning(channel, panning)
	return self.outChannels[channel]:push({"panning", panning, true})
end

--Set the panning of a channel
function LSynth:setPanning(channel, panning)
	return self.outChannels[channel]:push({"panning", panning})
end

--Set a panning slide effect for a channel
function LSynth:setPanningSlide(channel, stepPerSecond, target)
	return self.outChannels[channel]:push({"panningSlide", stepPerSecond, target})
end

--Set the frequency of a channel
function LSynth:setFrequency(channel, frequency)
	return self.outChannels[channel]:push({"frequency", frequency})
end

--Set a frequency slide effect for a channel
function LSynth:setFrequencySlide(channel, hzPerSecond, target)
	return self.outChannels[channel]:push({"frequencySlide", hzPerSecond, target})
end

--Force set the amplitude of a channel
function LSynth:forceSetAmplitude(channel, amplitude)
	return self.outChannels[channel]:push({"amplitude", amplitude, true})
end

--Set the amplitude of a channel
function LSynth:setAmplitude(channel, amplitude)
	return self.outChannels[channel]:push({"amplitude", amplitude})
end

--Set an amplitude slide effect for a channel
function LSynth:setAmplitudeSlide(channel, stepPerSecond, target)
	return self.outChannels[channel]:push({"amplitudeSlide", stepPerSecond, target})
end

--Enable a channel's output
function LSynth:enable(channel)
	return self.outChannels[channel]:push({"enable"})
end

--Disable a channel's output
function LSynth:disable(channel)
	return self.outChannels[channel]:push({"disable"})
end

--Enable a channel and wait some time before executing the next command
function LSynth:enableAndWait(channel, time)
	return self.outChannels[channel]:push({"enableAndWait", time})
end

--Tell a channel to wait some time before executing the next command
function LSynth:wait(channel, time)
	return self.outChannels[channel]:push({"wait", time})
end

--Interrupt a channel, clears the commands queue and cancels any wait command
function LSynth:interrupt(channel)
	self.outChannels[channel]:clear()
	return self.outChannels[channel]:push({"interrupt"})
end

--== Hooks ==--

--love.update
function LSynth:update(dt)
	if not self.initialized then error("The chip has not been initialized yet!") end
end

return LSynth