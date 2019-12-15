--Waveforms samples generators
local waveforms = {}

local channels = ... --The amount of channels

--[[
Supported waveforms:
--------------------

0 Sine
1 Triangle
2 Half-Rectified Sine
3 Square
4 Pulse
5 Saw
6 Noise
7 Custom

About Waveform data argument:
-----------------------------
Contains custom data for the waveform, used for the custom waveform ONLY.

The dataLength is the count of elements in the data array.
]]

--== Localized Lua APIs ==--
local sin, floor, random = math.sin, math.floor, math.random

--== Shared Constants ==--
local pi, pi2 = math.pi, math.pi*2

--None
waveforms[-1] = function(period)
	return 0
end

--Sine
waveforms[0] = function(period)
	return sin(period*pi2)
end

--Triangle
waveforms[1] = function(period)
	period = period < 0.75 and period+0.25 or period-0.75
	return period < 0.5 and period*4-1 or 1-(period-0.5)*4
end

--Half-Rectified Sine
waveforms[2] = function(period)
	return period < 0.5 and sin(period*pi2) or 0
end

--Square
waveforms[3] = function(period)
	return period < 0.5 and 1 or -1
end

--Pulse
waveforms[4] = function(period)
	return period < 0.25 and 1 or -1
end

--Saw
waveforms[5] = function(period)
	period = period < 0.5 and period+0.5 or period-0.5
	return period*2-1
end

--== Noise Variables ==--
local noisePeriodOffsets = {}
local noiseValues = {}

for channel=0, channels-1 do
	noisePeriodOffsets[channel] = 0
	noiseValues[channel] = 0
end

--Noise
waveforms[6] = function(period, reset, channel)
	if reset then noisePeriodOffsets[channel] = 0 end --Reset at each new cycle

	--2 is the noise rate modifier, defines how many times the sample value will change in each noise cycle
	period = period*2 - noisePeriodOffsets[channel]

	if period >= 0 then
		noiseValues[channel] = random()*2-1 --New random value
		noisePeriodOffsets[channel] = noisePeriodOffsets[channel]+floor(period)+1 --Update the offset
	end

	return noiseValues[channel]
end

--Custom
waveforms[7] = function(period, reset, channel, data, dataLength)
	return data[1+floor(period*dataLength)]
end

return waveforms