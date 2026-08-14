local confusion = require("necro.game.character.Confusion")
local player    = require("necro.game.character.Player")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

TrapHandler.register("ConfusionTrap", makeSimpleTrap({
    flyawayText = "Confusion!",
    guard  = function(entity) return not confusion.isConfused(entity) end,
    action = function(entity) confusion.inflict(entity, 24) end,
}))
