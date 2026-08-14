local gameClient = require("necro.client.GameClient")
local menu = require("necro.menu.Menu")
local spectatorHUD = require("necro.render.hud.SpectatorHUD")
local stateControl = require("necro.client.StateControl")

local apClient = require("AP.scripts.client.client")

event.menu.add("archipelagoMidrunErrorConnect", "Archipelago_MidRun_Connect", function(ev)
    local isHost = apClient.isHost()

    local entries = {
        {
            label = isHost
                and L("Please reconnect your Archipelago client", "mod.AP.error.connectionLost.message")
                or L("Waiting for the host to reconnect to Archipelago", "mod.AP.error.connectionLost.messageClient")
        },
        {
            id = "_connect",
            label = L("Connect", "connectButton"),
            hidden = not isHost,
            enableIf = function()
                return apClient.ableToConnect()
            end,
            selected = apClient.ableToConnect(),
            action = function()
                apClient.connect()
            end,
        },
        {
            id = "_continue",
            label = L("Continue"),
            enableIf = function()
                return apClient.isSessionConnected()
            end,
            action = function()
                stateControl.unpauseBeats()
                menu.close()
                spectatorHUD.showControls()
            end
        },
        {
            id = "_lobby",
            label = L("Return to lobby"),
            action = function()
                return gameClient.disconnect()
            end
        }
    }

    ev.menu = {
        closeButton = false,
        directionalConfirmation = false,
        dismissable = false,
        label = L("Archipelago connection lost"),
        entries = entries
    }
end)
