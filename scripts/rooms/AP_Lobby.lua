local Segment = require("necro.game.tile.Segment")
local Tile = require("necro.game.tile.Tile")
local Map = require("necro.game.object.Map")
local Object = require("necro.game.object.Object")
local textPool = require("necro.config.i18n.TextPool")
local TileTypes = require("necro.game.tile.TileTypes")
local Player = require("necro.game.character.Player")
local PlayerList = require("necro.client.PlayerList")
local extraMode = require "necro.game.data.modifier.ExtraMode"
local gfx = require "system.gfx.GFX"

local apConnection = require("AP.scripts.ap_handlers.APConnection")
local apUtils = require("AP.scripts.ap_handlers.APUtils")
-- local i18n = textPool.get("mod.AP.lobby.stair")
local lobbyUtils = require("AP.scripts.utils.lobbyUtils")

local apLobby = {}

-- TODO: Clean this up in the future
local function setLobbyTiles(minX, minY, maxX, maxY, width, height)
    local wall = TileTypes.lookUpTileID("UnbreakableWall", TileTypes.lookUpZoneID("Zone2"))
    local floor = TileTypes.lookUpTileID("Floor", TileTypes.lookUpZoneID("Zone2"))
    local shopFloor = TileTypes.lookUpTileID("ShopFloor", TileTypes.lookUpZoneID("Zone2"))
    local door = TileTypes.lookUpTileID("DoorHorizontal", TileTypes.lookUpZoneID("Zone2"))

    -- Hephaestus Shop
    lobbyUtils.addRect(minX - 3, minY - 6, 7, 7, wall, floor)
    lobbyUtils.clearTile(minX + 3, minY - 1)
    lobbyUtils.addTorch(minX - 1, minY)
    lobbyUtils.addTorch(minX + 1, minY)
    lobbyUtils.addTorch(minX - 1, minY - 6)
    lobbyUtils.addTorch(minX + 1, minY - 6)
    Object.spawn("Hephaestus", minX, minY - 4)
    Tile.set(minX - 1, minY - 4, shopFloor)
    Tile.set(minX + 1, minY - 4, shopFloor)

    local centerX = minX + math.floor((maxX - minX) / 2)

    -- Dungeon Master Shop
    lobbyUtils.addRect(centerX - 3, minY - 9, 7, 8, wall, floor)
    Tile.set(centerX - 3, minY - 1, wall)
    Tile.set(centerX - 2, minY - 1, wall)
    Tile.set(centerX - 2, minY - 2, wall)
    Tile.set(centerX - 1, minY - 1, wall)
    Tile.set(centerX - 1, minY - 2, wall)
    Tile.set(centerX + 1, minY - 1, wall)
    Tile.set(centerX + 1, minY - 2, wall)
    Tile.set(centerX + 2, minY - 1, wall)
    Tile.set(centerX + 2, minY - 2, wall)
    Tile.set(centerX + 3, minY - 1, wall)
    Tile.set(centerX, minY - 1, floor)
    Tile.set(centerX, minY - 2, floor)
    lobbyUtils.clearTile(centerX, minY - 2)
    lobbyUtils.addTorch(centerX - 1, minY - 2)
    lobbyUtils.addTorch(centerX + 1, minY - 2)
    lobbyUtils.addTorch(centerX - 1, minY - 9)
    lobbyUtils.addTorch(centerX + 1, minY - 9)
    Object.spawn("Medic", centerX, minY - 6)
    Tile.set(centerX - 1, minY - 6, shopFloor)
    Tile.set(centerX + 1, minY - 6, shopFloor)

    -- Merlin Shop
    lobbyUtils.addRect(maxX - 3, minY - 6, 7, 7, wall, floor)
    lobbyUtils.clearTile(maxX - 3, minY - 1)
    lobbyUtils.addTorch(maxX - 1, minY)
    lobbyUtils.addTorch(maxX + 1, minY)
    lobbyUtils.addTorch(maxX - 1, minY - 6)
    lobbyUtils.addTorch(maxX + 1, minY - 6)
    Object.spawn("Merlin", maxX, minY - 4)
    Tile.set(maxX - 1, minY - 4, shopFloor)
    Tile.set(maxX + 1, minY - 4, shopFloor)

    -- Doors
    lobbyUtils.clearTile(minX + 3, minY)
    Tile.set(minX + 3, minY, door)
    lobbyUtils.clearTile(centerX, minY)
    Tile.set(centerX, minY, door)
    lobbyUtils.clearTile(maxX - 3, minY)
    Tile.set(maxX - 3, minY, door)

    return { x = minX - 1, y = minY - 2 }, { x = centerX - 1, y = minY - 4 }, { x = maxX - 1, y = minY - 2 }
