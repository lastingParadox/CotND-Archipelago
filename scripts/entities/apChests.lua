local collision = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"
local gameSession = require "necro.client.GameSession"
local itemGeneration = require "necro.game.item.ItemGeneration"
local itemStorage = require "necro.game.item.ItemStorage"
local object = require "necro.game.object.Object"
local player = require "necro.game.character.Player"
local predictor = require "necro.game.system.Predictor"
local rng = require "necro.game.system.RNG"

local apExtrasRoom = require("AP.scripts.level.apExtrasRoom")
local apLocationItem = require("AP.scripts.utils.apLocationItem")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local REGULAR_FLOORS = 3

-- chest entity ID -> { kind = <chest colour>, loot = <the roll it gave up> }
local stockedChests = {}
stockedChests = script.persist(function() return stockedChests end)

local function chestChecksActive()
    if not apUtils.isAPContext() then return false end
    -- Boss Rush hands out three chests at the start of the run.
    if gameSession.getCurrentMode().id == "APBossRush" then return false end

    return not predictor.isGameStateSpeculative()
end

-- Seeded per chest so every client agrees on which ones carry a check.
local function rollsCheck(chest)
    local chance = progression.getChestCheckChance()
    if chance >= 100 then return true end

    local channel = rng.makeChannel(
        currentLevel.getSeed(),
        currentLevel.getZone() * 100 + currentLevel.getFloor(),
        chest.position.x * 1000 + chest.position.y
    )

    return rng.range(1, 100, channel) <= chance
end

-- Every chest of the colour that wins its roll holds the next unclaimed check, so
-- the player can open whichever they reach first and the monocle tells the truth
-- about all of them.
local function stockChest(chest, kind)
    local zone = currentLevel.getZone()
    local located = progression.getNextChestLocation(zone, kind)
    if not located then return end
    if not rollsCheck(chest) then return end

    -- A generated chest holds a type name. Anything already spawned would have to
    -- be detached rather than overwritten, so those keep their own roll.
    local loot = chest.storage.items[1]
    if loot ~= nil and type(loot) ~= "string" then return end

    -- Sent by the client, since the location name carries an index the mod would
    -- otherwise have to guess at.
    local locationName = located.Location
    if not locationName or locationName == "" then return end

    local item = apLocationItem.spawn(located, locationName, chest.position.x, chest.position.y)
    if not item then return end

    if not itemStorage.replaceIndex(chest, 1, item.id) then
        itemStorage.store(item.id, chest)
    end

    stockedChests[chest.id] = { kind = kind, loot = loot }
end

-- The check has been claimed, so the chests that lost the race take their own roll
-- back and stop advertising an item that is no longer theirs to give.
local function releaseKind(kind)
    for chestID, entry in pairs(stockedChests) do
        if entry.kind == kind then
            local chest = ecs.getEntityByID(chestID)

            if chest then
                if entry.loot then
                    itemStorage.replaceIndex(chest, 1, entry.loot)
                else
                    itemStorage.deleteIndex(chest, 1)
                end
            end

            stockedChests[chestID] = nil
        end
    end
end

local function byPosition(a, b)
    if a.position.y ~= b.position.y then return a.position.y < b.position.y end
    return a.position.x < b.position.x
end

event.levelLoad.add("apLoadChestChecks", { order = "extraEntities", sequence = 1 }, function()
    stockedChests = {}

    if not chestChecksActive() then return end
    if currentLevel.isBoss() then return end
    if not progression.getChestChecks() then return end

    local kinds, byKind = {}, {}

    for chest in ecs.entitiesWithComponents({ "AP_chestKind", "storage" }) do
        local kind = chest.AP_chestKind.kind

        if kind ~= "" then
            if not byKind[kind] then
                byKind[kind] = {}
                kinds[#kinds + 1] = kind
            end

            table.insert(byKind[kind], chest)
        end
    end

    -- Spawning the items in a fixed order keeps entity IDs identical everywhere.
    table.sort(kinds)

    for _, kind in ipairs(kinds) do
        local chests = byKind[kind]
        table.sort(chests, byPosition)

        for _, chest in ipairs(chests) do
            stockChest(chest, kind)
        end
    end
end)

-- After "storageInit" filled the chest, before "markSeen" reads it.
event.objectSpawn.add("apStockFlawlessChest", { filter = "chestLike", order = "markSeen", sequence = -1 },
    function(ev)
        if not chestChecksActive() then return end
        if not (currentLevel.isBoss() and progression.getFlawlessChestChecks()) then return end

        stockChest(ev.entity, "Flawless")
    end)

event.objectDeath.add("apChestOpened", { filter = "chestLike", order = "itemDrop", sequence = -1 },
    function(ev)
        local entry = stockedChests[ev.entity.id]
        if not entry then return end

        stockedChests[ev.entity.id] = nil
        releaseKind(entry.kind)
    end)

local function spawnUpgradeChest(upgrade, anchor, channel)
    local item = itemGeneration.choice({
        chanceType = upgrade.chanceType,
        default = "ResourceHoardGold",
    })
    local attributes = { storage = { items = { item } } }

    apExtrasRoom.add(upgrade.chest, attributes, {
        fallback = function()
            local tiles = collision.getVacantTiles(
                anchor, 2, 9, 9, false,
                collision.mask(collision.Group.SOLID, collision.Type.TRAP)
            )
            if #tiles == 0 then return end

            local tile = rng.choice(tiles, channel)
            object.spawn(upgrade.chest, tile[1], tile[2], attributes)
        end,
    })
end

-- One extra chest per zone per upgrade. The seed is the run's, not the level's, so
-- this answers the same before the run starts as it does on the floor itself.
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

-- After "initialItems", so the level's own chests and enemies are already placed
-- and the vacant-tile search accounts for them.
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

