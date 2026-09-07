local clientActionBuffer = require "necro.client.ClientActionBuffer"
local gameClient = require "necro.client.GameClient"
local netplay = require "necro.network.Netplay"
local resources = require "necro.client.Resources"
local snapshot = require "necro.game.system.Snapshot"
local turn = require "necro.cycles.Turn"

local apClient = require("AP.scripts.client.client")
local apLog = require("AP.scripts.utils.log").apLog

-- Separate from APState so an event uploads the moment it arrives, unthrottled.
local AP_EVENTS = netplay.Resource.extend("APEvents")

-- The host stamps each event with the turn it happened on; every client applies it there.
local published = {}
local nextEventID = 1
published, nextEventID = script.persist(function() return published, nextEventID end)

-- Rollback-managed, so a rewind past an event lets it apply again.
apEventsApplied = snapshot.variable({}, true)

-- Entries older than this stop being republished.
local RETAIN_TURNS = 600

local apEventSync = { RESOURCE = AP_EVENTS }
local subscribers = {}

---Registers what to do when an event of this kind reaches its turn, on every client.
function apEventSync.subscribe(kind, apply)
    subscribers[kind] = apply
end

local function currentEvents()
    if not gameClient.isConnected() or apClient.isHost() then
        return published
    end

    local payload = resources.getData(AP_EVENTS)
    return type(payload) == "table" and payload or {}
end

local function upload()
    if not gameClient.isConnected() or not resources.isResourceListReady() then return end
    resources.uploadIfChanged(AP_EVENTS, "APEvents", published)
end

---Host-only; off the network this is a local queue on the same path.
---@param kind string Matching a subscribe() registration.
---@param data table|nil Serialised to every client as-is.
function apEventSync.publish(kind, data)
    local now = turn.getCurrentTurnID()

    for i = #published, 1, -1 do
        if now - published[i].turn > RETAIN_TURNS then
            table.remove(published, i)
        end
    end

    published[#published + 1] = {
        id = nextEventID,
        kind = kind,
        data = data,
        turn = now,
    }
    nextEventID = nextEventID + 1

    upload()
end

local function applyDue()
    local now = turn.getCurrentTurnID()

    for _, entry in ipairs(currentEvents()) do
        if not apEventsApplied[entry.id] and entry.turn <= now then
            local apply = subscribers[entry.kind]

            if apply then
                apEventsApplied[entry.id] = true
                apply(entry.data)
            end
        end
    end
end

-- Ahead of TrapHandler's runner, so a trap published this turn makes the same turn's drain.
event.turn.add("apApplySyncedEvents", { order = "playerActions", sequence = -2 }, applyDue)

-- A joiner learning of an event late rewinds to its turn and resimulates.
event.resourceLoaded.add("apRewindToSyncedEvents", AP_EVENTS, function()
    if apClient.isHost() then return end

    local now = turn.getCurrentTurnID()
    local rewindTo = nil

    for _, entry in ipairs(currentEvents()) do
        if not apEventsApplied[entry.id] and entry.turn < now then
            if not rewindTo or entry.turn < rewindTo then
                rewindTo = entry.turn
            end
        end
    end

    if rewindTo then
        apLog(("Rewinding to turn %d for a synced AP event"):format(rewindTo))
        clientActionBuffer.requestRollback(rewindTo)
    end
end)

return apEventSync