end

function apLobby.createMainAPLobby()
    local width = 15
    local height = 11

    -- Initial room creation
    local minX, maxX, minY, maxY, segmentID = lobbyUtils.addRoom(width, height, -3, "Zone2", 4)
    Segment.expand(segmentID, { minX - 3, minY - 9, width + 6, height + 9 })

    apUtils.setLobbyRect(Segment.getRect(segmentID))

    local hephaestus, dungeonMaster, merlin = setLobbyTiles(minX, minY, maxX, maxY, width, height)

    local centerX = math.floor((minX + maxX) / 2)

    local playerID = PlayerList.getLocalPlayerID()
    local playerEntity = Player.getPlayerEntity(playerID)
    apLobby.generateLobbyTraps(playerEntity.name, centerX, 0)

    -- Setting traps for traversal between AP and Lobby
    lobbyUtils.addBackToLobby(maxX - 3, 0)

    local lobbyX, lobbyY = 3, 0
    lobbyUtils.addDestination(lobbyX, lobbyY, centerX, -1, "mod.AP.lobby.stair", "TriggerOpenMenu")

    return centerX, hephaestus, dungeonMaster, merlin
end

function apLobby.generateLobbyTraps(character, lobbyX, lobbyY)
    local offsetX = lobbyX - 2
    local offsetY = lobbyY + 2
    local index = 0

    local zoneText = {
        "label.lobby.stair.zone1",
        "label.lobby.stair.zone2",
        "label.lobby.stair.zone3",
        "label.lobby.stair.zone4",
        "label.lobby.stair.zone5",
    }

    local characterLocations = apConnection.saveData.characterLocations or {}

    if characterLocations then
        characterLocations = characterLocations[character] or {}
    end


    local unlockedZones = {}

    if character == "Aria" then
        unlockedZones = {
            ["Zone1"] = characterLocations["Zone 2"] or false,
            ["Zone2"] = characterLocations["Zone 3"] or false,
            ["Zone3"] = characterLocations["Zone 4"] or false,
            ["Zone4"] = characterLocations["Zone 5"] or false,
            ["Zone5"] = true
        }
    else
        unlockedZones = {
            ["Zone1"] = true,
            ["Zone2"] = characterLocations["Zone 1"] or false,
            ["Zone3"] = characterLocations["Zone 2"] or false,
            ["Zone4"] = characterLocations["Zone 3"] or false,
            ["Zone5"] = characterLocations["Zone 4"] or false,
        }
    end

    -- All zones
    Tile.setType(offsetX, offsetY, "LobbyStairs")
    local trap = Map.firstWithComponent(offsetX, offsetY, "trapStartRun")
    trap = trap or Object.spawn("TriggerStartRun", offsetX, offsetY)
    trap.trapStartRun.mode = "AP_APAllZones"
    lobbyUtils.addLabel(offsetX, offsetY, "label.lobby.stair.allZones")

    offsetX = offsetX - 2
    offsetY = offsetY + 2

    for i = 1, 5 do
        if i == 1 or unlockedZones["Zone" .. i] then
            Tile.setType(offsetX, offsetY, "LobbyStairs")
            trap = Map.firstWithComponent(offsetX, offsetY, "trapStartRun")
            trap = trap or Object.spawn("TriggerStartRun", offsetX, offsetY)
            trap.trapStartRun.mode = "AP_APSingleZone"
            trap.trapStartRun.zone = i
        else
            Tile.setType(offsetX, offsetY, "LobbyLockedStairs")
        end
        lobbyUtils.addLabel(offsetX, offsetY, zoneText[i])

        offsetX = offsetX + 2
    end
end

return apLobby
