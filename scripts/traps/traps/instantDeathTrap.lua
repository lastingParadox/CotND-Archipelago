local damage = require "necro.game.system.Damage"
local sound  = require "necro.audio.Sound"

local apFlags    = require "AP.scripts.utils.flags"
local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name    = "InstantDeathTrap",
    flyaway = "Instant Death!",
    start   = function() sound.playUI("necrodancerLaugh") end,
    apply   = function(ctx)
        damage.inflict({
            victim     = ctx.entity,
            damage     = 999,
            type       = apFlags.DAMAGE_DEATH_LINK,
            killerName = "Instant Death Trap",
        })
    end,
})
