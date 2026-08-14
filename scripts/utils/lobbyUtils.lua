local lightSource = require "necro.game.vision.LightSource"
local map = require("necro.game.object.Map")
local marker = require "necro.game.tile.Marker"
local object = require("necro.game.object.Object")
local objectMap = require("necro.game.object.Map")
local persistence = require("necro.game.object.Persistence")
local segment = require("necro.game.tile.Segment")
local textPoolLobby = require("necro.game.data.i18n.TextPoolLobby")
local tile = require("necro.game.tile.Tile")
local tileTypes = require("necro.game.tile.TileTypes")

local lobbyUtils = {}
local lightSources = {}

marker.Type.extend("AP_SPAWN")

function lobbyUtils.addTorch(x, y, radius)
    local entity = object.spawn("WallTorch", x, y, {
        lightSourceRadial = {
            outerRadius = radius or 1344,
        },
    })

    table.insert(lightSources, entity)
end

function lobbyUtils.updateLightSources()
    for _, entity in ipairs(lightSources) do
        lightSource.update(entity)
    end
end

function lobbyUtils.clearTile(x, y, zone)
    local floor = tileTypes.lookUpTileID("Floor", tileTypes.lookUpZoneID(zone or "Zone1"))
    tile.set(x, y, floor)

    for _, entity in objectMap.entitiesWithComponent(x, y, "gameObject") do
        if not persistence.check(entity) then
            object.delete(entity)
        end
    end
end

function lobbyUtils.addRect(minX, minY, width, height, wall, floor, addTorches)
    local maxX = minX + width - 1
    local maxY = minY + height - 1
    for x = minX, maxX do
        for y = minY, maxY do
            if (x == minX or x == maxX) or (y == minY or y == maxY) then
                tile.set(x, y, wall)
            else
                tile.set(x, y, floor)
            end
        end
    end

    if addTorches then
        local torchRadius = math.max(1088, 512 * math.max(width, height))
        for y = minY + 4, maxY - 4, 4 do
            lobbyUtils.addTorch(minX, y, torchRadius)
            lobbyUtils.addTorch(maxX, y, torchRadius)
        end

        for x = minX + 4 - width % 3, maxX - 2, 3 do
            lobbyUtils.addTorch(x, minY, torchRadius)
            lobbyUtils.addTorch(x, maxY, torchRadius)
        end
    end
end

function lobbyUtils.addRoom(width, height, minY, zone, segmentRect)
    local levelX, _, levelWidth, _ = segment.getBounds(segment.getCount())
    local minX = levelX + levelWidth + math.abs(segmentRect and segmentRect.xOffset or 0) + 1
    local maxX = minX + width - 1
    local minY = minY or -5
    local maxY = minY + height - 1

    local segmentID

    if segmentRect then
        segmentID = segment.add(minX + segmentRect.xOffset, minY + segmentRect.yOffset, segmentRect.width,
            segmentRect.height)
    else
        segmentID = segment.add(minX, minY, width, height)
    end

    local wall = tileTypes.lookUpTileID("UnbreakableWall", tileTypes.lookUpZoneID(zone or "Zone1"))
    local floor = tileTypes.lookUpTileID("Floor", tileTypes.lookUpZoneID(zone or "Zone1"))

    for x = minX, maxX do
        for y = minY, maxY do
            local isWall = math.min(x - minX, maxX - x, y - minY, maxY - y) == 0

            tile.set(x, y, isWall and wall or floor)
        end

        tile.set(x, maxY + 1, 0)
    end

    local torchRadius = math.max(1536, 256 * math.max(width, height))

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
        if tile.isSolid(x - i, y) or tile.isSolid(x + i, y) then
            return i
        end
    end
    return 10
end

function lobbyUtils.addLabel(x, y, key, offsetY)
    return object.spawn("LabelLobby", x, y, {
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

function lobbyUtils.addLabelForced(x, y, key, offsetY, tiles)
    return object.spawn("LabelLobby", x, y, {
        worldLabel = {
            offsetY = offsetY,
        },
        worldLabelTextPool = {
            key = key,
        },
        worldLabelMaxWidth = {
            width = 48 * (tiles or 3) - 24,
            force = true,
        },
    })
end

function lobbyUtils.addTextLabel(x, y, text, offsetY, tiles)
    return object.spawn("LabelLobby", x, y, {
        worldLabel = {
            offsetY = offsetY,
            alignY = 0,
            text = text,
        },
        worldLabelMaxWidth = {
            width = 48 * (tiles or 3) - 24,
            force = true,
        },
    })
end

function lobbyUtils.addFadingLabel(x, y, key, offsetX, offsetY, maxDistance)
    return object.spawn("LabelFading", x, y, {
        worldLabelTextPool = {
            key = key
        },
        worldLabel = {
            offsetX = offsetX,
            offsetY = offsetY
        },
        worldLabelFade = {
            maxDistance = maxDistance
        }
    })
end

function lobbyUtils.addBackToLobby(x, y)
    tile.setType(x, y, "LobbyStairs")
    lobbyUtils.addLabel(x, y, textPoolLobby.BACK_TO_LOBBY)
    object.spawn("TriggerTravel", x, y)
end

function lobbyUtils.addDestination(sourceX, sourceY, destX, destY, label, triggerType, trapData)
    if label then
        lobbyUtils.addLabel(sourceX, sourceY, label)
    end

    tile.setType(sourceX, sourceY, "LobbyStairs")
    local trapType = triggerType == "TriggerOpenMenu" and "trapOpenMenu" or "trapTravel"
    local trap = map.firstWithComponent(sourceX, sourceY, trapType)
    trap = trap or object.spawn(triggerType or "TriggerTravel", sourceX, sourceY, trapData)

    if trapData then
        for component, data in pairs(trapData) do
            trap[component] = trap[component] or {}
            for key, value in pairs(data) do
                trap[component][key] = value
            end
        end
    end

    if trapType == "trapTravel" then
        trap.trapTravel.x = destX
        trap.trapTravel.y = destY
    else
        trap.trapOpenMenu.menu = "Archipelago_Connect"
    end

    return trap
end

return lobbyUtils
