local damage = require("necro.game.system.Damage")
local player = require("necro.game.character.Player")

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local TrapHandler = require("AP.scripts.traps.trapHandler")

local function timerTrap(ev)
    local trapSuccess = false

    for _, entity in ipairs(player.getPlayerEntities()) do
        if not entity or not entity.playableCharacter then goto continue end
        if not entity.AP_damageCountdown then goto continue end

        if entity.AP_damageCountdown.active then
            apFlyaways.addToFlyawayQueue({
                entity = entity,
            })
            trapSuccess = true
            goto continue
        end

        entity.AP_damageCountdown.countdown      = 16
        entity.AP_damageCountdown.damage         = 3
        entity.AP_damageCountdown.countdownReset = 16
        entity.AP_damageCountdown.killerName     = "Timer Trap"
        entity.AP_damageCountdown.type           = damage.Type.TRAP
        entity.AP_damageCountdown.active         = true

        apFlyaways.addToFlyawayQueue({
            entity = entity,
        })

        trapSuccess = true
        ::continue::
    end

    return trapSuccess
end

TrapHandler.register("TimerTrap", timerTrap)

return timerTrap
