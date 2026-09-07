local action    = require "necro.game.system.Action"
local collision = require "necro.game.tile.Collision"
local rng       = require "necro.game.system.RNG"

local apFlyaways = require "AP.scripts.ui.apFlyaways"
local trapSystem = require "AP.scripts.traps.trapSystem"

local ORTHOGONAL = {
    action.Direction.RIGHT,
    action.Direction.UP,
    action.Direction.LEFT,
    action.Direction.DOWN,
}

local MIN_INTERVAL = 5
local MAX_INTERVAL = 10

trapSystem.define({
    name      = "HiccupTrap",
    flyaway   = "Hiccup!",
    status    = "Hiccups!",
    perPlayer = true,
    -- No duration: the hiccups last until the floor does.
    apply     = function(ctx)
        ctx.state.beatsUntilHiccup = rng.range(MIN_INTERVAL, MAX_INTERVAL, ctx.channel)
    end,
    tick      = function(ctx)
        local entity = ctx.entity

        ctx.state.beatsUntilHiccup = ctx.state.beatsUntilHiccup - 1
        if ctx.state.beatsUntilHiccup > 0 then return end

        local x, y  = entity.position.x, entity.position.y
        local free  = {}
        for _, dir in ipairs(ORTHOGONAL) do
            if not collision.check(x + action.dx(dir), y + action.dy(dir), collision.Group.SOLID) then
                free[#free + 1] = dir
            end
        end

        if #free > 0 then
            local chosenDir = rng.choice(free, ctx.channel)
            local found = false

            for _, entry in ipairs(ctx.ev.actionQueue) do
                if entry.entity and entry.entity.id == entity.id then
                    entry.action = chosenDir
                    found = true
                    break
                end
            end
            if not found then
                ctx.ev.actionQueue[#ctx.ev.actionQueue + 1] = { entity = entity, action = chosenDir }
            end

            apFlyaways.addToFlyawayQueue({ entity = entity, text = "Hiccup!" })
        end

        ctx.state.beatsUntilHiccup = rng.range(MIN_INTERVAL, MAX_INTERVAL, ctx.channel)
    end,
})
