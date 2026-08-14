local ecs = require("system.game.Entities")
local gameMod = require "necro.game.data.resource.GameMod"
local marker = require "necro.game.tile.Marker"
local object = require("necro.game.object.Object")

local lobbyUtils = require("AP.scripts.utils.lobbyUtils")

local apCharacterSelect = {}

local function sortCharacters(a, b)
    if a.playableCharacter.lobbyOrder ~= b.playableCharacter.lobbyOrder then
        return a.playableCharacter.lobbyOrder < b.playableCharacter.lobbyOrder
    end

    return a.name < b.name
end

function apCharacterSelect.createCharacterSelectionRoom(x, y)
    local protos = select(2, ecs.prototypesWithComponents({
        "playableCharacter",
        "!playableCharacterNonSelectable"
    }))

    table.sort(protos, sortCharacters)

    local numStairs = #protos
    local cols = math.max(5, math.floor(math.sqrt(numStairs * 2)))
    local rows = math.ceil(numStairs / cols)
    local width = 2 * cols + 3
    local height = 3 * rows + 5
    local minX, maxX, minY, maxY = lobbyUtils.addRoom(width, height, -5, "Zone2")
    local centerX = math.floor((minX + maxX) / 2)

    for i = 1, numStairs do
        local proto = protos[i]
        local tempX = minX + 2 + 2 * ((i - 1) % cols)
        local tempY = minY + 4 + 3 * math.floor((i - 1) / cols)

        object.spawn("AP_CharacterSelectorLobby", tempX, tempY, {
            worldLabelEntityLookup = {
                type = proto.name
            },
            interactableSelectCharacter = {
                characterType = proto.name
            },
            AP_interactableSelectCharacterLobby = { characterType = proto.name },
            AP_worldLabelCharacterStats = { characterType = proto.name }
        })
    end

    if gameMod.isModLoaded("CharacterSkins") then
        object.spawn("CharacterSkins_SkinSelectionShrine", maxX - 4, minY + 2)
    end
    object.spawn("AP_CharacterSelectorLobbyRandom", maxX - 2, minY + 2)

    local randomLabel = lobbyUtils.addLabel(maxX - 2, minY + 3, "label.lobby.characterSelect.stair.random")
    randomLabel.worldLabel.alignY = 0

    lobbyUtils.addDestination(x, y, centerX, 0, "label.lobby.stair.characterSelect",
        "TriggerTravelPrimaryOnly", {
            AP_trapUnlock = {
                lockType = "characterRoomKey",
                lockedText = "Find the key to unlock!",
            }
        })

    local apLobbyX, apLobbyY = marker.lookUpFirst(marker.Type.AP_SPAWN)
    lobbyUtils.addDestination(minX + 2, minY + 2, apLobbyX, apLobbyY, "mod.AP.lobby.stairBack",
        "TriggerTravelPrimaryOnly")
end

return apCharacterSelect
