local sizeModifier = require "necro.game.character.SizeModifier"

local trapSystem = require "AP.scripts.traps.trapSystem"

local SHRINK_TURNS = 12

trapSystem.define({
    name    = "ShrinkTrap",
    flyaway = "Shrunk!",
    sound   = "potionBlue",
    apply   = function(ctx)
        if not ctx.entity.dwarfism then return false end
        sizeModifier.shrink(ctx.entity, SHRINK_TURNS)
    end,
})
