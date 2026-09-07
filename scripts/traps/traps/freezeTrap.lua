local freeze = require "necro.game.character.Freeze"

local trapSystem = require "AP.scripts.traps.trapSystem"

local FREEZE_TURNS = 10

---Ice and Stone are the same stun mechanically; the variant is flavor.
trapSystem.define({
    name     = "FreezeTrap",
    variants = {
        Ice   = { flyaway = "Freeze!", sound = "spellFreeze", freezeType = freeze.Type.ICE },
        Stone = { flyaway = "Stoned!", sound = "gorgonStone", freezeType = freeze.Type.STONE },
    },
    apply    = function(ctx)
        local entity = ctx.entity
        if not entity.freezable then return false end
        if freeze.isFrozen(entity) then return false end

        freeze.inflict(entity, FREEZE_TURNS, ctx.variant.freezeType)
    end,
})
