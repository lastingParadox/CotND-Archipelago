-- TEMPORARY DIAGNOSTIC. Delete once the offending entity is identified.
-- Runs just before moveAnimations and names any entity whose position/sprite
-- coordinates are not numbers, which is what makes updateSpritePosition throw.
local ecs = require("system.game.Entities")

local apLog = require("AP.scripts.utils.log").apLog

local reported = {}

local function check(entity, component, field)
    local value = component and component[field]

    if value ~= nil and type(value) ~= "number" then
        return string.format("%s=%s (%s)", field, tostring(value), type(value))
    end
end

event.render.add("apSpriteProbe", { order = "moveAnimations", sequence = -1 }, function()
    for entity in ecs.entitiesWithComponents({ "sprite", "position", "positionalSprite", "!spriteStaticPosition" }) do
        local bad = {}

        bad[#bad + 1] = check(entity, entity.position, "x")
        bad[#bad + 1] = check(entity, entity.position, "y")
        bad[#bad + 1] = check(entity, entity.sprite, "x")
        bad[#bad + 1] = check(entity, entity.sprite, "y")
        bad[#bad + 1] = check(entity, entity.sprite, "mirrorX")
        bad[#bad + 1] = check(entity, entity.sprite, "mirrorOffsetX")
        bad[#bad + 1] = check(entity, entity.positionalSprite, "offsetX")
        bad[#bad + 1] = check(entity, entity.positionalSprite, "offsetY")

        if #bad > 0 and not reported[entity.name] then
            reported[entity.name] = true
            apLog("SPRITE PROBE: entity '" .. entity.name .. "' (id " .. tostring(entity.id) ..
                ") has " .. table.concat(bad, ", "), "error")
        end
    end
end)
