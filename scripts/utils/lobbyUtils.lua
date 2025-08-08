local Segment = require("necro.game.tile.Segment")
local Tile = require("necro.game.tile.Tile")
local Map = require("necro.game.object.Map")
local Object = require("necro.game.object.Object")
local TileTypes = require("necro.game.tile.TileTypes")
local TextPoolLobby = require("necro.game.data.i18n.TextPoolLobby")
local Persistence = require("necro.game.object.Persistence")
local ObjectMap = require("necro.game.object.Map")
local Marker = require "necro.game.tile.Marker"

local lobbyUtils = {}

Marker.Type.extend("AP_SPAWN")

function lobbyUtils.addTorch(x, y, radius)
    return Object.spawn("WallTorch", x, y, {
        lightSourceRadial = {
            outerRadius = radius or 1344,
        },
    })
end

function lobbyUtils.clearTile(x, y)
    Tile.setType(x, y, "Floor")

    for _, entity in ObjectMap.entitiesWithComponent(x, y, "gameObject") do
        if not Persistence.check(entity) then
            Object.delete(entity)
        end
    end
end

function lobbyUtils.addRect(x1, y1, width, height, wall, floor)
    for x = x1, x1 + width - 1 do
        for y = y1, y1 + height - 1 do
            if (x == x1 or x == x1 + width - 1) or (y == y1 or y == y1 + height - 1) then
                Tile.set(x, y, wall)
            else
                Tile.set(x, y, floor)
            end
        end
    end
end

function lobbyUtils.addRoom(width, height, minY, zone, offsetX)
    local offsetX = offsetX or 1
    local levelX, _, levelWidth, _ = Segment.getBounds(Segment.getCount())
    local minX = levelX + levelWidth + offsetX
    local maxX = minX + width - 1
    local minY = minY or -5
    local maxY = minY + height - 1

    local segmentID = Segment.add(minX, minY, width, height)

    local wall = TileTypes.lookUpTileID("UnbreakableWall", TileTypes.lookUpZoneID(zone or "Zone1"))
    local floor = TileTypes.lookUpTileID("Floor", TileTypes.lookUpZoneID(zone or "Zone1"))

    for x = minX, maxX do
        for y = minY, maxY do
            local isWall = math.min(x - minX, maxX - x, y - minY, maxY - y) == 0

            Tile.set(x, y, isWall and wall or floor)
        end

        Tile.set(x, maxY + 1, 0)
    end

    local torchRadius = math.max(1088, 512 * math.max(width, height))

    for y = minY + 4, maxY - 4, 4 do
        lobbyUtils.addTorch(minX, y, torchRadius)
        lobbyUtils.addTorch(maxX, y, torchRadius)
    end

    for x = minX + 4 - width % 3, maxX - 2, 3 do
        lobbyUtils.addTorch(x, minY, torchRadius)
        lobbyUtils.addTorch(x, maxY, torchRadius)
    end

    return minX, maxX, minY, maxY, segmentID
end

function lobbyUtils.computeAvailableLabelSpace(x, y)
    for i = 1, 9 do
        if Tile.isSolid(x - i, y) or Tile.isSolid(x + i, y) then
            return i
        end
    end
    return 10
end

function lobbyUtils.addLabel(x, y, key, offsetY)
    return Object.spawn("LabelLobby", x, y, {
        worldLabel = {
            offsetY = offsetY,
        },
        worldLabelTextPool = {
            key = key,
        },
        worldLabelMaxWidth = {
            width = 48 * lobbyUtils.computeAvailableLabelSpace(x, y) - 24,
        },
    })
end

function lobbyUtils.addBackToLobby(x, y)
    Tile.setType(x, y, "LobbyStairs")
    Object.spawn("TriggerTravel", x, y)
    lobbyUtils.addLabel(x, y, TextPoolLobby.BACK_TO_LOBBY)
end

function lobbyUtils.addDestination(sourceX, sourceY, destX, destY, label, triggerType)
    Tile.setType(sourceX, sourceY, "LobbyStairs")
    local trapType = triggerType == "TriggerOpenMenu" and "trapOpenMenu" or "trapTravel"
    local trap = Map.firstWithComponent(sourceX, sourceY, trapType)
    trap = trap or Object.spawn(triggerType or "TriggerTravel", sourceX, sourceY)

    if trapType == "trapTravel" then
        trap.trapTravel.x = destX
        trap.trapTravel.y = destY
    else
        trap.trapOpenMenu.menu = "Archipelago_Connect"
    end

    if label then
        lobbyUtils.addLabel(sourceX, sourceY, label)
    end

    return trap
end

return lobbyUtils
