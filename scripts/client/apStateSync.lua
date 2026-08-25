local gameClient = require "necro.client.GameClient"
local resources = require "necro.client.Resources"
local visualUpdate = require "necro.cycles.VisualUpdate"
local worldLabel = require "necro.game.system.WorldLabel"

local apClient = require("AP.scripts.client.client")
local apStorage = require("AP.scripts.client.storage")
local progression = require("AP.scripts.client.progression")

-- Host-only; the server replays the log to joiners.
local AP_STATE = apClient.STATE_RESOURCE

apClient.markStateSyncLoaded()

local UPLOAD_INTERVAL = 20
local ticksUntilUpload = 0

local function buildPayload()
    return {
        connected = apClient.isConnected(),
        seedName = apStorage.seedName,
        playerName = apStorage.playerName,
        slot = apStorage.slot,
        saveData = apStorage.saveData,
    }
end

event.tick.add("apUploadState", { order = "lobby", sequence = 4 }, function()
    if not gameClient.isConnected() or not apClient.isHost() then return end
    -- upload() logs a warning and drops the payload until the list is ready.
    if not resources.isResourceListReady() then return end

    local current = resources.getData(AP_STATE)
    local connected = apClient.isConnected()
    local connectionChanged = type(current) ~= "table" or current.connected ~= connected

    ticksUntilUpload = ticksUntilUpload - 1
    -- The connected flag gates too much to wait out the throttle.
    if ticksUntilUpload > 0 and not connectionChanged then return end
    ticksUntilUpload = UPLOAD_INTERVAL

    resources.uploadIfChanged(AP_STATE, "APState", buildPayload())
end)

event.resourceLoaded.add("apApplyState", AP_STATE, function()
    if apClient.isHost() then return end

    local payload = resources.getData(AP_STATE)
    if type(payload) ~= "table" or type(payload.saveData) ~= "table" then return end

    apStorage.applyHostState(payload.seedName, payload.playerName, payload.slot, payload.saveData)
    progression.rebuildCaches()

    -- The item action that refreshes labels ran before this arrived.
    worldLabel.updateAll()
    visualUpdate.trigger()
end)

return { RESOURCE = AP_STATE }
