local action = require("necro.game.system.Action")
local camera = require "necro.render.Camera"
local characterSwitch = require("necro.game.character.CharacterSwitch")
local clientActionBuffer = require("necro.client.ClientActionBuffer")
local currency = require "necro.game.item.Currency"
local gameState = require("necro.client.GameState")
local inventory = require "necro.game.item.Inventory"
local itemSlot = require "necro.game.item.ItemSlot"
local marker = require("necro.game.tile.Marker")
local move = require("necro.game.system.Move")
local object = require("necro.game.object.Object")
local segment = require("necro.game.tile.Segment")
local singlePlayer = require("necro.client.SinglePlayer")
local tile = require "necro.game.tile.Tile"
local vision = require("necro.game.vision.Vision")
local visibility = require "necro.game.vision.Visibility"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apCharacters = require("AP.scripts.utils.apCharacters")
local apClient = require("AP.scripts.client.client")
local apFlags = require("AP.scripts.utils.flags")
local apInventory = require("AP.scripts.utils.apInventory")
local localCoop = require "necro.client.LocalCoop"
local player = require "necro.game.character.Player"
local progression = require("AP.scripts.client.progression")

local AP_LOBBY_ACTION = action.System.extend("AP_LOBBY")

local APLobby = {
    spawn = { x = nil, y = nil },
    segmentID = -1
}

function APLobby.getAPLobbySpawn()
    return APLobby.spawn.x, APLobby.spawn.y
end

function APLobby.sendToAPLobby(entities)
    if apClient.isSessionConnected() and gameState.isInLobby() then
        -- Required here so this file does not pull the mode entities forward in load order.
        require("AP.scripts.entities.apExtraModeConfiguration").disableLockedModes()

        for _, entity in ipairs(entities or player.getPlayerEntities()) do
            local playerID = entity.controllable.playerID
            local playerEntity = entity
            local character = apCharacters.cotNDCharToAPLocation(playerEntity.name)

            local function switchTo(characterName)
                if not characterName or not progression.isCharacterPlayable(characterName) then
                    return false
                end

                characterSwitch.perform(playerEntity, apCharacters.apLocationToCotNDChar(characterName),
                    { resetHealth = true, immediate = true })
                playerEntity = player.getPlayerEntity(playerID)
                return true
            end

            if not progression.isCharacterPlayable(character) then
                switchTo(progression.getStartingCharacter())
            end

            currency.set(playerEntity, apFlags.CURRENCY_AP_DIAMOND, progression.getDiamonds() or 0)
            apCharacters.setAPHealth(playerEntity)

            apInventory.applyStarterInventory(playerEntity, progression, { sanitize = true })

            local x, y = marker.lookUpFirst(marker.Type.AP_SPAWN)
            move.absolute(playerEntity, x, y)

            object.updateAttachments()
            vision.updateFieldOfView()
            vision.updateInstantly()
            visibility.updateRevealed()
            camera.updateVisibleTileRect()
            visualUpdate.trigger()
        end
    end
end

-- Moves only the pressing client's own players, which in local coop is everyone.
function APLobby.sendLocalPlayersToAPLobby()
    if singlePlayer.isActive() then
        return APLobby.sendToAPLobby()
    end

    -- Queues a system action so every client runs the teleport on the same turn.
    for _, playerID in ipairs(localCoop.getLocalPlayerIDs()) do
        clientActionBuffer.addAction(playerID, clientActionBuffer.findAvailableTurnID(playerID), AP_LOBBY_ACTION, 0)
    end
end

event.turn.add("apTeleportToAPLobby", "customActions", function(ev)
    local actions = ev.actionMap[AP_LOBBY_ACTION]
    if not actions then return end

    local entities = {}
    for _, actionData in ipairs(actions) do
        local entity = player.getPlayerEntity(actionData.playerID)
        if entity then
            entities[#entities + 1] = entity
        end
    end

    if #entities > 0 then
        APLobby.sendToAPLobby(entities)
    end
end)

function APLobby.setSegment(segmentID)
    APLobby.segmentID = segmentID
end

function APLobby.isInLobby(entity)
    if APLobby.segmentID == -1 then return false end
    -- return segment.contains(APLobby.segmentID, entity.position.x, entity.position.y)
    local playerSegment = segment.getSegmentIDAt(entity.position.x, entity.position.y)
    return playerSegment >= APLobby.segmentID
end

event.gameStateLevel.add("teleportAPPlayer", { order = "splitScreen" }, function(ev)
    APLobby.sendToAPLobby()
end)

return APLobby
