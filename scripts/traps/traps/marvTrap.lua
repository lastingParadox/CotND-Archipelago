local rng   = require "necro.game.system.RNG"
local sound = require "necro.audio.Sound"

local APFlags         = require "AP.scripts.utils.flags"
local apFollowerChain = require "AP.scripts.character.apFollowerChain"
local trapSystem      = require "AP.scripts.traps.trapSystem"

local KILLER_NAME = "Marv Trap"
local WARN_SOUND  = "lambBaa"

-- Cumulative thresholds out of 100: usually one Marv, rarely a line of three.
local COUNT_WEIGHTS = { { 1, 65 }, { 2, 90 }, { 3, 100 } }

local function rollCount(channel)
    local roll = rng.range(1, 100, channel)

    for _, entry in ipairs(COUNT_WEIGHTS) do
        if roll <= entry[2] then return entry[1] end
    end

    return 1
end

-- Marvs named after the trap, dealing trap damage rather than DeathLink damage.
trapSystem.define({
    name    = "MarvTrap",
    flyaway = "Protect your flock!",
    apply   = function(ctx)
        local entity = ctx.entity
        if not entity.inventory then return false end

        local sounds = entity.name == "Mary"
            and { "maryGrief1", "maryGrief2", "maryGrief3", "maryGrief4" }
            or  { string.lower(tostring(entity.name)) .. "Hurt" }

        local spawned = 0

        for _ = 1, rollCount(ctx.channel) do
            local marv = apFollowerChain.appendChainFollower(entity, "Marv", 0, 0)
            if not marv then break end

            local comp = marv.AP_followerDamageParentWhileDead
            comp.killerName = KILLER_NAME
            comp.sounds     = sounds
            comp.type       = APFlags.DAMAGE_AP_TRAP

            spawned = spawned + 1
        end

        if spawned == 0 then return false end

        sound.playFromEntity(WARN_SOUND, entity)
    end,
})
