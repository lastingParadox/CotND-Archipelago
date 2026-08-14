local action       = require("necro.game.system.Action")
local currentLevel = require("necro.game.level.CurrentLevel")
local rng          = require("necro.game.system.RNG")
local sound        = require("necro.audio.Sound")
local turn         = require("necro.cycles.Turn")

local apTrapStatus   = require "AP.scripts.ui.apTrapStatus"
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

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

local disableKind      = nil
local disableValue     = nil
local disableName      = nil
local disableRemaining = 0

disableKind, disableValue, disableName, disableRemaining = script.persist(function()
    return disableKind, disableValue, disableName, disableRemaining
end)

apTrapStatus.register("DisableTrap", function()
    if disableRemaining > 0 and disableName then
        return disableName .. " Disabled!"
    end
end)

local function showBlocked(entity)
    sound.playFromEntity("error", entity)
end

-- Tick down remaining beats each turn.
event.turn.add("APDisableTrapTick", { order = "traps" }, function()
    if disableRemaining > 0 then
        disableRemaining = disableRemaining - 1
    end
end)

-- Block directional movement/attacks.
event.objectDirection.add("APDisableTrapBlockDirection",
    { order = "storeAction", sequence = -1 },
    function(ev)
        if disableRemaining <= 0 then return end
        if disableKind ~= "direction" then return end
        if not ev.entity.playableCharacter then return end
        if ev.action == disableValue then
            ev.result = action.Result.INHIBIT
            showBlocked(ev.entity)
        end
    end
)

-- Block special actions.
event.objectSpecialAction.add("APDisableTrapBlockSpecial",
    { order = "storeAction", sequence = -1 },
    function(ev)
        if disableRemaining <= 0 then return end
        if disableKind ~= "special" then return end
        if not ev.entity.playableCharacter then return end
        if ev.action == disableValue then
            ev.result = action.Result.INHIBIT
            showBlocked(ev.entity)
        end
    end
)

-- Block digging.
event.objectDig.add("APDisableTrapBlockDig",
    { order = "breakTile", sequence = -1 },
    function(ev)
        if disableRemaining <= 0 then return end
        if disableKind ~= "dig" then return end
        if not ev.entity or not ev.entity.playableCharacter then return end
        ev.strength = 0
        showBlocked(ev.entity)
    end
)

-- Clean up on run reset.
event.gameStateReset.add("APDisableTrapReset", { order = "resetRunVariables" }, function()
    disableKind      = nil
    disableValue     = nil
    disableName      = nil
    disableRemaining = 0
end)

TrapHandler.register("DisableTrap", makeSimpleTrap({
    flyawayText = function(entity, ctx)
        return ctx.chosen.name .. " Disabled!"
    end,
    setup = function()
        if disableRemaining > 0 then return false end
        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        local chosen  = ACTION_TYPES[rng.range(1, #ACTION_TYPES, channel)]
        disableKind      = chosen.kind
        disableValue     = chosen.value
        disableName      = chosen.name
        disableRemaining = DISABLE_BEATS
        return { chosen = chosen }
    end,
}))
