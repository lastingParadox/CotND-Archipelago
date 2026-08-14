local health = require("necro.game.character.Health")
local sound  = require("necro.audio.Sound")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

TrapHandler.register("CursedTrap", makeSimpleTrap({
    flyawayText = "Cursed!",
    guard  = function(entity) return entity.health and entity.cursedHealth end,
    action = function(entity)
        local cursedAmount = health.curseHealth(entity)
        if not (cursedAmount and cursedAmount > 0) then return false end
        sound.playFromEntity("trapDice", entity)
    end,
}))
