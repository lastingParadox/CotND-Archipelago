local chat = require "necro.client.Chat"
local hasClient, client = pcall(require, "system.network.Client")
local hasStorage, storage = pcall(require, "system.file.Storage")
local gameClient = require "necro.client.GameClient"
local json = require("system.utils.serial.JSON")
local netplay = require "necro.network.Netplay"
local orderedSelector = require "system.events.OrderedSelector"
local playerList = require "necro.client.PlayerList"
local resources = require "necro.client.Resources"
local singlePlayer = require "necro.client.SinglePlayer"

-- Only the host holds the socket to the Archipelago client, so it mirrors the
-- session state here for everyone else. A resource rather than a player
-- attribute because level transitions block on resources.allTransfersDone(),
-- so every client agrees on this at a transition -- attributes arrive whenever
-- they arrive, which desyncs anything deterministic that reads them.
local AP_STATE = netplay.Resource.extend("APState")

local apChatBadge = require("AP.scripts.ui.apChatBadge")
local apLog = require("AP.scripts.utils.log").apLog
local handlers = require("AP.scripts.client.initHandlers")
local apVersion = require("AP.scripts.utils.version")

local apClient = {
    client = nil,
    port = 0,
    apworldVersion = false,
    lastConnectError = "",
    -- Also set after script.persist below; needed here for the early return.
    STATE_RESOURCE = AP_STATE,
}

