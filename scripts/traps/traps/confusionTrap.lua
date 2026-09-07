local confusion = require("necro.game.character.Confusion")

local trapSystem = require("AP.scripts.traps.trapSystem")

trapSystem.define({
    name    = "ConfusionTrap",
    flyaway = "Confusion!",
    apply   = function(ctx)
        if confusion.isConfused(ctx.entity) then return false end
        confusion.inflict(ctx.entity, 24)
    end,
})
