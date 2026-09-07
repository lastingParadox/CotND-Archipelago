local APFlags    = require("AP.scripts.utils.flags")
local trapSystem = require("AP.scripts.traps.trapSystem")

local COUNTDOWN = 16
local DAMAGE    = 1

-- The countdown component keeps its own lifetime, so the trap holds no state.
trapSystem.define({
    name    = "TimerTrap",
    flyaway = "Timer!",
    apply   = function(ctx)
        local entity = ctx.entity
        if not entity.AP_damageCountdown then return false end
        if entity.AP_damageCountdown.active then return end

        entity.AP_damageCountdown.countdown      = COUNTDOWN
        entity.AP_damageCountdown.damage         = DAMAGE
        entity.AP_damageCountdown.countdownReset = COUNTDOWN
        entity.AP_damageCountdown.killerName     = "Timer Trap"
        entity.AP_damageCountdown.type           = APFlags.DAMAGE_AP_TRAP
        entity.AP_damageCountdown.active         = true
    end,
})
