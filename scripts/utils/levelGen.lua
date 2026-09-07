local collision = require "necro.game.tile.Collision"
local color = require "system.utils.Color"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"
local map = require "necro.game.object.Map"
local object = require "necro.game.object.Object"
local objectRenderer = require "necro.render.level.ObjectRenderer"
local perspective = require "necro.game.system.Perspective"
local proceduralLevel = require "necro.game.data.level.ProceduralLevel"
local render = require "necro.render.Render"
local rng = require "necro.game.system.RNG"
local segment = require "necro.game.tile.Segment"
local segmentVisibility = require "necro.game.vision.SegmentVisibility"
local tile = require "necro.game.tile.Tile"
local utils = require "system.utils.Utilities"
-- Code extracted from ChLibs

local apDiamonds = require("AP.scripts.utils.apDiamondUtils")

local levelGen = {}
local rooms = {}

local function getValidTiles(room, collisionMask, inset)
    local validTiles = {}

    for x = room.x + inset, room.x + room.width - 1 - inset do
        for y = room.y + inset, room.y + room.height - 1 - inset do
            if not collision.check(x, y, collisionMask) then
                validTiles[#validTiles + 1] = {
                    x,
                    y
                }
            end
        end
    end

    return validTiles
end

local function getAllTiles(room, inset)
    local allTiles = {}

    for x = room.x + inset, room.x + room.width - 1 - inset do
        for y = room.y + inset, room.y + room.height - 1 - inset do
            allTiles[#allTiles + 1] = {
                x,
                y
            }
        end
    end

    return allTiles
end

function levelGen.getValidRooms(roomType)
    roomType = roomType or proceduralLevel.RoomType.STANDARD
    local validRooms = {}

    for _, room in ipairs(rooms) do
        if room.type == roomType then
            validRooms[#validRooms + 1] = room
        end
    end

    return validRooms
end

local function getBackUpChannel()
    return rng.makeChannel(currentLevel.getSeed(),
        currentLevel.getDepth() * 33 + currentLevel.getFloor() * 45 + currentLevel.getZone(), 130)
end

function levelGen.randomTile(params)
    local validRooms = levelGen.getValidRooms(params.roomType)
    local avoidEdges = params.avoidEdges and 1 or 0
    local channel = params.channel or getBackUpChannel()
    local mask = params.collisionMask or collision.Group.PLAYER_PLACEMENT

    rng.shuffle(validRooms, channel)

    local validTiles = {}

    for _, room in ipairs(validRooms) do
        for _, coord in ipairs(getValidTiles(room, mask, avoidEdges)) do
            validTiles[#validTiles + 1] = coord
        end
    end

    rng.shuffle(validTiles, channel)

    return validTiles[1]
end

function levelGen.placeObject(targetType, roomType, attributes, channel, avoidEdges)
    local coord = levelGen.randomTile({
        roomType = roomType or proceduralLevel.RoomType.STANDARD,
        collisionMask = collision.Group.PLAYER_PLACEMENT,
        channel = channel or getBackUpChannel(),
        avoidEdges = avoidEdges
    })

    if coord then
        return object.spawn(targetType, coord[1], coord[2], attributes)
    end

    -- Fallback:
    local validRooms = levelGen.getValidRooms(roomType)
    if validRooms == nil or #validRooms == 0 then
        return levelGen.placeObject(targetType, proceduralLevel.RoomType.STANDARD, attributes, channel, avoidEdges)
    else
        rng.shuffle(validRooms, channel)
        local allTiles = getAllTiles(validRooms[1], 0)
        rng.shuffle(allTiles, channel)
        coord = allTiles[1]

        if collision.check(coord[1], coord[2], collision.Group.PLAYER_PLACEMENT) then
            local entity = map.get(coord[1], coord[2])
            entity = entity and ecs.getEntityByID(entity)
            if entity then object.delete(entity) end
        end

        return object.spawn(targetType, coord[1], coord[2], attributes)
    end
end

event.levelLoad.add("readRoomData", "currentLevel", function(ev)
    rooms = ev.rooms or {}
end)

-- Grimmy's Monocle wall gold fix

local function renderWallContent(item, x, y)
    local proto = ecs.getEntityPrototype(item)
    if not (proto and proto.sprite) then
        return
    end
    local args = objectRenderer.getObjectVisual(proto)
    args.color = color.fade(args.color, 0.6)
    args.rect[1] = args.rect[1] + x * 24 - 12
    args.rect[2] = args.rect[2] + y * 24 - 28
    args.z = args.rect[2] + 19
    return render.getBuffer(render.Buffer.OBJECT).draw(args)
end

local cachedWallGoldPositions = nil

local function getWallGoldPosition()
    local segmentX, segmentY, segmentWidth, segmentHeight = segment.getBounds(segment.MAIN)
    local result = {}
    for x = segmentX, segmentX + segmentWidth - 1 do
        for y = segmentY, segmentY + segmentHeight - 1 do
            local tileInfo = tile.getInfo(x, y)
            if tileInfo.visibleByMonocle and (tileInfo.digEntity or tileInfo.digDiamonds or tileInfo.digAPDiamonds) then
                result[#result + 1] = { x, y }
            end
        end
    end
    return result
end

event.gameStateLevel.add("clearCacheWallGoldPosition", "resetLevelVariables", function(ev)
    cachedWallGoldPositions = nil
end)

event.render.add("renderContents", "contents", function()
    if utils.arrayFind(perspective.getListAttribute(perspective.Attribute.CONTENTS_VISIBILITY_GROUPS), "contentsVisibleByMonocle") then
        cachedWallGoldPositions = cachedWallGoldPositions or getWallGoldPosition()
        for i = 2, #cachedWallGoldPositions do
            local x, y = cachedWallGoldPositions[i][1], cachedWallGoldPositions[i][2]
            local tileInfo = tile.getInfo(x, y)
            if tileInfo.visibleByMonocle and (tileInfo.digEntity or tileInfo.digDiamonds or tileInfo.digAPDiamonds) and segmentVisibility.isVisibleAt(x, y) then
                if tileInfo.digEntity and not tileInfo.digDiamonds and not tileInfo.digAPDiamonds then
                    renderWallContent(tileInfo.digEntity, x, y)
                elseif tileInfo.digAPDiamonds then
                    local amount = apDiamonds.getDiamondAmountForTile(x, y)
                    renderWallContent("AP_ResourceDiamond" .. tostring(amount), x, y)
                else
                    local item = "ResourceDiamond"
                    local zoneNum = tonumber(string.match(tileInfo.tileset, "Zone(%d)"))
                    if (zoneNum > 1 and zoneNum < 5) then
                        item = item .. tostring(zoneNum)
                    elseif zoneNum == 5 then
                        item = item .. "4"
                    end

                    renderWallContent(item, x, y)
                end
            end
        end
    end
end)

return levelGen
