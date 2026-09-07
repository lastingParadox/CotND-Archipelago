local trapSystem = require "AP.scripts.traps.trapSystem"

local ONE_HIT_LIMIT = 1

event.objectHeal.add("APOneHitTrapEnforceLimit", { filter = "health", order = "end" }, function(ev)
    if not trapSystem.isActive("OneHitTrap", ev.entity) then return end

    if ev.entity.health.maxHealth > ONE_HIT_LIMIT then
        ev.entity.health.maxHealth = ONE_HIT_LIMIT
    end
    if ev.entity.health.health > ONE_HIT_LIMIT then
        ev.entity.health.health = ONE_HIT_LIMIT
    end
end)

trapSystem.define({
    name      = "OneHitTrap",
    flyaway   = "One Hit!",
    status    = "One Hit!",
    sound     = "trapDice",
    perPlayer = true,
    apply     = function(ctx)
        local entity = ctx.entity
        if not entity.health then return false end

        ctx.state.maxHealth = entity.health.maxHealth
        entity.health.maxHealth = math.min(entity.health.maxHealth, ONE_HIT_LIMIT)
        if entity.health.health > ONE_HIT_LIMIT then
            entity.health.health = ONE_HIT_LIMIT
        end
    end,
    expire    = function(ctx)
        local entity = ctx.entity
        if not (entity and entity.health) then return end

        entity.health.maxHealth = ctx.state.maxHealth
        if entity.health.health > entity.health.maxHealth then
            entity.health.health = entity.health.maxHealth
        end
    end,
})
