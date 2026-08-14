local ecs      = require "system.game.Entities"
local snapshot = require "necro.game.system.Snapshot"

local apTrapStatus   = require "AP.scripts.ui.apTrapStatus"
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local ONE_HIT_LIMIT = 1

-- Rollback-managed, or it drifts from the health it describes.
apOneHitSavedState = snapshot.variable({}, true)

apTrapStatus.register("OneHitTrap", function(entity)
    return apOneHitSavedState[entity.id] and "One Hit!" or nil
end)

event.objectHeal.add("APOneHitTrapEnforceLimit", { filter = "health", order = "end" }, function(ev)
    if not apOneHitSavedState[ev.entity.id] then return end
    if ev.entity.health.maxHealth > ONE_HIT_LIMIT then
        ev.entity.health.maxHealth = ONE_HIT_LIMIT
    end
    if ev.entity.health.health > ONE_HIT_LIMIT then
        ev.entity.health.health = ONE_HIT_LIMIT
    end
end)

event.gameStateLevel.add("APOneHitTrapRestoreOnLevel", { order = "splitScreen" }, function()
    for id, state in pairs(apOneHitSavedState) do
        local entity = ecs.getEntityByID(id)
        if entity and entity.health then
            entity.health.maxHealth = state.maxHealth
            if entity.health.health > entity.health.maxHealth then
                entity.health.health = entity.health.maxHealth
            end
        end
    end
    apOneHitSavedState = {}
end)

event.gameStateReset.add("APOneHitTrapClearOnReset", { order = "resetRunVariables" }, function()
    apOneHitSavedState = {}
end)

TrapHandler.register("OneHitTrap", makeSimpleTrap({
    flyawayText = "One Hit!",
    guard = function(entity)
        return entity.health and not apOneHitSavedState[entity.id]
    end,
    sound = "trapDice",
    action = function(entity)
        apOneHitSavedState[entity.id] = { maxHealth = entity.health.maxHealth }
        entity.health.maxHealth = math.min(entity.health.maxHealth, ONE_HIT_LIMIT)
        if entity.health.health > ONE_HIT_LIMIT then
            entity.health.health = ONE_HIT_LIMIT
        end
    end,
}))
