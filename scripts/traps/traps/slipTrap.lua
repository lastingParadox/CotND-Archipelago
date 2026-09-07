local action       = require("necro.game.system.Action")
local collision    = require("necro.game.tile.Collision")
local objectEvents = require("necro.game.object.ObjectEvents")

local utils = require("system.utils.Utilities")
local sign  = utils.sign

local trapSystem = require("AP.scripts.traps.trapSystem")

local NONE_DIRECTION = action.Direction.NONE

local function getSlipDirection(entity, queuedAction)
    if queuedAction then
        local dx, dy = action.getMovementOffset(queuedAction)
        if dx ~= 0 or dy ~= 0 then
            return queuedAction
        end
    end

    if entity.slide and entity.slide.direction and entity.slide.direction ~= NONE_DIRECTION then
        return entity.slide.direction
    end

    if entity.position and entity.previousPosition then
        local dx = sign(entity.position.x - entity.previousPosition.x)
        local dy = sign(entity.position.y - entity.previousPosition.y)
        if dx ~= 0 or dy ~= 0 then
            return action.move(dx, dy)
        end
    end

    if entity.facingDirection and entity.facingDirection.direction and entity.facingDirection.direction ~= NONE_DIRECTION then
        return entity.facingDirection.direction
    end

    return NONE_DIRECTION
end

trapSystem.define({
    name         = "SlipTrap",
    flyaway      = "Whoa!",
    perPlayer    = true,
    -- Slides are resolved alongside the other floor hazards, not with player input.
    tickOrder    = "floorHazards",
    tickSequence = 1,
    apply     = function(ctx)
        local entity = ctx.entity
        if entity.grabbable and entity.grabbable.isGrabbed then return false end
        if not entity.slide then return false end

        -- ctx.action is what this player queued for the beat the trap landed on.
        local direction = getSlipDirection(entity, ctx.action)
        if direction == NONE_DIRECTION then return false end

        if entity.slide.direction ~= direction then
            entity.slide.direction = direction
            objectEvents.fire("beginSlide", entity)
        end

        ctx.state.direction = direction
    end,
    tick      = function(ctx)
        local entity = ctx.entity
        if not (entity.gameObject and entity.gameObject.active and entity.slide) then
            return trapSystem.stop("SlipTrap", entity)
        end

        entity.slide.direction = ctx.state.direction

        local dx, dy = action.getMovementOffset(ctx.state.direction)
        local collisionMask = collision.Group.SOLID
        if entity.slideOnSlipperyTile and entity.slideOnSlipperyTile.collisionMask then
            collisionMask = entity.slideOnSlipperyTile.collisionMask
        end

        if collision.check(entity.position.x + dx, entity.position.y + dy, collisionMask) then
            trapSystem.stop("SlipTrap", entity)
        end
    end,
    expire    = function(ctx)
        local entity = ctx.entity
        if entity and entity.slide then
            entity.slide.direction = NONE_DIRECTION
            objectEvents.fire("endSlide", entity)
        end
    end,
})
