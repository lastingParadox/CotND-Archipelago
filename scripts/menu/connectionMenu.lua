local color = require "system.utils.Color"
local menu = require("necro.menu.Menu")
local worldLabel = require "necro.game.system.WorldLabel"

local apClient = require("AP.scripts.client.client")
local apLobby = require("AP.scripts.level.apLobby")

local lastPortSet = nil
local lastConnectError = nil
event.tick.add("apConnectionMenuPortWatch", { order = "lobby", sequence = 10 }, function()
    local portSet = apClient.isPortSet()
    local connectError = apClient.lastConnectError or ""
    if lastPortSet ~= portSet or lastConnectError ~= connectError then
        lastPortSet = portSet
        lastConnectError = connectError
        if menu.isNamedOpen("Archipelago_Connect") then
            menu.update()
        end
    end
end)

event.menu.add("archipelagoMenuConnect", "Archipelago_Connect", function(ev)
    local localMenu = {}
    local entries = {}

    -- A non-host sees the lobby, the way back, and the reason the rest is missing.
    local isHost = apClient.isHost()

    entries[1] = {
        id = "_connect",
        label = L("Connect", "connectButton"),
        hidden = not isHost,
        enableIf = function() return apClient.ableToConnect() end,
        action = function() apClient.connect() end
    }

    entries[2] = {
        id = "_disconnect",
        label = L("Disconnect", "disconnectButton"),
        hidden = not isHost,
        enableIf = function()
            return apClient.isConnected()
        end,
        action = function()
            apClient.disconnect()
            menu.close()
        end,
    }

    entries[3] = {
        id = "_lobby",
        label = L("Lobby", "lobbyButton"),
        enableIf = function()
            return apClient.isSessionConnected()
        end,
        selected = apClient.isSessionConnected(),
        action = function()
            worldLabel.updateAll()

            menu.close()

            apLobby.sendLocalPlayersToAPLobby()
        end
    }

    entries[4] = {
        id = "_done",
        label = L("Back", "backButton"),
        enableIf = function()
            return apClient ~= nil and not apClient.isConnecting()
        end,
        action = menu.close
    }

    entries[5] = {
        id = "_noPort",
        label = L("AP Client needs to be connected to the Archipelago server", "noPortWarning"),
        color = color.rgb(255, 80, 80),
        fontScale = 1,
        hidden = apClient.isPortSet() or not isHost,
    }

    entries[6] = {
        id = "_lastConnectError",
        label = apClient.lastConnectError or "",
        color = color.rgb(255, 80, 80),
        fontScale = 1,
        -- A connection error belongs to whoever attempted the connection.
        hidden = not isHost or apClient.lastConnectError == "",
    }

    entries[7] = {
        id = "_notHost",
        label = L("Only the host can connect to Archipelago", "notHostWarning"),
        color = color.rgb(255, 80, 80),
        fontScale = 1,
        hidden = isHost,
    }

    localMenu.entries = entries
    localMenu.label = L("Archipelago", "APConnectMenuTitle")
    localMenu.escapeAction = function()
        if apClient.isConnecting() then return nil else return menu.close() end
    end

    ev.menu = localMenu
end)
