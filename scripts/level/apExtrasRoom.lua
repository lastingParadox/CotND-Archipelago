local collision = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"
local object = require "necro.game.object.Object"
local objectMap = require "necro.game.object.Map"
local placementUtils = require "necro.game.level.PlacementUtils"
local player = require "necro.game.character.Player"
local proceduralLevel = require "necro.game.data.level.ProceduralLevel"
local rng = require "necro.game.system.RNG"
local segment = require "necro.game.tile.Segment"
local settingsStorage = require "necro.config.SettingsStorage"
local tile = require "necro.game.tile.Tile"
local tileTypes = require "necro.game.tile.TileTypes"

local apLog = require("AP.scripts.utils.log").apLog
local apUtils = require("AP.scripts.utils.apUtils")

local apExtrasRoom = {}

local queued = {}

-- Keyed by name so a script reload replaces an estimator instead of doubling it.
local estimators = {}
local estimatorNames = {}

---Registers how many rooms a floor will want
---@param name string
---@param estimate function (entry, ev) -> count, where entry carries zone and floor.
function apExtrasRoom.demand(name, estimate)
    if estimators[name] == nil then
        estimatorNames[#estimatorNames + 1] = name
        table.sort(estimatorNames)
    end

    estimators[name] = estimate
end

event.levelSequenceUpdate.add("apExtraRooms", { order = "ensemble", sequence = 1 }, function(ev)
    if not apUtils.isAPContext() then return end

    for _, entry in ipairs(ev.sequence) do
        if not entry.boss then
            local rooms = 0

            for _, name in ipairs(estimatorNames) do
                rooms = rooms + (estimators[name](entry, ev) or 0)
            end

            if rooms > 0 then
                entry.extraRoomCount = (tonumber(entry.extraRoomCount) or 0) + rooms
            end
        end
    end
end)

local LOOT_COMPONENTS = { "item", "storage", "shrine" }
local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local SIDES = 4
local CLOSET_SIZES = { { 3, 3 }, { 3, 2 }, { 2, 3 }, { 2, 2 } }
local FLOOR_TILE = "Floor"
local WALL_TILE = "DirtWall"
local BORDER_TILE = "LevelBorder"

-- Walkable despite being walls, so carving them opens a shop.
local SHOP_WALLS = {
    ShopWall = true,
    DarkShopWall = true,
    ShopWallCracked = true,
    DarkShopWallCracked = true,
}

local WALL_SPIKE = "Sync_WallSpike"
local SPIKE_CHANCE_SETTING = "mod.Sync.levelGeneration.spikeWallChance"
local SPIKE_CHANCE_DEFAULT = 0.08

-- Synchrony spikes a whole connected stone wall at this rate, and a closet's shell is one.
local function spikeShell(x, y, width, height, channel)
    if not ecs.getEntityPrototype(WALL_SPIKE) then return end
    if not currentLevel.isRegularFloor() then return end
    if player.firstWithComponent("Sync_traitNoWallSpikes") then return end

    local chance = settingsStorage.get(SPIKE_CHANCE_SETTING)
    if type(chance) ~= "number" then chance = SPIKE_CHANCE_DEFAULT end

    if rng.float(1, channel) >= chance then return end

    for cx = x - 1, x + width do
        for cy = y - 1, y + height do
            local inside = cx >= x and cx < x + width
                and cy >= y and cy < y + height

            if not inside then object.spawn(WALL_SPIKE, cx, cy) end
        end
    end
end

local function isWall(info)
    return bit.band(info.collision or 0, collision.Type.WALL) ~= 0
end

-- The level's own edge: LevelBorder and the boss walls
local function isBorder(info)
    return bit.band(info.collision or 0, collision.Type.BORDER) ~= 0
end

-- Anything that is not walkable is space to build in, void included
local function isSpace(x, y)
    if not tile.exists(x, y) then return true end

    local info = tile.getInfo(x, y)
    return isWall(info) and not SHOP_WALLS[info.name]
end

local function isCarvable(x, y)
    if not isSpace(x, y) or placementUtils.getRoomAt(x, y) then return false end

    local info = tile.getInfo(x, y)

    return not info.digEntity and not info.digDiamonds and not info.digAPDiamonds
        and not objectMap.get(x, y)
end

-- A later closet may share a wall with an earlier one, but must never carve into it
local claimedFloor = {}
local claimedShell = {}

local SECRET_ROOMS = {
    [proceduralLevel.RoomType.SECRET] = true,
    [proceduralLevel.RoomType.SECRET_SHOP] = true,
}

-- Only floor the player can already walk to counts as a way in
local function isOpenFloor(x, y, index)
    if claimedFloor[index] then return false end

    local room = placementUtils.getRoomAt(x, y)

    return not (room and SECRET_ROOMS[room.type])
end

-- Void comes in two kinds: the level's outer margin, and pockets inside
local function floodOuterVoid(survey, minX, minY, width, height)
    local outer, stack = {}, {}

    local function push(x, y)
        local index = tile.reduceCoordinates(x, y)

        if index and survey.void[index] and not outer[index] then
            outer[index] = true
            stack[#stack + 1] = { x, y }
        end
    end

    for x = minX, minX + width - 1 do
        push(x, minY)
        push(x, minY + height - 1)
    end

    for y = minY, minY + height - 1 do
        push(minX, y)
        push(minX + width - 1, y)
    end

    while #stack > 0 do
        local at = table.remove(stack)

        for _, step in ipairs(NEIGHBOURS) do
            push(at[1] + step[1], at[2] + step[2])
        end
    end

    return outer
end

-- One pass up front, so testing a block is a lookup rather than a tile.getInfo per tile.
local function surveyRock(minX, minY, width, height)
    local survey = { carvable = {}, space = {}, floor = {}, void = {} }
    local zoneID

    for x = minX, minX + width - 1 do
        for y = minY, minY + height - 1 do
            local index = tile.reduceCoordinates(x, y)

            if index then
                survey.space[index] = isSpace(x, y)
                survey.carvable[index] = isCarvable(x, y)

                if tile.exists(x, y) then
                    local info = tile.getInfo(x, y)
                    zoneID = zoneID or info.zoneID

                    if not isWall(info) and isOpenFloor(x, y, index) then
                        survey.floor[index] = true
                    end
                else
                    survey.void[index] = true
                end
            end
        end
    end

    survey.zoneID = zoneID or 0
    survey.outerVoid = floodOuterVoid(survey, minX, minY, width, height)

    return survey
end

local function claim(x, y, width, height)
    for cx = x - 1, x + width do
        for cy = y - 1, y + height do
            local index = tile.reduceCoordinates(cx, cy)

            if index then
                local inside = cx >= x and cx < x + width
                    and cy >= y and cy < y + height

                if inside then
                    claimedFloor[index] = true
                else
                    claimedShell[index] = true
                end
            end
        end
    end
end


---@return boolean fits
---@return boolean usesVoid  Marks a site out in the level's outer margin.
---@return integer sides  How many of the closet's four edges a dig can enter from.
local function closetFits(x, y, width, height, survey)
    local usesVoid = false
    local reached = {}

    for cx = x - 1, x + width do
        for cy = y - 1, y + height do
            local index = tile.reduceCoordinates(cx, cy)
            if not index or claimedFloor[index] then return false, false, 0 end

            local inside = cx >= x and cx < x + width
                and cy >= y and cy < y + height

            if inside then
                if claimedShell[index] then return false, false, 0 end
                if not survey.carvable[index] then return false, false, 0 end
            else
                if not survey.space[index] then return false, false, 0 end

                -- Corners do not count, since one only touches the interior diagonally.
                local side = (cx == x - 1 and "left")
                    or (cx == x + width and "right")
                    or (cy == y - 1 and "top")
                    or (cy == y + height and "bottom")
                local corner = (cx == x - 1 or cx == x + width)
                    and (cy == y - 1 or cy == y + height)

                if side and not corner then
                    for _, step in ipairs(NEIGHBOURS) do
                        local neighbour = tile.reduceCoordinates(cx + step[1], cy + step[2])
                        if neighbour ~= nil and survey.floor[neighbour] == true then
                            reached[side] = true
                        end
                    end
                end
            end

            usesVoid = usesVoid or survey.outerVoid[index] == true
        end
    end

    local sides = 0
    for _ in pairs(reached) do sides = sides + 1 end

    return sides > 0, usesVoid, sides
end

-- Every placement of every size, split by whether it needs the level's empty margin.
local function findSpots(minX, minY, width, height, survey)
    local inside, outside = {}, {}

    for sizeIndex, size in ipairs(CLOSET_SIZES) do
        -- Two tiles of margin, so the backing ring stays inside the segment.
        for x = minX + 2, minX + width - size[1] - 2 do
            for y = minY + 2, minY + height - size[2] - 2 do
                local fits, usesVoid, sides = closetFits(x, y, size[1], size[2], survey)

                if fits then
                    local pool = usesVoid and outside or inside
                    pool[sizeIndex] = pool[sizeIndex] or {}

                    local spots = pool[sizeIndex]
                    spots[#spots + 1] = { x, y, size[1], size[2], sides = sides }
                end
            end
        end
    end

    return inside, outside
end

-- Centers of the closets already carved on this floor.
local carvedCentres = {}
local MIN_SEPARATION = 12

local function farFromCarved(spot)
    local x = spot[1] + spot[3] / 2
    local y = spot[2] + spot[4] / 2

    for _, centre in ipairs(carvedCentres) do
        local dx, dy = x - centre[1], y - centre[2]
        if dx * dx + dy * dy < MIN_SEPARATION * MIN_SEPARATION then return false end
    end

    return true
end

-- Spread first, centre second: distance from existing closets outranks the inward pull.
local function nearestToCentre(spots, centreX, centreY, channel)
    local scored = {}

    for _, spot in ipairs(spots) do
        if farFromCarved(spot) then
            local dx = spot[1] + spot[3] / 2 - centreX
            local dy = spot[2] + spot[4] / 2 - centreY
            scored[#scored + 1] = { spot = spot, distance = dx * dx + dy * dy }
        end
    end

    if #scored == 0 then
        for index, spot in ipairs(spots) do
            local dx = spot[1] + spot[3] / 2 - centreX
            local dy = spot[2] + spot[4] / 2 - centreY
            scored[index] = { spot = spot, distance = dx * dx + dy * dy }
        end
    end

    table.sort(scored, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        if a.spot[1] ~= b.spot[1] then return a.spot[1] < b.spot[1] end
        return a.spot[2] < b.spot[2]
    end)

    local keep = math.max(1, math.floor(#scored / 2))

    return scored[rng.int(keep, channel) + 1].spot
end

-- Only the spots a dig can reach from exactly `tier` sides, size by size
local function pickSpot(pool, centreX, centreY, channel, tier)
    local openest, sizeIndices = {}, {}

    for sizeIndex, spots in pairs(pool) do
        local kept = {}

        for _, spot in ipairs(spots) do
            if (spot.sides or 1) == tier then kept[#kept + 1] = spot end
        end

        if #kept > 0 then
            openest[sizeIndex] = kept
            sizeIndices[#sizeIndices + 1] = sizeIndex
        end
    end

    if #sizeIndices == 0 then return nil end

    table.sort(sizeIndices)

    local spots = openest[sizeIndices[rng.int(#sizeIndices, channel) + 1]]
    return nearestToCentre(spots, centreX, centreY, channel)
end

---@return table|nil {x, y, width, height} of the carved closet.
local function carveCloset(channel)
    local minX, minY, width, height = segment.getBounds(segment.MAIN)
    local survey = surveyRock(minX, minY, width, height)
    local zoneID = survey.zoneID

    local floorID = tileTypes.lookUpTileID(FLOOR_TILE, zoneID)
        or tileTypes.lookUpTileID(FLOOR_TILE, 0)
    local wallID = tileTypes.lookUpTileID(WALL_TILE, zoneID)
        or tileTypes.lookUpTileID(WALL_TILE, 0)
    local borderID = tileTypes.lookUpTileID(BORDER_TILE, zoneID)
        or tileTypes.lookUpTileID(BORDER_TILE, 0)

    local inside, outside = findSpots(minX, minY, width, height, survey)

    -- Findability first, and only then the level's own rock over its margin
    local centreX = minX + width / 2
    local centreY = minY + height / 2
    local spot, pool

    for tier = SIDES, 1, -1 do
        pool = "interior"
        spot = pickSpot(inside, centreX, centreY, channel, tier)

        if not spot then
            pool = "margin"
            spot = pickSpot(outside, centreX, centreY, channel, tier)
        end

        if spot then break end
    end

    if not spot then return end

    local x, y, w, h = spot[1], spot[2], spot[3], spot[4]

    -- Only what a shovel cannot get through is replaced: boundary rock, and the void
    for cx = x - 1, x + w do
        for cy = y - 1, y + h do
            local interior = cx >= x and cx < x + w
                and cy >= y and cy < y + h

            if not interior and (not tile.exists(cx, cy) or isBorder(tile.getInfo(cx, cy))) then
                tile.set(cx, cy, wallID)
            end
        end
    end

    for cx = x, x + w - 1 do
        for cy = y, y + h - 1 do
            tile.set(cx, cy, floorID)
        end
    end

    -- Backs anything just converted, so a dig through it does not open onto void.
    for cx = x - 2, x + w + 1 do
        for cy = y - 2, y + h + 1 do
            local beyondShell = cx < x - 1 or cx > x + w
                or cy < y - 1 or cy > y + h

            if beyondShell and not tile.exists(cx, cy) then
                tile.set(cx, cy, borderID)
            end
        end
    end

    spikeShell(x, y, w, h, channel)

    claim(x, y, w, h)
    carvedCentres[#carvedCentres + 1] = { x + w / 2, y + h / 2 }

    return spot
end

local function lootCount(room)
    local count = 0

    for x = room.x, room.x + room.width - 1 do
        for y = room.y, room.y + room.height - 1 do
            for _, component in ipairs(LOOT_COMPONENTS) do
                if objectMap.hasComponent(x, y, component) then
                    count = count + 1
                    break
                end
            end
        end
    end

    return count
end

local function rankedRooms(channel)
    local candidates = {}
    local roomTypes = { proceduralLevel.RoomType.SECRET, proceduralLevel.RoomType.STANDARD }

    for _, roomType in ipairs(roomTypes) do
        for _, room in ipairs(placementUtils.getRoomsOfType(roomType)) do
            candidates[#candidates + 1] = { room = room, loot = lootCount(room) }
        end
    end

    -- Drawn up front so the sort itself stays deterministic across clients.
    for _, candidate in ipairs(candidates) do
        candidate.tiebreak = rng.int(#candidates * 8, channel)
    end

    table.sort(candidates, function(a, b)
        if (a.loot == 0) ~= (b.loot == 0) then return a.loot == 0 end
        if a.loot ~= b.loot then return a.loot < b.loot end
        return a.tiebreak < b.tiebreak
    end)

    return candidates
end

local function tilesIn(room)
    return placementUtils.getTilesInRoom(room, collision.Group.PLAYER_PLACEMENT)
end

---Queues an entity for a room of this floor's own.
---@param entityType string
---@param attributes table|nil Spawn attributes.
---@param options table|nil    secret: carve a closet out of rock. fallback: called on failure.
function apExtrasRoom.add(entityType, attributes, options)
    options = options or {}

    queued[#queued + 1] = {
        entityType = entityType,
        attributes = attributes,
        secret = options.secret,
        fallback = options.fallback,
    }
end

-- After "extraEntities", so every other system has already claimed its rooms.
event.levelLoad.add("apPlaceExtras", { order = "activationRange", sequence = -1 }, function(ev)
    local contents = queued
    queued = {}
    claimedFloor, claimedShell, carvedCentres = {}, {}, {}

    if #contents == 0 or not apUtils.isAPContext() then return end

    local channel = rng.makeChannel(ev.seed or 0,
        (ev.zone or 0) * 100 + (ev.floor or 0), 7731)

    local candidates = rankedRooms(channel)
    local cursor = 1

    for _, entry in ipairs(contents) do
        local coord

        -- A carved closet or nothing, never a fallback into a generated room.
        if entry.secret then
            local closet = carveCloset(channel)

            if closet then
                coord = {
                    closet[1] + rng.int(closet[3], channel),
                    closet[2] + rng.int(closet[4], channel),
                }
            else
            end
        else
            while not coord and cursor <= #candidates do
                local tiles = tilesIn(candidates[cursor].room)
                cursor = cursor + 1

                if #tiles > 0 then
                    coord = tiles[rng.int(#tiles, channel) + 1]
                end
            end
        end

        if coord then
            object.spawn(entry.entityType, coord[1], coord[2], entry.attributes)
        elseif entry.fallback then
            entry.fallback()
        end
    end
end)

return apExtrasRoom
