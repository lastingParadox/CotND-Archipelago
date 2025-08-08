local ecs = require("system.game.Entities")
local object = require("necro.game.object.Object")
local textPool = require("necro.config.i18n.TextPool")

-- local i18n = textPool.get("mod.AP.lobby.stairBack")
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
        })
    end

    object.spawn("AP_CharacterSelectorLobbyRandom", maxX - 2, minY + 2)

    local randomLabel = lobbyUtils.addLabel(maxX - 2, minY + 3, "label.lobby.characterSelect.stair.random")
    randomLabel.worldLabel.alignY = 0

    lobbyUtils.addDestination(x, y + 2, centerX, -1, "label.lobby.stair.characterSelect",
        "TriggerTravelPrimaryOnly")

    lobbyUtils.addDestination(minX + 2, minY + 2, x, y, "mod.AP.lobby.stairBack", "TriggerTravelPrimaryOnly")
end

return apCharacterSelect
