local action = require("necro.game.system.Action")
local rng    = require("necro.game.system.RNG")
local sound  = require("necro.audio.Sound")

local trapSystem = require "AP.scripts.traps.trapSystem"

local DISABLE_BEATS = 16

-- Each entry defines a blockable action.
local ACTION_TYPES = {
    { kind = "direction", value = action.Direction.UP,    name = "Move Up" },
    { kind = "direction", value = action.Direction.DOWN,  name = "Move Down" },
    { kind = "direction", value = action.Direction.LEFT,  name = "Move Left" },
    { kind = "direction", value = action.Direction.RIGHT, name = "Move Right" },
    { kind = "special",   value = action.Special.BOMB,    name = "Bombs" },
    { kind = "special",   value = action.Special.ITEM_1,  name = "Item Use" },
    { kind = "special",   value = action.Special.THROW,   name = "Weapon Throw" },
    { kind = "dig",       value = nil,                    name = "Digging" },
}

local function showBlocked(entity)
    sound.playFromEntity("error", entity)
end

---The disabled action, or nil while nothing is disabled.
local function blocked(kind)
    local state = trapSystem.stateOf("DisableTrap")
    if state and state.kind == kind then return state end
end

event.objectDirection.add("APDisableTrapBlockDirection",
    { order = "storeAction", sequence = -1 },
    function(ev)
        local state = blocked("direction")
        if not state then return end
        if not ev.entity.playableCharacter then return end

        if ev.action == state.value then
            ev.result = action.Result.INHIBIT
            showBlocked(ev.entity)
        end
    end
)

event.objectSpecialAction.add("APDisableTrapBlockSpecial",
    { order = "storeAction", sequence = -1 },
    function(ev)
        local state = blocked("special")
        if not state then return end
        if not ev.entity.playableCharacter then return end

        if ev.action == state.value then
            ev.result = action.Result.INHIBIT
            showBlocked(ev.entity)
        end
    end
)

event.objectDig.add("APDisableTrapBlockDig",
    { order = "breakTile", sequence = -1 },
    function(ev)
        if not blocked("dig") then return end
        if not (ev.entity and ev.entity.playableCharacter) then return end

        ev.strength = 0
        showBlocked(ev.entity)
    end
)

trapSystem.define({
    name      = "DisableTrap",
    flyaway   = function(ctx) return ctx.state.name .. " Disabled!" end,
    status    = function(ctx) return ctx.state.name .. " Disabled!" end,
    duration  = DISABLE_BEATS,
    tickOrder = "traps",
    start     = function(ctx)
        local chosen = ACTION_TYPES[rng.range(1, #ACTION_TYPES, ctx.channel)]

        ctx.state.kind  = chosen.kind
        ctx.state.value = chosen.value
        ctx.state.name  = chosen.name
    end,
})
