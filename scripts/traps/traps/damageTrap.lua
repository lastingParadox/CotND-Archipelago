local damage        = require("necro.game.system.Damage")
local invincibility = require("necro.game.character.Invincibility")
local player        = require("necro.game.character.Player")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

-- Spawn protection and i-frames suppress a TRAP hit outright.
local function isProtected(entity)
    if entity.spawnInvincibility and entity.spawnInvincibility.active then return true end
    return invincibility.isActive(entity)
end

TrapHandler.register("DamageTrap", makeSimpleTrap({
    flyawayText = "Ouch!",
    -- Defer the whole trap rather than hitting only the unprotected players.
    setup = function()
        for _, entity in ipairs(player.getPlayerEntities()) do
            if entity.playableCharacter and isProtected(entity) then return false end
        end
    end,
    action = function(entity)
        damage.inflict({
            victim     = entity,
            damage     = 1,
            type       = damage.Type.TRAP,
            killerName = "Damage Trap",
        })
    end,
}))
