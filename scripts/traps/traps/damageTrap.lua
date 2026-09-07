local damage        = require("necro.game.system.Damage")
local invincibility = require("necro.game.character.Invincibility")

local APFlags    = require "AP.scripts.utils.flags"
local trapSystem = require "AP.scripts.traps.trapSystem"

local function isProtected(entity)
    if entity.spawnInvincibility and entity.spawnInvincibility.active then return true end
    return invincibility.isActive(entity)
end

trapSystem.define({
    name    = "DamageTrap",
    flyaway = "Ouch!",
    -- Defer the whole trap rather than hitting only the unprotected players.
    guard   = function(ctx)
        for _, entry in ipairs(ctx.players) do
            if isProtected(entry.entity) then return false end
        end
    end,
    apply   = function(ctx)
        damage.inflict({
            victim     = ctx.entity,
            damage     = 1,
            type       = APFlags.DAMAGE_AP_TRAP,
            killerName = "Damage Trap",
        })
    end,
})
