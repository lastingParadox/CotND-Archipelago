local APFlags    = require("AP.scripts.utils.flags")
local trapSystem = require("AP.scripts.traps.trapSystem")

local COUNTDOWN = 16
local DAMAGE    = 1

-- The countdown component keeps its own lifetime, so the trap holds no state.
trapSystem.define({
    name    = "TimerTrap",
    flyaway = "Timer!",
    apply   = function(ctx)
        local countdown = ctx.entity.AP_timerCountdown
        if not countdown then return false end
        if countdown.active then return end

        countdown.countdown      = COUNTDOWN
        countdown.damage         = DAMAGE
        countdown.countdownReset = COUNTDOWN
        countdown.killerName     = "Timer Trap"
        countdown.type           = APFlags.DAMAGE_AP_TRAP
        countdown.active         = true
    end,
})
