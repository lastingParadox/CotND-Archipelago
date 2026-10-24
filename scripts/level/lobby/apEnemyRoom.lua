local ecs = require("system.game.Entities")
local marker = require "necro.game.tile.Marker"
local object = require("necro.game.object.Object")

local apItemRoom = require("AP.scripts.level.lobby.apItemRoom")
local apItemShowcase = require("AP.scripts.entities.apItemShowcase")
local lobbyUtils = require("AP.scripts.utils.lobbyUtils")
local progression = require("AP.scripts.client.progression")

local apEnemyRoom = {}

local HUB_WIDTH = 15
local HUB_HEIGHT = 9
local HUB_MIN_Y = -6
local STAIR_DY = 6
local PITCH = 2
local MINIBOSS_PITCH = 3

local GROUPS = { "zone1", "zone2", "zone3", "zone4", "zone5", "miniboss" }

local function groupOf(proto, zone)
    return proto.enemyPoolMiniboss and "miniboss" or ("zone" .. zone)
end

local function prototypesIn(component)
    return select(2, ecs.prototypesWithComponents({ component }))
end

-- The slot's enemy checks, or the engine's enemy pools for this world's zones when it has none.
local function enemyZones()
    local zones = progression.getEnemyZones()
    if next(zones) then return zones end

    local pooled = {}

    for zone = 1, progression.isDLCEnabled("Amplified") and 5 or 4 do
        for _, proto in ipairs(prototypesIn("enemyPoolZone" .. zone)) do
            pooled[proto.name] = zone
        end
    end

    for _, proto in ipairs(prototypesIn("enemyPoolMiniboss")) do
        pooled[proto.name] = 1
    end

    return pooled
end

-- Every enemy, bucketed by the hub stair that leads to it.
local function collectGroups()
    local byGroup = {}

    for entityName, zone in pairs(enemyZones()) do
        local proto = ecs.getEntityPrototype(entityName)

        if proto then
            local key = groupOf(proto, zone)
            byGroup[key] = byGroup[key] or {}
            table.insert(byGroup[key], entityName)
        end
    end

    local groups = {}

    for _, key in ipairs(GROUPS) do
        local names = byGroup[key]

        if names then
            table.sort(names)
            groups[#groups + 1] = { key = key, names = names }
        end
    end

    return groups
end

local function spawnEnemyShowcase(entityName, x, y)
    object.spawn("AP_ItemShowcase", x, y, {
        AP_itemShowcase = { active = true, item = entityName, category = "enemy" },
    })

    local location = progression.getEnemyLocation(entityName)
    local data = { label = location and location:gsub("^Defeat ", "") or nil }
    lobbyUtils.addTextLabel(x, y,
        apItemShowcase.getShowcaseLabel(entityName, data, ecs.getEntityPrototype(entityName)), 10, PITCH)
end

---Builds the enemy hub and its chambers, with the way in at (x, y).
---@return boolean built
function apEnemyRoom.generateEnemyRoom(x, y)
    local groups = collectGroups()
    if #groups == 0 then return false end

    local layouts = {}
    for index, group in ipairs(groups) do
        layouts[index] = apItemRoom.chamberLayout(#group.names,
            group.key == "miniboss" and MINIBOSS_PITCH or PITCH)
    end

    apItemRoom.reserveLevelSpace(HUB_WIDTH, HUB_HEIGHT, layouts)

    local hubMinX, _, hubMinY = lobbyUtils.addRoom(HUB_WIDTH, HUB_HEIGHT, HUB_MIN_Y, "Zone2")
    local hubCenterX = hubMinX + math.floor(HUB_WIDTH / 2)

    lobbyUtils.addDestination(x, y, hubCenterX, hubMinY + 3, "mod.AP.lobby.enemyRoom", "TriggerTravelPrimaryOnly")

    local apLobbyX, apLobbyY = marker.lookUpFirst(marker.Type.AP_SPAWN)
    lobbyUtils.addDestination(hubMinX + 2, hubMinY + 3, apLobbyX, apLobbyY,
        "mod.AP.lobby.stairBack", "TriggerTravelPrimaryOnly")

    lobbyUtils.addLabel(hubCenterX, hubMinY + 2, "mod.AP.lobby.enemyHub", 3)
    lobbyUtils.addLabel(hubCenterX, hubMinY + 4, "mod.AP.lobby.enemyHubHint", -6)

    for index, group in ipairs(groups) do
        local stairX = hubCenterX - (#groups - 1) + (index - 1) * PITCH
        local stairY = hubMinY + STAIR_DY
        local titleKey = "mod.AP.lobby.enemyCat." .. group.key

        local arrivalX, arrivalY = apItemRoom.buildChamber(titleKey, "mod.AP.lobby.stairBackEnemyHub",
            layouts[index], stairX, stairY, group.names, spawnEnemyShowcase)

        lobbyUtils.addDestination(stairX, stairY, arrivalX, arrivalY, nil, "TriggerTravelPrimaryOnly")
        lobbyUtils.addLabelForced(stairX, stairY, titleKey, nil, PITCH)
    end

    return true
end

return apEnemyRoom
