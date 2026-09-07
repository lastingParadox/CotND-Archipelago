local currentLevel = require "necro.game.level.CurrentLevel"
local gameSession  = require "necro.client.GameSession"

local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name    = "UndoTrap",
    flyaway = "Undo!",
    sound   = "trapDice",
    finish  = function() gameSession.goToLevel(currentLevel.getNumber()) end,
})
