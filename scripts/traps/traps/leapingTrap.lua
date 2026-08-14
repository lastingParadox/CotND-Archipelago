local collision = require "necro.game.tile.Collision"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local LEAP_DISTANCE = 2

local leapingEntities = {}
leapingEntities = script.persist(function()
    return leapingEntities
end)

event.objectDirection.add("APLeapingTrapAmplify", { order = "amplify", sequence = 1 }, function(ev)
    if not leapingEntities[ev.entity.id] then return end
    local mask = ev.entity.collisionCheckOnMove and ev.entity.collisionCheckOnMove.mask or collision.Group.SOLID
    if ev.result or collision.check(ev.x, ev.y, mask) then return end

    -- ev.x/ev.y are the single-step destination, so the far tile needs its own
    -- check, and both have to stay in step with dx/dy for later handlers.
    local x, y = ev.x + ev.dx, ev.y + ev.dy
    if collision.check(x, y, mask) then return end

    ev.dx = ev.dx * LEAP_DISTANCE
    ev.dy = ev.dy * LEAP_DISTANCE
    ev.x, ev.y = x, y
end)

event.gameStateLevel.add("APLeapingTrapClearOnLevel", { order = "splitScreen" }, function()
    leapingEntities = {}
end)

event.gameStateReset.add("APLeapingTrapClearOnReset", { order = "resetRunVariables" }, function()
    leapingEntities = {}
end)

TrapHandler.register("LeapingTrap", makeSimpleTrap({
    flyawayText = "Leaping!",
    guard  = function(entity) return not leapingEntities[entity.id] end,
    sound  = "bounceTrap",
    action = function(entity)
        leapingEntities[entity.id] = true
    end,
}))
