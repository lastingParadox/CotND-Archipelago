local ecs = require("system.game.Entities")
local marker = require("necro.game.tile.Marker")
local object = require("necro.game.object.Object")

local apCharacters = require("AP.scripts.utils.apCharacters")
local lobbyUtils = require("AP.scripts.utils.lobbyUtils")

marker.Type.extend("AP_BUFF_SPAWN")

local apBuffRoom = {}

local ROOM_WIDTH = 13
local ROOM_HEIGHT = 18
local SHRINE_COLS = 5

local function sortCharacters(a, b)
    if a.playableCharacter.lobbyOrder ~= b.playableCharacter.lobbyOrder then
        return a.playableCharacter.lobbyOrder < b.playableCharacter.lobbyOrder
    end
    return a.name < b.name
end

function apBuffRoom.generateBuffRoom(sourceX, sourceY)
    local minX, maxX, minY, maxY = lobbyUtils.addRoom(ROOM_WIDTH, ROOM_HEIGHT, -5, "Zone2")
    local centerX = math.floor((minX + maxX) / 2)

    -- Forward destination: antechamber staircase → top of buff room.
    lobbyUtils.addDestination(
        sourceX, sourceY,
        centerX, minY + 3,
        "mod.AP.lobby.buffRoom",
        "TriggerTravelPrimaryOnly"
    )

    -- Back stair: buff room upper-left → AP lobby spawn.
    local apLobbyX, apLobbyY = marker.lookUpFirst(marker.Type.AP_SPAWN)
    lobbyUtils.addDestination(
        minX + 2, minY + 3,
        apLobbyX, apLobbyY,
        "mod.AP.lobby.stairBack",
        "TriggerTravelPrimaryOnly"
    )

    object.spawn("LabelLobby", centerX, minY + 2, {
        worldLabel = { offsetY = 3 },
        worldLabelTextPool = { key = "mod.AP.lobby.buffRoom" },
    })
    object.spawn("LabelLobby", centerX, minY + 4, {
        worldLabel = { offsetY = 3 },
        worldLabelTextPool = { key = "mod.AP.lobby.buffRoomHint" },
    })

    -- Static "Bonus HP" header.
    object.spawn("LabelLobby", minX + 3, minY + 5, {
        worldLabel = { text = "Bonus HP", offsetY = -8 }
    })

    -- Decrease trigger  |  heart icon display  |  Increase trigger
    object.spawn("AP_TriggerBuffHealthDecrease", minX + 2, minY + 6)

    object.spawn("AP_BuffHeartDisplay", minX + 3, minY + 6)
    marker.setFirst(marker.Type.AP_BUFF_SPAWN, minX + 3, minY + 6)

    object.spawn("AP_TriggerBuffHealthIncrease", minX + 4, minY + 6)

    -- ── Bonus potion selector, mirrored one tile in from the right wall ────
    object.spawn("LabelLobby", maxX - 3, minY + 5, {
        worldLabel = { text = "Potions on Run Start", offsetY = -8 }
    })

    object.spawn("AP_TriggerBuffPotionDecrease", maxX - 4, minY + 6)

    object.spawn("AP_BuffPotionDisplay", maxX - 3, minY + 6)

    object.spawn("AP_TriggerBuffPotionIncrease", maxX - 2, minY + 6)

    -- ── Character buff shrine grid (5 cols × up to 4 rows) ─────────────────
    local protos = select(2, ecs.prototypesWithComponents({
        "playableCharacter",
        "!playableCharacterNonSelectable",
    }))
    table.sort(protos, sortCharacters)

    -- Centres the grid horizontally: 5 shrines at spacing 2 span 9 columns.
    local shrineStartX = centerX - math.floor(SHRINE_COLS / 2) * 2
    local shrineStartY = minY + 8

    for i, proto in ipairs(protos) do
        local col = (i - 1) % SHRINE_COLS
        local row = math.floor((i - 1) / SHRINE_COLS)
        local sx  = shrineStartX + col * 2
        local sy  = shrineStartY + row * 2

        local charName = apCharacters.cotNDCharToAPLocation(proto.name)

        -- Left inactive, since apBuffShrines drives the visual state from progression.
        object.spawn("AP_BuffCharacterShrine", sx, sy, {
            AP_character = { name = charName },
        })

        -- Character name label, rendered slightly below the shrine sprite.
        object.spawn("LabelLobby", sx, sy, {
            worldLabel = { offsetY = 14, text = charName }
        })
    end
end

return apBuffRoom
