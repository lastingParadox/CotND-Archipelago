local characterSwitch = require("necro.game.character.CharacterSwitch")
local currency = require "necro.game.item.Currency"
local gameState = require("necro.client.GameState")
local marker = require "necro.game.tile.Marker"
local move = require("necro.game.system.Move")
local object = require "necro.game.object.Object"
local player = require("necro.game.character.Player")
local playerList = require("necro.client.PlayerList")
local vision = require("necro.game.vision.Vision")

local apCharacterSelect = require("AP.scripts.rooms.AP_CharacterSelect")
local apGameModeSelect = require("AP.scripts.rooms.AP_GameModeSelect")
local apConnection = require("AP.scripts.ap_handlers.APConnection")
local apLobby = require("AP.scripts.rooms.AP_Lobby")
local apShops = require("AP.scripts.rooms.AP_Shops")
local apUtils = require("AP.scripts.ap_handlers.APUtils")

marker.Type.extend("AP_SPAWN")

local APGeneration = {
    apLobbyX = 0,
    apLobbyY = 0,
    shops = {},
    shopsPopulated = false,
    createMainAPLobby = apLobby.createMainAPLobby,
    populateLobbyShops = apShops.populateLobbyShops,
    createCharacterSelectionRoom = apCharacterSelect.createCharacterSelectionRoom,
    generateExtraModesRoom = apGameModeSelect.generateExtraModesRoom
}

function APGeneration.generateAPLobby()
    APGeneration.apLobbyX, APGeneration.shops.hephaestusItems, APGeneration.shops.dungeonMasterItems, APGeneration.shops.merlinItems =
        APGeneration.createMainAPLobby()

    marker.setFirst(marker.Type.AP_SPAWN, APGeneration.apLobbyX, APGeneration.apLobbyY)

    APGeneration.populateLobbyShops(APGeneration.shops.hephaestusItems, APGeneration.shops.dungeonMasterItems,
        APGeneration.shops.merlinItems)
    APGeneration.setShopsPopulated(true)

    APGeneration.createCharacterSelectionRoom(APGeneration.apLobbyX, APGeneration.apLobbyY)
    APGeneration.generateExtraModesRoom(APGeneration.apLobbyX, APGeneration.apLobbyY)
end

function APGeneration.generateLobbyTraps(characterName)
    apLobby.generateLobbyTraps(characterName, APGeneration.apLobbyX, APGeneration.apLobbyY)
end

function APGeneration.getApLobbyCoords()
    return APGeneration.apLobbyX, APGeneration.apLobbyY
end

function APGeneration.sendToAPLobby()
    if apConnection.connected and gameState.isInLobby() then
        local playerID = playerList.getLocalPlayerID()
        local playerEntity = player.getPlayerEntity(playerID)

        local characters = apConnection.saveData.characters

        if not characters[playerEntity.name] then
            -- If the character is not in the list, switch to the first available character
            characterSwitch.perform(playerEntity, next(characters), { immediate = true })
            playerEntity = player.getPlayerEntity(playerID)
        end

        currency.set(playerEntity, currency.Type.DIAMOND, apConnection.saveData.diamonds or 0)
        apUtils.setAPHealth(playerEntity)

        local x, y = marker.lookUpFirst(marker.Type.AP_SPAWN)
        move.absolute(playerEntity, x, y)
        vision.updateFieldOfView()
        object.updateAttachments()
    end
end

function APGeneration.setShopsPopulated(value)
    APGeneration.shopsPopulated = value

    if value == false then
        apShops.clearShops()
    end
end

event.objectCharacterSwitchTo.add("changeApTraps", { order = "follower" }, function(ev)
    local newCharacter = ev.newType
    APGeneration.generateLobbyTraps(newCharacter)
end)

event.lobbyGenerate.add("apStairway", { order = "modes", sequence = 1 }, function(ev)
    APGeneration.generateAPLobby()
end)

event.gameStateLevel.add("teleportAPPlayer", { order = "splitScreen" }, function(ev)
    -- Teleport the player to the AP lobby if connected
    APGeneration.sendToAPLobby()
end)

return APGeneration
