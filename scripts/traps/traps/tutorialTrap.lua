local tutorialLevel = require "necro.game.data.level.TutorialLevel"

local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name    = "TutorialTrap",
    flyaway = "Tutorial time!",
    finish  = function() tutorialLevel.start() end,
})
