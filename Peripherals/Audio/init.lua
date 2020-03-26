local perpath = ... --The path to the Audio folder

local events = require("Engine.events")
local chip = require("Peripherals.Audio.LSynth")


return function(config)
	local CPUKit = config.CPUKit

	local function requestCallback(channel)
		--events.trigger("audio:audiorequest", channel)
		if CPUKit then CPUKit.triggerEvent("audiorequest", channel) end
	end

  chip:initialize(requestCallback)
  
  local function panic()
    for i=0,3 do
      chip:interrupt(i)
      chip:disable(i)
    end
  end
  
  events.register("love:reboot", panic)
  events.register("love:quit", panic)
  
  local function chipUpdate(dt)
	chip:update(dt)
  end
  events.register("love:update", chipUpdate)
  
  local AU, yAU, devkit = {}, {}, {}
  
  AU.chip = chip
  
  AU.panic = panic
  
  function AU.play(sfx,chn,queue)
    
    if type(sfx) ~= "table" then return error("SFX data should be a table, provided: "..type(sfx)) end
    if #sfx % 4 > 0 then return error("The SFX data is missing some values.") end
    for k,v in ipairs(sfx) do
      if type(k) ~= "number" then
        return error("SFX Data shouldn't contain any non-number indexes ["..tostring(k).."]")
      end
      
      if type(v) ~= "number" then
        return error("SFX Data [#"..k.."] should be a number, provided: "..type(v))
      end
    end
    
    local data = {}
    for k,v in ipairs(sfx) do
      data[k] = v
    end
    
    chn = chn or 0
    
    if type(chn) ~= "number" then return error("Channel should be a number or a nil, provided: "..type(chn)) end
    
    chn = math.floor(chn)
    
    if chn < 0 or chn > 3 then return error("Channel is out of range ("..chn.."), should be in [0,3]") end
	
	if not queue then
		chip:interrupt(chn)
	end
	chip:enable(chn)
    
    for i = 1, #data, 4 do
	  local dur,wav,freq,amp = data[i],data[i+1],data[i+2],data[i+3]
	  
	  if wav == 6 then freq = freq * 4 end --Noise gets three times the frequency.
	  
	  if i == 1 then chip:request(chn) end
      chip:setWaveform(chn, wav)
	  chip:setAmplitude(chn, amp*amp)
      chip:setFrequency(chn, freq)
	  chip:wait(chn, dur)
	end

    chip:setAmplitude(chn, 0)
    chip:disable(chn)
  end
  
  return AU, yAU, devkit
  
end