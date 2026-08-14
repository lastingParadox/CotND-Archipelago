local voice = require "necro.audio.Voice"

local makeFloorTrap = (require "AP.scripts.traps.factories.makeFloorTrap").makeFloorTrap
local TrapHandler   = require "AP.scripts.traps.trapHandler"

TrapHandler.register("IceFloorTrap", makeFloorTrap({
    name        = "IceFloorTrap",
    tileType    = "Ice",
    flyawayText = "Ice Floor!",
    duration    = 16,
    voice       = "voiceConfused",
}))
