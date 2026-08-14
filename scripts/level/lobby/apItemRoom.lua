local ecs = require("system.game.Entities")
local marker = require "necro.game.tile.Marker"
local object = require("necro.game.object.Object")
local tile = require("necro.game.tile.Tile")
local tileTypes = require("necro.game.tile.TileTypes")

local apClient = require("AP.scripts.client.client")
local apItemShowcase = require("AP.scripts.entities.apItemShowcase")
local lobbyUtils = require("AP.scripts.utils.lobbyUtils")

local apItemRoom = {}

local HUB_WIDTH = 15
local HUB_HEIGHT = 19
local HUB_MIN_Y = -6

local GAME_ROWS = {
    { dy = 6,  capacity = 5 },
    { dy = 8,  capacity = 5 },
    { dy = 10, capacity = 3 },
}
local DIVIDER_DY = 13
local DIVIDER_GAP = { [6] = true, [7] = true, [8] = true }
local AP_ROW = { dy = DIVIDER_DY + 3, capacity = 6 }

local CHAMBER_COLUMNS = 6
local CHAMBER_MIN_WIDTH = 9
local CHAMBER_MIN_HEIGHT = 8
local STAIR_DX = 2
local PITCH = 2

local HUB_CENTER_DX = math.floor(HUB_WIDTH / 2)

-- Slot offsets for `count` stairs spaced by PITCH, centred on the hub. A row
-- holds fewer than its capacity whenever the slot's options empty a category.
local function centeredColumns(count)
    local columns = {}

    for index = 1, count do
        columns[index] = HUB_CENTER_DX - (count - 1) + (index - 1) * PITCH
    end

    return columns
end

local function chamberLayout(count)
    -- Squarest grid that holds them, so a category does not stretch into one
    -- long row.
    local cols = math.min(CHAMBER_COLUMNS, math.ceil(math.sqrt(count)))
    local rows = math.ceil(count / cols)

    return {
        cols = cols,
        rows = rows,
        width = math.max(CHAMBER_MIN_WIDTH, STAIR_DX + (cols - 1) * PITCH + 3),
        height = math.max(CHAMBER_MIN_HEIGHT, rows * PITCH + 6),
    }
end

local function generateChamber(group, layout, hubX, hubY)
    local descriptor = group.descriptor
    local minX, _, minY = lobbyUtils.addRoom(layout.width, layout.height, HUB_MIN_Y, "Zone2")

    local centerX = minX + math.floor(layout.width / 2)

    lobbyUtils.addLabelForced(centerX, minY + 1, "mod.AP.lobby.itemCat." .. descriptor.id, 3,
        layout.width - 2)

    lobbyUtils.addDestination(minX + STAIR_DX, minY + 2, hubX, hubY, "mod.AP.lobby.stairBackHub",
        "TriggerTravelPrimaryOnly")

    for index, entry in ipairs(group.items) do
        local column = (index - 1) % layout.cols
        local row = math.floor((index - 1) / layout.cols)
        local itemX = minX + STAIR_DX + column * PITCH
        local itemY = minY + 4 + row * PITCH

        object.spawn("AP_ItemShowcase", itemX, itemY,
            { AP_itemShowcase = { active = true, item = entry.name } })

        local proto = ecs.getEntityPrototype(entry.data.preview or entry.name)
        lobbyUtils.addTextLabel(itemX, itemY,
            apItemShowcase.getShowcaseLabel(entry.name, entry.data, proto), 10, PITCH)
    end

    return minX + STAIR_DX, minY + 3
end

