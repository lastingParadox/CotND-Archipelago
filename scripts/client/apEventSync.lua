local clientActionBuffer = require "necro.client.ClientActionBuffer"
local gameClient = require "necro.client.GameClient"
local netplay = require "necro.network.Netplay"
local resources = require "necro.client.Resources"
local snapshot = require "necro.game.system.Snapshot"
local turn = require "necro.cycles.Turn"

local apClient = require("AP.scripts.client.client")
local apLog = require("AP.scripts.utils.log").apLog

-- Separate from APState so an event uploads the moment it arrives rather than
-- waiting on that payload's throttle and dragging the whole save with it.
local AP_EVENTS = netplay.Resource.extend("APEvents")

-- Only the Archipelago host holds the socket, so it is the only one that learns of
-- a deathlink or a traplink trap. It stamps each with the turn it happened on and
-- publishes; every client applies on that same turn, so the effect is part of the
-- simulation rather than one machine's local state.
local published = {}
local nextEventID = 1
published, nextEventID = script.persist(function() return published, nextEventID end)

-- Rollback-managed: a rewind past an event has to let it apply again, or the
-- resimulation drops the effect the original pass produced.
apEventsApplied = snapshot.variable({}, true)

-- Entries older than this stop being republished. Long enough to cover a rollback
-- window, short enough that the payload cannot grow without bound over a run.
local RETAIN_TURNS = 600

local apEventSync = { RESOURCE = AP_EVENTS }
local subscribers = {}

---Registers what to do when an event of this kind reaches its turn. Runs on every
---client, so it must only touch simulated state.
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

---Host-only. Off the network this is just a local queue, which is the same path.
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

-- Ahead of TrapHandler's runner, so a trap published this turn is queued in time
-- for the same turn's drain.
event.turn.add("apApplySyncedEvents", { order = "playerActions", sequence = -2 }, applyDue)

-- The host applied on the turn it stamped; a joiner learning of it later rewinds to
-- that turn and resimulates, the same correction the engine runs for late player
-- input. That is what removes the need to schedule events into the future.
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
