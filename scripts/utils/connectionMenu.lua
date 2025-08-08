local APGeneration = require("AP.scripts.ap_handlers.APGeneration")
local APConnection = require("AP.scripts.ap_handlers.APConnection")
local Menu = require("necro.menu.Menu")
local Player = require("necro.game.character.Player")
local PlayerList = require("necro.client.PlayerList")
local CharacterSwitch = require("necro.game.character.CharacterSwitch")

Event.menu.add("archipelagoMenuConnect", "Archipelago_Connect", function(ev)
    local menu = {}
    local entries = {}

    entries[1] = {
        id = "_connect",
        label = L("Connect", "connectButton"),
        enableIf = function()
            return APConnection.connection.status == "Disconnected"
        end,
        action = function()
            APConnection.connect()
        end,
    }

    entries[2] = {
        id = "_lobby",
        label = L("Lobby", "lobbyButton"),
        enableIf = function()
            return APConnection.connected
        end,
        action = function()
            local playerID = PlayerList.getLocalPlayerID()
            local playerEntity = Player.getPlayerEntity(playerID)

            local characters = APConnection.saveData.characters

            if not characters[playerEntity.name] then
                -- If the character is not in the list, switch to the first available character
                CharacterSwitch.perform(playerEntity, next(characters), { immediate = true })
                playerEntity = Player.getPlayerEntity(playerID)
            end

            APGeneration.generateLobbyTraps(playerEntity.name)
            if not APGeneration.shopsPopulated then
                APGeneration.populateLobbyShops(APGeneration.shops.hephaestusItems, APGeneration.shops
                    .dungeonMasterItems,
                    APGeneration.shops.merlinItems)
                APGeneration.setShopsPopulated(true)
            end

            Menu.close()

            APGeneration.sendToAPLobby()
        end
    }

    entries[3] = {
        id = "_done",
        label = L("Back", "backButton"),
        enableIf = function()
            return APConnection.connection.status ~= "Connecting"
        end,
        action = Menu.close,
    }

    menu.entries = entries
    menu.searchable = true
    menu.label = L("Archipelago", "Archipelago")
    menu.escapeAction = function()
        if APConnection.connection.status == "Connecting" then return nil else return Menu.close() end
    end

    ev.menu = menu
end)