function apItemRoom.generateItemRoom(x, y)
    if not apClient.isSessionConnected() then
        return false
    end

    local groups = apItemShowcase.getShowcaseCategories()

    local populated = {}
    for _, group in ipairs(groups) do
        if #group.items > 0 then
            populated[group.descriptor.id] = group
        end
    end

    local gameGroups, apGroups = {}, {}

    for _, descriptor in ipairs(apItemShowcase.categories) do
        local group = populated[descriptor.id]
        if group then
            local section = descriptor.section == "ap" and apGroups or gameGroups
            section[#section + 1] = group
        end
    end

    -- How many stairs each game row ends up holding, so the pillars flanking the
    -- last row can hug it however many categories the slot leaves.
    local rowCounts = {}
    local assigned = 0
    for index, row in ipairs(GAME_ROWS) do
        rowCounts[index] = math.max(0, math.min(row.capacity, #gameGroups - assigned))
        assigned = assigned + rowCounts[index]
    end

    local hubMinX, _, hubMinY = lobbyUtils.addRoom(HUB_WIDTH, HUB_HEIGHT, HUB_MIN_Y, "Zone2")
    local hubCenterX = hubMinX + math.floor(HUB_WIDTH / 2)

    lobbyUtils.addDestination(x, y, hubCenterX, hubMinY + 3, "mod.AP.lobby.itemRoom",
        "TriggerTravelPrimaryOnly")

    local apLobbyX, apLobbyY = marker.lookUpFirst(marker.Type.AP_SPAWN)
    lobbyUtils.addDestination(hubMinX + STAIR_DX, hubMinY + 3, apLobbyX, apLobbyY,
        "mod.AP.lobby.stairBack", "TriggerTravelPrimaryOnly")

    lobbyUtils.addLabel(hubCenterX, hubMinY + 2, "mod.AP.lobby.itemHub", 3)
    lobbyUtils.addLabel(hubCenterX, hubMinY + 4, "mod.AP.lobby.itemHubHint", -6)

    local wall = tileTypes.lookUpTileID("UnbreakableWall", tileTypes.lookUpZoneID("Zone2"))

    -- One pitch outside each end of the last row, so they bookend it rather than
    -- sitting at a width the row may no longer be.
    local pillarRow = GAME_ROWS[#GAME_ROWS]
    local pillarColumns = centeredColumns(rowCounts[#GAME_ROWS])

    if #pillarColumns > 0 then
        for _, dx in ipairs({ pillarColumns[1] - PITCH, pillarColumns[#pillarColumns] + PITCH }) do
            tile.set(hubMinX + dx, hubMinY + pillarRow.dy, wall)
            lobbyUtils.addTorch(hubMinX + dx, hubMinY + pillarRow.dy)
        end
    end

    lobbyUtils.addRect(hubMinX, hubMinY + DIVIDER_DY, HUB_WIDTH, HUB_HEIGHT - DIVIDER_DY,
        wall, tileTypes.lookUpTileID("Grass1", tileTypes.lookUpZoneID("Zone2")))

    for dx in pairs(DIVIDER_GAP) do
        lobbyUtils.clearTile(hubMinX + dx, hubMinY + DIVIDER_DY, "Zone2")
    end

    lobbyUtils.addLabel(hubCenterX, hubMinY + DIVIDER_DY + 1, "mod.AP.lobby.itemHub.apSection", 3)

    local stairs = {}

    local function placeRow(list, first, count, dy)
        local columns = centeredColumns(count)

        for index = 1, count do
            stairs[#stairs + 1] = {
                group = list[first + index - 1],
                x = hubMinX + columns[index],
                y = hubMinY + dy,
                tiles = PITCH,
            }
        end
    end

    local placed = 0
    for index, row in ipairs(GAME_ROWS) do
        local count = rowCounts[index]
        if count <= 0 then break end

        placeRow(gameGroups, placed + 1, count, row.dy)
        placed = placed + count
    end

    placeRow(apGroups, 1, math.min(AP_ROW.capacity, #apGroups), AP_ROW.dy)

    for _, stair in ipairs(stairs) do
        local layout = chamberLayout(#stair.group.items)
        local arrivalX, arrivalY = generateChamber(stair.group, layout, stair.x, stair.y)

        lobbyUtils.addDestination(stair.x, stair.y, arrivalX, arrivalY, nil, "TriggerTravelPrimaryOnly")
        lobbyUtils.addLabelForced(stair.x, stair.y,
            "mod.AP.lobby.itemCat." .. stair.group.descriptor.id, nil, stair.tiles)
    end

    return true
end

return apItemRoom
