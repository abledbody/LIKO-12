--The bios configuration file.
--per ,err = P(peripheral,mountedName,configTable)

--Ignore unused variables for this file, and set the globals.
--luacheck: globals P PA _OS, ignore 211

--Create a new cpu mounted as "CPU"
local CPU, yCPU, CPUKit = PA("CPU")

--Create a new gpu mounted as "GPU"
local GPU, yGPU, GPUKit = PA("GPU","GPU",{
  _ColorSet = {
   {5,  5,  6,  255},--Black
   {25, 39, 57, 255},--Dark Blue
   {85, 24, 35, 255},--Maroon
   {36, 76, 7,  255},--Dark Green
   {136,81, 53, 255},--Brown
   {69, 69, 76, 255},--Dark Gray
   {144,143,136,255},--Bright Grey
   {255,251,232,255},--White
   {182,10, 4,  255},--Red
   {255,110,17, 255},--Orange
   {255,236,98, 255},--Yellow
   {122,161,67, 255},--Green
   {139,182,210,255},--Cyan
   {90, 69, 180,255},--Blue
   {240,99, 145,255},--Pink
   {244,190,139,255} --Tan
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