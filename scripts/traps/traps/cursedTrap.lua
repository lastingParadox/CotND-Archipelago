local health = require("necro.game.character.Health")
local sound  = require("necro.audio.Sound")

local trapSystem = require("AP.scripts.traps.trapSystem")

trapSystem.define({
    name    = "CursedTrap",
    flyaway = "Cursed!",
    apply   = function(ctx)
        local entity = ctx.entity
        if not (entity.health and entity.cursedHealth) then return false end

        local cursedAmount = health.curseHealth(entity)
        if not (cursedAmount and cursedAmount > 0) then return false end

        sound.playFromEntity("trapDice", entity)
    end,
})
