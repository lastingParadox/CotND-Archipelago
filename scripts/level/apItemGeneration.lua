local bitAnd = bit.band
local bitXor = bit.bxor
local currency     = require "necro.game.item.Currency"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs          = require "system.game.Entities"
local flyaway      = require "necro.game.system.Flyaway"
local itemGeneration = require "necro.game.item.ItemGeneration"
local itemPickup   = require "necro.game.item.ItemPickup"
local object       = require "necro.game.object.Object"
local randomPool   = require "system.utils.RandomPool"
local rng          = require "necro.game.system.RNG"
local stringHash   = require("system.utils.StringHash")
local targeting    = require "necro.game.enemy.Targeting"

local apUtils   = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local itemPoolCache = {}

event.shopkeeperTransaction.add("apSpawnItemFallback", {
    filter = "transactionSpawnItem",
    order = "spawnItem",
    sequence = 1,
}, function(ev)
    if not apUtils.isAPContext()
        or not ev.error
        or ev.error ~= ev.shopkeeper.transactionSpawnItem.errorFlyaway
    then
        return
    end

    local newItemType = itemGeneration.choice({
        chanceType = ev.shopkeeper.transactionSpawnItem.chanceType,
        levelBonus = ev.shopkeeper.transactionSpawnItem.levelBonus,
        slot = ev.slot,
        player = ev.client,
        transmutedItem = ev.item,
        levelOverride = 2
    })

    if newItemType then
        ev.error = nil
        ev.newItem = object.spawn(newItemType, ev.x, ev.y - 1)

        object.moveToNearbyVacantTile(ev.newItem, ev.shopkeeper.transactionSpawnItem.collisionMask)
    else
        ev.error = "No items left in the\n" .. ev.shopkeeper.transactionSpawnItem.chanceType .. " item pool!"
    end
end)


local PAWNBROKER_PRICED_ITEMS = {
    Sync_SpellCharm = true,
    Sync_WeaponLantern = true,
    FeetBootsLunging = true,
}

event.entitySchemaLoadEntity.add("apPawnbrokerPricing", "overrides", function(ev)
    if PAWNBROKER_PRICED_ITEMS[ev.entity.name] then
        ev.entity.AP_pawnbrokerPricing = {}
    end
end)

-- Vision is a party union, so the engine never records who revealed it; nearest
-- player is the closest stand-in.
local function pawnbrokerCost(item)
    local gold
    if currency.isShared(currency.Type.GOLD) then
        gold = currency.get(nil, currency.Type.GOLD)
    else
        local buyer = targeting.getNearestPlayer(item.position.x, item.position.y)
        gold = buyer and currency.get(buyer, currency.Type.GOLD) or 0
    end

    return math.max(2, gold) - 1
end

-- The pawnbroker priced items apply their cost when revealed for the first time in a level
event.objectReveal.add("apApplyPawnbrokerPricing", { filter = "AP_pawnbrokerPricing", order = "aggro" }, function(ev)
    if not apUtils.isAPContext() then return end

    local item = ev.entity
    if not item.sale or item.sale.priceTag == 0 or not item.position then return end

    local tag = ecs.getEntityByID(item.sale.priceTag)
    if tag and tag.priceTagCostCurrency then
        tag.priceTagCostCurrency.cost = pawnbrokerCost(item)
    end
end)

event.itemGenerate.add("apSetLevelOverride", { order = "initParameters", sequence = 1 }, function(ev)
    if ev.levelOverride and ev.levelOverride ~= 0 then
        ev.level = ev.levelOverride

        local cacheKey = string.format("%s|%d", table.concat(ev.requiredComponents, "|"), ev.level)
        ev.seed = bitXor(bitAnd(stringHash.hash32(cacheKey), 134217727), currentLevel.getSeed())
        ev.cacheKey = string.format("%s|%d", cacheKey, ev.seed)
    end
end)

event.itemGenerate.add("apBanUnownedItems", { order = "initParameters", sequence = 2 }, function(ev)
    if not apUtils.isAPContext() then return end

    local originalFilter = ev.filter
    ev.filter = function(item, args, player)
        local itemName = item.name

        if progression.getItems(itemName) and not progression.getBannedItems(itemName) then
            return originalFilter(item, args, player)
        end

        return false
    end
end)

