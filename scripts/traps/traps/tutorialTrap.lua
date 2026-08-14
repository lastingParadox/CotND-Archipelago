local tutorialLevel = require "necro.game.data.level.TutorialLevel"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

TrapHandler.register("TutorialTrap", makeSimpleTrap({
    flyawayText = "Tutorial time!",
    after       = function() tutorialLevel.start() end,
}))
