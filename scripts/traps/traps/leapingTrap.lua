local collision = require "necro.game.tile.Collision"

local trapSystem = require "AP.scripts.traps.trapSystem"

local LEAP_DISTANCE = 2

event.objectDirection.add("APLeapingTrapAmplify", { order = "amplify", sequence = 1 }, function(ev)
    if not trapSystem.isActive("LeapingTrap", ev.entity) then return end

    local mask = ev.entity.collisionCheckOnMove and ev.entity.collisionCheckOnMove.mask or collision.Group.SOLID
    if ev.result or collision.check(ev.x, ev.y, mask) then return end

    -- ev.x/ev.y hold the single-step destination, so the far tile needs its own check.
    local x, y = ev.x + ev.dx, ev.y + ev.dy
    if collision.check(x, y, mask) then return end

    ev.dx = ev.dx * LEAP_DISTANCE
    ev.dy = ev.dy * LEAP_DISTANCE
    ev.x, ev.y = x, y
end)

trapSystem.define({
    name      = "LeapingTrap",
    flyaway   = "Leaping!",
    sound     = "bounceTrap",
    perPlayer = true,
    stateful  = true,
})
