local collision = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"
local gameSession = require "necro.client.GameSession"
local object = require "necro.game.object.Object"
local player = require "necro.game.character.Player"
local predictor = require "necro.game.system.Predictor"
local priceTag = require "necro.game.item.PriceTag"
local rng = require "necro.game.system.RNG"

local apExtrasRoom = require("AP.scripts.level.apExtrasRoom")
local apLocationItem = require("AP.scripts.utils.apLocationItem")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local REGULAR_FLOORS = 3

-- Boss chests are a separate check with separate rules; see apFlawlessChests.
local ZONE_ITEM = "Item"

local claimedLocations = {}
local claimedTiles = {}

claimedLocations, claimedTiles = script.persist(function()
    return claimedLocations, claimedTiles
end)

claimedLocations = claimedLocations or {}
claimedTiles = claimedTiles or {}

local function isClaimed(located)
    return claimedLocations[tostring(located.LocationCode)] == true
end

-- A tile carries one location at most, however many things are standing on it.
local function tileClaimed(x, y)
    return claimedTiles[x .. "," .. y] == true
end

local function claim(located, x, y)
    claimedLocations[tostring(located.LocationCode)] = true
    claimedTiles[x .. "," .. y] = true
end

local function nextLocation()
    return progression.getNextChestLocation(currentLevel.getZone(), ZONE_ITEM, isClaimed)
end

local function itemChecksActive()
    if not apUtils.isAPContext() then return false end
    -- Boss Rush hands out three chests at the start of the run.
    if gameSession.getCurrentMode().id == "APBossRush" then return false end

    return not predictor.isGameStateSpeculative()
end

-- Seeded per carrier so every client agrees on which ones carry a location.
local function rollsCheck(carrier)
    local chance = progression.getItemChance()
    if chance >= 100 then return true end

    local channel = rng.makeChannel(
        currentLevel.getSeed(),
        currentLevel.getZone() * 100 + currentLevel.getFloor(),
        carrier.position.x * 1000 + carrier.position.y
    )

    return rng.range(1, 100, channel) <= chance
end

-- Puts the next unclaimed zone location into the container.
local function stockContainer(container)
    local x, y = container.position.x, container.position.y
    if tileClaimed(x, y) then return false end

    local located = nextLocation()
    if not located then return false end
    if not rollsCheck(container) then return false end

    local locationName = located.Location
    if not locationName or locationName == "" then return false end

    if not apLocationItem.store(container, located, locationName) then return false end

    claim(located, x, y)

    return true
end

-- Moves the pedestal's existing tag onto whatever now stands there.
local function transferPriceTag(from, to)
    local tag = from.sale and ecs.getEntityByID(from.sale.priceTag)
    if not (tag and to.sale) then return false end

    priceTag.add(to, tag)
    from.sale.priceTag = 0

    return true
end

-- An arena rune and a choice shrine both mark their offers with their own entity ID, which
-- is what starts the fight and clears the offers not taken.
local function transferSingleChoice(from, to)
    local choice = from.item.singleChoice
    if choice == 0 or not to.item then return end

    to.item.singleChoice = choice
    from.item.singleChoice = 0
end

local function byPosition(a, b)
    if a.position.y ~= b.position.y then return a.position.y < b.position.y end
    return a.position.x < b.position.x
end

-- object.delete only flags the entity; it stays enumerable until the next flush. Shop
-- wares are spawned and then deleted in the same breath when the shopkeeper is already
-- dead, and "initialItems" does that before this runs, so the dying ones are still here.
local function isLive(entity)
    return not entity.gameObject.despawned
end

