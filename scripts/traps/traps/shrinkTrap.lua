local sizeModifier = require "necro.game.character.SizeModifier"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local SHRINK_TURNS = 12

TrapHandler.register("ShrinkTrap", makeSimpleTrap({
    flyawayText = "Shrunk!",
    sound       = "potionBlue",
    guard       = function(entity) return entity.dwarfism end,
    action      = function(entity) sizeModifier.shrink(entity, SHRINK_TURNS) end,
}))
