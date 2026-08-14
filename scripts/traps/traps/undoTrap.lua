local currentLevel = require "necro.game.level.CurrentLevel"
local gameSession  = require "necro.client.GameSession"
local sound        = require "necro.audio.Sound"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

TrapHandler.register("UndoTrap", makeSimpleTrap({
    flyawayText   = "Undo!",
    sound         = "trapDice",
    alwaysSucceed = true,
    after         = function() gameSession.goToLevel(currentLevel.getNumber()) end,
}))