local pendingWarnings = {}
local function queueWarning(text, logText)
    pendingWarnings[#pendingWarnings + 1] = text
    apLog(logText, "warning")
end

if not hasClient then
    queueWarning(
        "You do not have the system.network.Client module whitelisted in your config.json! The Archipelago trapdoor will be disabled.",
        "system.network.Client module not found. Archipelago client functionality will be disabled."
    )
end

if not hasStorage then
    queueWarning(
        "You do not have the system.file.Storage module whitelisted in your config.json! The Archipelago trapdoor will be disabled.",
        "system.file.Storage module not found. Archipelago save data functionality will be disabled."
    )
end

local apConnectSelector = orderedSelector.new(event.apConnect, {
    "connected"
})

local apUpdateSelector = orderedSelector.new(event.apUpdate, {
    "update"
})

if not hasClient or not hasStorage then
    event.tick.add("apClientMissingModuleWarnings", { order = "lobby", sequence = 0 }, function(ev)
        if apClient._missingWarningsShown then return end

        for _, warning in ipairs(pendingWarnings) do
            apChatBadge.addMessage(warning)
        end

        apClient._missingWarningsShown = true
    end)

    -- Fail fast when required sandbox modules are unavailable.
    function apClient.isPortSet() return false end
    function apClient.ableToConnect() return false end
    function apClient.connect() end
    function apClient.disconnect(_) end
    function apClient.isConnected() return false end
    function apClient.isConnecting() return false end
    function apClient.isHost() return true end
    function apClient.isSessionConnected() return false end
    function apClient.sendPacket(_) end
    function apClient.sendDeathlink(_) end

    return apClient
end

local apFolder = hasStorage and storage.new("archipelago") or { readFile = function(_) end }
apClient, apFolder = script.persist(function() return apClient, apFolder end)

-- persist hands back the table from the previous load, so anything derived fresh
-- each load has to be reapplied to it or it stays at the older load's value.
apClient.STATE_RESOURCE = AP_STATE

function apClient.isPortSet()
    return apClient.port ~= nil and apClient.port ~= 0
end

function apClient.isHost()
    -- Off the network there is no player list and the local player owns the run.
    if not gameClient.isConnected() then
        return true
    end
    -- In a session, fail closed: playerList.isHost() compares hostPlayerID with
    -- localPlayerID, and both are nil until login completes, which would report
    -- every client as the host.
    local hostID = playerList.getHostPlayerID()
    local localID = playerList.getLocalPlayerID()
    return hostID ~= nil and localID ~= nil and hostID == localID
end

-- Whether Archipelago is available to this session at all. The host owns the
-- socket; everyone else reads the replicated state, which transitions wait on.
function apClient.isSessionConnected()
    if apClient.isHost() then
        return apClient.isConnected()
    end
    local payload = resources.getData(AP_STATE)
    return type(payload) == "table" and payload.connected == true
end

function apClient.ableToConnect()
    -- If apClient is connected or connecting, then we are not able to connect
    return apClient.isHost() and apClient.isPortSet()
        and not apClient.isConnected() and not apClient.isConnecting()
end

function apClient.connect()
    if not apClient.isHost() then
        apLog("Only the multiplayer host can connect to the Archipelago client.", "warning")
        return
    end
    if hasClient and (apClient.client == nil or not apClient.client.isConnected()) then
        apClient.lastConnectError = ""
        apLog("Connecting to Archipelago client at port " .. tostring(apClient.port))
        apClient.client = client.connectTCP("127.0.0.1", apClient.port, "AP:" .. apVersion.getModVersion())
        if apClient.client.isConnected() then
            apLog("Successfully connected to Archipelago client.")
        elseif not apClient.client.isConnecting() then
            apLog("Failed to connect to Archipelago client.")
        end
    end
end

local pendingDisconnectTicks = 0

function apClient.disconnect(reason)
    if apClient.client ~= nil and apClient.client.isConnected() then
        apLog("Disconnecting from Archipelago client.")
        apClient.sendPacket({
            datatype = "Disconnect",
            reason = reason,
        })
        apClient.client.flush()

        if reason then
            pendingDisconnectTicks = 2
        else
            apClient.client.disconnect()
            apClient.seed = nil
            apClient.client = nil
            apClient.apworldVersion = false
        end
    end
end

-- Defer disconnect to permit "disconnect reason" to propagate before officially disconnecting
event.tick.add("apClientDeferredDisconnect", { order = "lobby", sequence = 3 }, function()
    if pendingDisconnectTicks <= 0 then return end
    pendingDisconnectTicks = pendingDisconnectTicks - 1
    if pendingDisconnectTicks == 0 and apClient.client ~= nil then
        apClient.client.disconnect()
        apClient.seed = nil
        apClient.client = nil
        apClient.apworldVersion = false
    end
end)

function apClient.isConnected()
    return apClient.client ~= nil and apClient.client.isConnected()
end

function apClient.isConnecting()
    return apClient.client ~= nil and apClient.client.isConnecting()
end

function apClient.sendPacket(packet)
    if apClient.client ~= nil and apClient.client.isConnected() then
        local message = json.encode(packet)
        apClient.client.sendReliable(message)
    end
end

function apClient.sendDeathlink(message)
    apClient.sendPacket({
        datatype = "Death",
        msg = message,
    })
end

local stateSyncLoaded = false
function apClient.markStateSyncLoaded()
    stateSyncLoaded = true
end

event.tick.add("initClientPort", { order = "lobby", sequence = 1 }, function(ev)
    if hasStorage and (apClient.port == 0 or (not apClient.isConnected())) then
        local storedPort = tonumber(apFolder.readFile("port.txt"))
        if apClient.port ~= storedPort then apLog("Archipelago client port set to: " .. tostring(storedPort)) end
        apClient.port = storedPort

        -- The "AP Client needs to be connected" warning wipes any last connection errors
        if not apClient.isPortSet() then
            apClient.lastConnectError = ""
        end
    end
end)

event.tick.add("clientLoop", { order = "lobby", sequence = 2 }, function(ev)
    if apClient.client == nil then return end

    apClient.client.process()
    -- Call apClient.poll() in a loop after each process() call to fetch events until it returns nil. Returns (uncompressed) messages and connection events
    while true do
        if not apClient.client then return end
        local event = apClient.client.poll()
        if not event then break end
        if event.message == "" then break end

        local ok, message = pcall(json.decode, event.message)
        if not ok then
            apLog("Failed to decode message: " .. tostring(message), "error")
            goto nextMessage
        end

        local dispatchOk, dispatchErr = pcall(handlers.dispatch, message, apClient)
        if not dispatchOk then
            apLog("Handler error for " .. tostring(message.datatype) .. ": " .. tostring(dispatchErr), "error")
        end

        apUpdateSelector.fire("update", { message = message })

        ::nextMessage::
    end
end)

event.exit.add("apClientDisconnect", { order = "externalLibraries", sequence = 1 }, function(ev)
    if apClient.isConnected() then
        apClient.disconnect()
    end
end)

return apClient
