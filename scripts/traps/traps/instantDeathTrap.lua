local damage = require "necro.game.system.Damage"
local sound  = require "necro.audio.Sound"

local apFlags        = require "AP.scripts.utils.flags"
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

TrapHandler.register("InstantDeathTrap", makeSimpleTrap({
    flyawayText = "Instant Death!",
    before      = function() sound.playUI("necrodancerLaugh") end,
    action      = function(entity)
        damage.inflict({
            victim     = entity,
            damage     = 999,
            type       = apFlags.DAMAGE_DEATH_LINK,
            killerName = "Instant Death Trap",
        })
    end,
}))
