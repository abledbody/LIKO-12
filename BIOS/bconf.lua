--The bios configuration file.
--per ,err = P(peripheral,mountedName,configTable)

--Ignore unused variables for this file, and set the globals.
--luacheck: globals P PA _OS, ignore 211

--Create a new cpu mounted as "CPU"
local CPU, yCPU, CPUKit = PA("CPU")

--Create a new gpu mounted as "GPU"
local GPU, yGPU, GPUKit = PA("GPU","GPU",{
  _ColorSet = {
   {20, 21, 24, 255},--Black
   {41, 49, 71, 255},--Dark Blue
   {97, 27, 40, 255},--Maroon
   {48, 89, 8,  255},--Dark Green
   {144,93, 67, 255},--Brown
   {76, 76, 81, 255},--Dark Gray
   {137,136,130,255},--Bright Grey
   {255,251,234,255},--White
   {187,27, 22, 255},--Red
   {255,111,19, 255},--Orange
   {255,236,98, 255},--Yellow
   {127,168,70, 255},--Green
   {141,184,213,255},--Cyan
   {92, 71, 185,255},--Blue
   {241,99, 145,255},--Pink
   {245,191,140,255} --Tan
  },
  _ClearOnRender = true, --Speeds up rendering, but may cause glitches on some devices !
  CPUKit = CPUKit
})

local LIKO_W, LIKO_H = GPUKit._LIKO_W, GPUKit._LIKO_H
local ScreenSize = (LIKO_W/2)*LIKO_H

--Create Audio peripheral
PA("Audio")

--Create gamepad contols
PA("Gamepad","Gamepad",{CPUKit = CPUKit})

--Create Touch Controls
PA("TouchControls","TC",{CPUKit = CPUKit, GPUKit = GPUKit})

--Create a new keyboard api mounted as "KB"
PA("Keyboard","Keyboard",{CPUKit = CPUKit, GPUKit = GPUKit,_Android = (_OS == "Android"),_EXKB = false})

--Create a new virtual hdd system mounted as "HDD"
PA("HDD","HDD",{
  Drives = {
    C = 1024*1024 * 50, --Measured in bytes, equals 50 megabytes
    D = 1024*1024 * 50 --Measured in bytes, equals 50 megabytes
  }
})

local KB = function(v) return v*1024 end

local RAMConfig = {
  layout = {
    {ScreenSize,GPUKit.VRAMHandler}, --0x0 -> 0x2FFF - The Video ram
    {ScreenSize,GPUKit.LIMGHandler}, --0x3000 -> 0x5FFF - The Label image
    {KB(64)}  --0x6000 -> 0x15FFF - The floppy RAM
  }
}

local RAM, yRAM, RAMKit = PA("RAM","RAM",RAMConfig)

PA("FDD","FDD",{
  GPUKit = GPUKit,
  RAM = RAM,
  DiskSize = KB(64),
  FRAMAddress = 0x6000
})

local WEB, yWEB, WEBKit = PA("WEB","WEB",{CPUKit = CPUKit})