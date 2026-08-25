local clientActionBuffer = require "necro.client.ClientActionBuffer"
local delay              = require "necro.game.system.Delay"
local objectEvents       = require "necro.game.object.ObjectEvents"
local turn               = require "necro.cycles.Turn"

local apUtils            = require("AP.scripts.utils.apUtils")
local apFlyaways         = require("AP.scripts.ui.apFlyaways")
local progression        = require("AP.scripts.client.progression")

local bolt               = {}

local DURATION           = 12.5

local resetBeatmapLater  = delay.register("apBoltBuffResetBeatmap", function(entity)
    objectEvents.fire("resetBeatmap", entity)
end)

local usedThisFloor      = false

local function isBoltBuff()
    if not apUtils.isAPContext() then return false end
    if not progression.getCharacterBuff("Bolt") then return false end
    return true
end

event.gameStateLevel.add("apBoltBuffResetFloor", "resetLevelVariables", function()
    usedThisFloor = false
end)

event.objectTakeDamage.add("apBoltBuffPacemaker", {
    filter = "character",
    order = "health",
}, function(ev)
    if ev.entity.name ~= "Bolt" then return end
    if ev.damage <= 0 then return end
    if not isBoltBuff() then return end
    if usedThisFloor then return end

    usedThisFloor = true

    local endTime = turn.getRawTimestamp() + DURATION
    if ev.entity.controllable then
        endTime = endTime + clientActionBuffer.getTimeDifference(ev.entity.controllable.playerID)
    end

    local component = ev.entity.rhythmIgnoredTemporarily
    if component and component.endTime < endTime then
        component.endTime = endTime
        component.active  = true
    end

    delay.cancel(ev.entity, "apBoltBuffResetBeatmap")
    resetBeatmapLater(ev.entity, DURATION)

    apFlyaways.addToFlyawayQueue({ entity = ev.entity, text = "Pacemaker!" })
end)

function bolt.apply(entity) end

function bolt.revoke(entity) end

return bolt