local function collectWeightedItems(itemTypes, itemWeights, components, weightComponent, tier)
    for _, entity in ecs.prototypesWithComponents(components) do
        local comp = entity[weightComponent]
        if not comp then
            goto continue
        end

        local weights = comp.weights
        local weight = weights[tier] or weights[#weights] or 0

        if weight > 0 then
            itemTypes[#itemTypes + 1] = entity
            itemWeights[#itemWeights + 1] = weight
        end

        ::continue::
    end
end

local function generateWeightedItemPool(requiredComponents, weightComponent, tier, seed)
    local itemTypes = {}
    local itemWeights = {}

    collectWeightedItems(
        itemTypes,
        itemWeights,
        requiredComponents,
        weightComponent,
        tier
    )

    local hasWeightComponent = false
    for _, c in ipairs(requiredComponents) do
        if c == weightComponent then
            hasWeightComponent = true
            break
        end
    end

    if hasWeightComponent then
        local apComponents = {}
        local apWeightComponent = "AP_" .. weightComponent

        for i, c in ipairs(requiredComponents) do
            apComponents[i] = (c == weightComponent) and apWeightComponent or c
        end

        collectWeightedItems(
            itemTypes,
            itemWeights,
            apComponents,
            apWeightComponent,
            tier
        )
    end

    return randomPool.new(seed, itemTypes, itemWeights)
end

local function generateUnweightedItemPool(requiredComponents, weightComponent, seed)
    local itemTypes = {}
    local seen = {}

    for _, entity in ecs.prototypesWithComponents(requiredComponents) do
        if not seen[entity.name] then
            seen[entity.name] = true
            itemTypes[#itemTypes + 1] = entity
        end
    end

    local hasWeightComponent = false
    for _, c in ipairs(requiredComponents) do
        if c == weightComponent then
            hasWeightComponent = true
            break
        end
    end

    if hasWeightComponent then
        local apComponents = {}
        local apWeightComponent = "AP_" .. weightComponent

        for i, c in ipairs(requiredComponents) do
            apComponents[i] = (c == weightComponent) and apWeightComponent or c
        end

        for _, entity in ecs.prototypesWithComponents(apComponents) do
            if not seen[entity.name] then
                seen[entity.name] = true
                itemTypes[#itemTypes + 1] = entity
            end
        end
    end

    return randomPool.new(seed, itemTypes)
end

event.itemGenerate.override("initializeRandomPool", function(func, ev)
    if not apUtils.isAPContext() then
        return func(ev)
    end

    if not ev.result and not ev.randomPool and not ev.chanceFunction then
        if itemPoolCache[ev.cacheKey] then
            ev.randomPool = itemPoolCache[ev.cacheKey]
        else
            if ev.itemPool then
                ev.randomPool = generateWeightedItemPool(ev.requiredComponents, ev.itemPool, ev.level, ev.seed)
            else
                ev.randomPool = generateUnweightedItemPool(ev.requiredComponents, ev.seed)
            end

            if ev.cacheKey then
                itemPoolCache[ev.cacheKey] = ev.randomPool
            end
        end
    end
end)

event.gameStateLevel.add("apInvalidateItemPoolCaches", { order = "itemPools" }, function()
    itemPoolCache = {}
end)
event.gameStateLevel.add("apClearItemPoolCaches", { order = "clearItemPoolCache" }, function()
    itemPoolCache = {}
end)
event.ecsSchemaReloaded.add("apClearItemPoolCaches", { order = "clearCache" }, function()
    itemPoolCache = {}
end)

-- In AP context, filter the uncertainty shrine to only weapons whose base form is unlocked.
-- If no candidates: give 50g fallback (skipped for goldHater/Monk) and show a flyaway.
event.shrine.override("uncertainty", function(func, ev)
    if not apUtils.isAPContext() then
        return func(ev)
    end

    local candidates = {}
    -- "weapon", not "weaponCommon": the latter is not a component.
    for _, entity in ecs.prototypesWithComponents({ "itemPoolUncertainty", "weapon" }) do
        local name = entity.name
        local baseName = name:sub(1, -10)  -- strip "Uncertain" (9 chars)
        if progression.getItems(baseName) and not progression.getBannedItems(baseName) then
            candidates[#candidates + 1] = name
        end
    end

    if #candidates == 0 then
        ev.entity.shrine.active = false
        if not ev.interactor.goldHater then
            currency.add(ev.interactor, currency.Type.GOLD, 50)
        end
        flyaway.create({
            entity  = ev.entity,
            offsetY = 7,
            text    = "No weapons in uncertainty pool!",
        })
        return
    end

    local chosen = candidates[rng.int(#candidates, ev.interactor)]
    local item   = object.spawn(chosen, ev.interactor.position.x, ev.interactor.position.y)
    itemPickup.tryCollect(item, ev.interactor, true)
end)
