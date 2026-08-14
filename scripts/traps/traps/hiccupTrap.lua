local action    = require "necro.game.system.Action"
local collision = require "necro.game.tile.Collision"
local rng       = require "necro.game.system.RNG"

local apFlyaways        = require "AP.scripts.ui.apFlyaways"
local makeBeatStateTrap = (require "AP.scripts.traps.factories.makeBeatStateTrap").makeBeatStateTrap
local TrapHandler       = require "AP.scripts.traps.trapHandler"

local ORTHOGONAL = {
    action.Direction.RIGHT,
    action.Direction.UP,
    action.Direction.LEFT,
    action.Direction.DOWN,
}

TrapHandler.register("HiccupTrap", makeBeatStateTrap({
    name        = "HiccupTrap",
    flyawayText = "Hiccup!",
    statusText  = "Hiccups!",

    initState = function(entity, channel)
        return { beatsUntilHiccup = rng.range(5, 10, channel) }
    end,

    onTick = function(entity, entityState, stateTable, ev, channel)
        entityState.beatsUntilHiccup = entityState.beatsUntilHiccup - 1
        if entityState.beatsUntilHiccup > 0 then return end

        local x     = entity.position.x
        local y     = entity.position.y
        local free  = {}
        for _, dir in ipairs(ORTHOGONAL) do
            local dx = action.dx(dir)
            local dy = action.dy(dir)
            if not collision.check(x + dx, y + dy, collision.Group.SOLID) then
                free[#free + 1] = dir
            end
        end

        if #free > 0 then
            local chosenDir = rng.choice(free, channel)
            local found = false
            for _, entry in ipairs(ev.actionQueue) do
                if entry.entity and entry.entity.id == entity.id then
                    entry.action = chosenDir
                    found = true
                    break
                end
            end
            if not found then
                ev.actionQueue[#ev.actionQueue + 1] = { entity = entity, action = chosenDir }
            end
            apFlyaways.addToFlyawayQueue({ entity = entity, text = "Hiccup!" })
        end

        -- Reset the timer for another random interval.
        entityState.beatsUntilHiccup = rng.range(5, 10, channel)
    end,
}))
