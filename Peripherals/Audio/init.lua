local perpath = select(1,...) --The path to the FDD folder

local json = require("Engine.JSON")
local coreg = require("Engine.coreg")
local events = require("Engine.events")

return function(config)
  
  local sfxr = love.filesystem.load(perpath.."sfxr.lua")()
  local thread = love.thread.newThread(perpath.."loadthread.lua")
  local chIn, chOut = love.thread.newChannel(), love.thread.newChannel()
  
  local LoadJob = false
  
  thread:start(perpath, chIn, chOut)
  
  events:register("love:reboot", function()
    chIn:push("stop")
  end)
  
  events:register("love:quit", function()
    chIn:supply("stop")
    thread:wait()
  end)
  
  local au, devkit, indirect = {}, {}, {"newGenerator"}
  
  function au.newGenerator(p)
    
    if type(p) ~= "table" then return false, "Parameters should be a table, provided: "..type(p) end
    
    local params = {
      repeatspeed = 0,
      waveform = 0, --*
      envelope = {
        attack = 0,
        sustain = 0.3,
        punch = 0,
        decay = 0.4
      },
      frequency = {
        start = 0.3,
        min = 0,
        slide = 0, --
        dslide = 0 --
      },
      vibrato = {
        depth = 0,
        speed = 0
      },
      change = {
        amount = 0, --
        speed = 0
      },
      duty = {
        ratio = 0,
        sweep = 0 --
      },
      phaser = {
        offset = 0, --
        sweep = 0
      },
      lowpass = {
        cutoff = 1,
        sweep = 0, --
        resonance = 0
      },
      highpass = {
        cutoff = 0,
        sweep = 0 --
      }
    }
    
    for k1,v1 in pairs(p) do
      if type(v1) == "table" and type(params[k1]) == "table" then
        for k2,v2 in pairs(v1) do
          if type(v2) == "number" and type(params[k1][k2]) == "number" then
            params[k1][k2] = v2
          end
        end
      elseif type(v1) == "number" then
        if type(params[k1]) == "number" then
          params[k1] = v1
        end
      end
    end
    
    local job = json:encode(params)
    
    chIn:push(job)
    
    LoadJob = true
    
    return 2
    
  end
  
  events:register("love:update", function(dt)
    
    local terr = thread:getError()
    if terr then
      error("Thread: "..terr)
    end
    
    if LoadJob then
      
      local sounddata = chOut:pop()
      if sounddata then
        
        LoadJob = false
        
        coreg:resumeCoroutine(true, function()
          
          local source = love.audio.newSource(sounddata)
          
          return function()
            source:play()
          end
          
        end)
        
      end
    end
    
  end)
  
  function au.newSound()
    
    local s = {} --The sound object.
    local sounddata
    
    local params = {
      repeatspeed = 0,
      waveform = 0, --*
      envelope = {
        attack = 0,
        sustain = 0.3,
        punch = 0,
        decay = 0.4
      },
      frequency = {
        start = 0.3,
        min = 0,
        slide = 0, --
        dslide = 0 --
      },
      vibrato = {
        depth = 0,
        speed = 0
      },
      change = {
        amount = 0, --
        speed = 0
      },
      duty = {
        ratio = 0,
        sweep = 0 --
      },
      phaser = {
        offset = 0, --
        sweep = 0
      },
      lowpass = {
        cutoff = 1,
        sweep = 0, --
        resonance = 0
      },
      highpass = {
        cutoff = 0,
        sweep = 0 --
      }
    }
    
    function s:get(field)
      if type(field) ~= "string" then return error("Field should be a string, provided: "..type(field)) end
      
      local i, sub = field:match("(.+)%.(.+)")
      if i then
        if type(params[i]) ~= "table" then
          return error("Field doesn't exists.")
        else
          if type(params[i][sub]) ~= "number" then
            return error("Field doesn't exists")
          else
            return params[i][sub]
          end
        end
      else
        if type(params[field]) ~= "number" then
          return error("Field doesn't exists.")
        end
        
        return params[field]
      end
    end
    
    function s:set(field,value)
      if type(field) ~= "string" then return error("Field should be a string, provided: "..type(field)) end
      if type(value) ~= "number" then return error("Value should be a number, provided: "..type(value)) end
      
      local i, sub = field:match("(.+)%.(.+)")
      if i then
        if type(params[i]) ~= "table" then
          return error("Field doesn't exists.")
        else
          if type(params[i][sub]) ~= "number" then
            return error("Field doesn't exists")
          end
          
          if params[i][sub] ~= value then
            sounddata = false
          end
          params[i][sub] = value
        end
      else
        if type(params[field]) ~= "number" then
          return error("Field doesn't exists.")
        end
        
        if params[field] ~= value then
          sounddata = nil
        end
        params[field] = value
      end
    end
    
    function s:generate()
      if sounddata then return end
      
    end
    
    function s:play()
      self:generate()
      
      local source = love.audio.newSource(sounddata)
      source:play()
    end
    
  end
  
  function au.playRandom()
    
    local sound = sfxr.newSound()
    sound:randomize()
    local sounddata = sound:generateSoundData()
    local source = love.audio.newSource(sounddata)
    source:play()
    
    return true
    
  end
  
  return au, devkit, indirect
  
end