-- Every container on the floor, in a fixed order so each client stocks the same ones.
local function containersInLevel()
    local containers = {}

    for container in ecs.entitiesWithComponents({ "AP_container", "storage" }) do
        if isLive(container) then containers[#containers + 1] = container end
    end

    table.sort(containers, byPosition)

    return containers
end

-- Every item standing on its own tile, priced or not, in a fixed order.
local function looseItemsInLevel()
    local items = {}

    for item in ecs.entitiesWithComponents({ "item", "position" }) do
        if isLive(item)
            and item.item.dropped and item.item.holder == 0
            and not item.itemCurrency
            and not item.AP_noReplace
            and (not item.storable or item.storable.container == 0)
        then
            items[#items + 1] = item
        end
    end

    table.sort(items, byPosition)

    return items
end

-- Replaces the item on the tile with the AP item, keeping any price tag it had.
local function stockLooseItem(item)
    local x, y = item.position.x, item.position.y

    -- A check already took this tile, so the level's own item goes with the one it replaced.
    if tileClaimed(x, y) then
        object.delete(item)
        return false
    end

    local located = nextLocation()
    if not located then return false end
    if not rollsCheck(item) then return false end

    local locationName = located.Location
    if not locationName or locationName == "" then return false end

    local priced = item.sale and item.sale.priceTag ~= 0
    if priced and not ecs.getEntityByID(item.sale.priceTag) then return false end

    local replacement = apLocationItem.spawn(located, locationName, x, y)
    if not replacement then return false end

    if priced and not transferPriceTag(item, replacement) then
        object.delete(replacement)
        return false
    end

    transferSingleChoice(item, replacement)

    claim(located, x, y)
    object.delete(item)

    return true
end

event.levelLoad.add("apLoadMidrunLocations", { order = "extraEntities", sequence = 1 }, function()
    claimedLocations = {}
    claimedTiles = {}

    if not itemChecksActive() then return end
    if currentLevel.isLobby() or currentLevel.isBoss() then return end
    if not progression.getItemChecks() then return end

    for _, container in ipairs(containersInLevel()) do
        stockContainer(container)
    end

    for _, item in ipairs(looseItemsInLevel()) do
        stockLooseItem(item)
    end
end)

--------------------------------------------------------------------------------
-- Upgrade chests
--------------------------------------------------------------------------------

local function spawnUpgradeChest(upgrade, anchor, channel)
    apExtrasRoom.add(upgrade.chest, nil, {
        fallback = function()
            local tiles = collision.getVacantTiles(
                anchor, 2, 9, 9, false,
                collision.Group.ITEM_PLACEMENT
            )
            if #tiles == 0 then return end

            local tile = rng.choice(tiles, channel)
            object.spawn(upgrade.chest, tile[1], tile[2])
        end,
    })
end

local function upgradesForFloor(seed, zone, floor)
    local picks = {}

    for _, proto in ecs.prototypesWithComponents({ "AP_chestUpgrade" }) do
        if progression.getItems(proto.name) then
            local upgrade = proto.AP_chestUpgrade
            local channel = rng.makeChannel(seed, zone, upgrade.order)

            if rng.range(1, REGULAR_FLOORS, channel) == floor then
                picks[#picks + 1] = { upgrade = upgrade, channel = channel }
            end
        end
    end

    -- Prototype order is not guaranteed; the room each chest claims depends on it.
    table.sort(picks, function(a, b) return a.upgrade.order < b.upgrade.order end)

    return picks
end

apExtrasRoom.demand("apUpgradeChests", function(entry, ev)
    if ev.modeID == "APBossRush" then return 0 end
    return #upgradesForFloor(ev.options.seed, entry.zone, entry.floor)
end)

-- Runs once the level's own chests and enemies are already placed.
event.levelLoad.add("apSpawnUpgradeChests", { order = "extraEntities" }, function()
    if not apUtils.isAPContext() then return end
    if gameSession.getCurrentMode().id == "APBossRush" then return end
    if currentLevel.isBoss() then return end

    local anchor = player.getPlayerEntities()[1]
    if not anchor then return end

    local picks = upgradesForFloor(currentLevel.getSeed(), currentLevel.getZone(), currentLevel.getFloor())

    for _, pick in ipairs(picks) do
        spawnUpgradeChest(pick.upgrade, anchor, pick.channel)
    end
end)
