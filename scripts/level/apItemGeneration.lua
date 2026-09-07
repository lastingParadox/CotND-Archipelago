local bitAnd         = bit.band
local bitXor         = bit.bxor
local currency       = require "necro.game.item.Currency"
local currentLevel   = require "necro.game.level.CurrentLevel"
local ecs            = require "system.game.Entities"
local flyaway        = require "necro.game.system.Flyaway"
local itemGeneration = require "necro.game.item.ItemGeneration"
local itemPickup     = require "necro.game.item.ItemPickup"
local object         = require "necro.game.object.Object"
local objectMap      = require "necro.game.object.Map"
local randomPool     = require "system.utils.RandomPool"
local rng            = require "necro.game.system.RNG"
local stringHash     = require("system.utils.StringHash")
local targeting      = require "necro.game.enemy.Targeting"

local apUtils        = require("AP.scripts.utils.apUtils")
local progression    = require("AP.scripts.client.progression")

local itemPoolCache  = {}

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

-- Nearest player stands in for the revealer, since vision is a party union.
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

-- The blood shrine, the glass shop and the glass shrines all pin the material they hand out.
local function pinsWeaponMaterial(requiredComponents)
    for _, name in ipairs(requiredComponents or {}) do
        if name:find("weaponMaterial", 1, true) then return true end
    end

    return false
end

-- The shape behind a material variant, read off weaponType rather than parsed from the name
local function baseWeaponName(item)
    if not item.weaponType or item.weaponType.name == "" then return nil end

    local prefix = item.name:match("^(.-)Weapon")
    if not prefix then return nil end

    return prefix .. "Weapon" .. item.weaponType.name
end

event.itemGenerate.add("apBanUnownedItems", { order = "initParameters", sequence = 2 }, function(ev)
    if not apUtils.isAPContext() then return end
    if ev.AP_ignoreOwnership then return end

    -- A request that pins a material is granting that material
    local materialGranted = pinsWeaponMaterial(ev.requiredComponents)

    local originalFilter = ev.filter
    ev.filter = function(item, args, player)
        local itemName = item.name
        local owned = progression.getItems(itemName)

        if not owned and materialGranted then
            local base = baseWeaponName(item)
            owned = base ~= nil and progression.getItems(base)
        end

        if owned and not progression.getBannedItems(itemName) then
            return originalFilter(item, args, player)
        end

        return false
    end
end)

-- Unlocked and not sitting in the janitor's ban list.
local function isAvailableItem(itemName)
    return progression.getItems(itemName) and not progression.getBannedItems(itemName)
end

-- Swaps a placed item for a generated one, keeping the tile and the offer it belongs to.
local function replacePlacedItem(item, genArgs)
    local replacement = itemGeneration.choice(genArgs)
    if not replacement or replacement == "" then return false end

    local choice = item.item.singleChoice
    local spawned = object.spawn(itemGeneration.maybeMarkSeen(replacement),
        item.position.x, item.position.y)

    if not spawned then return false end
    if spawned.item then spawned.item.singleChoice = choice end

    object.delete(item)

    return true
end

-- A shrine tags its fixed offers with its own ID, since they never reach the generation filter.
local function replaceUnavailableOffers(ev, genArgs)
    local offers = {}

    for item in ecs.entitiesWithComponents({ "item", "position" }) do
        if item.item.singleChoice == ev.entity.id and not isAvailableItem(item.name) then
            offers[#offers + 1] = item
        end
    end

    for _, item in ipairs(offers) do
        replacePlacedItem(item, genArgs)
    end
end

-- Three fixed shovels, none of which pass through generation.
event.shrine.override("space", function(func, ev)
    func(ev)

    if not apUtils.isAPContext() then return end

    replaceUnavailableOffers(ev, { chanceType = "chest", slot = "shovel", player = ev.interactor })
end)

-- Drops a fixed Blood Shovel beside the weapon it generates.
event.shrine.override("blood", function(func, ev)
    func(ev)

    if not apUtils.isAPContext() then return end

    local shovel = objectMap.firstWithComponent(ev.x, ev.y + 1, "item")

    if shovel and not isAvailableItem(shovel.name) then
        replacePlacedItem(shovel, { chanceType = "chest", slot = "shovel", player = ev.interactor })
    end
end)

-- Reads a name set off the request, since initializeParameters assigns ev.filter outright.
event.itemGenerate.add("apExcludeNamedItems", { order = "initParameters", sequence = 4 }, function(ev)
    local excluded = ev.AP_excludeNames
    if not excluded then return end

    local originalFilter = ev.filter
    ev.filter = function(item, args, player)
        if excluded[item.name] then return false end
        return originalFilter(item, args, player)
    end
end)

-- Every piece of glass gear the shop can stand in for, a superset of its own four.
local GLASS_STOCK = {
    "ArmorGlass",
    "ArmorHeavyglass",
    "HeadGlassJaw",
    "FeetGlassSlippers",
    "TorchGlass",
    "ShovelGlass",
}

-- Not an AP item, so it is never gated and always closes the chain.
local GLASS_FALLBACK = "ShovelShard"

local function generatedGlassWeapon(ev, excluded)
    local weapon = itemGeneration.choice({
        chanceType = "secret",
        requiredComponents = { ev.entity.generateShopGlass.component },
        AP_excludeNames = excluded,
    })

    return weapon ~= "" and weapon or nil
end

local function unlockedGlassGear(offered)
    local pool = {}

    for _, itemName in ipairs(GLASS_STOCK) do
        if isAvailableItem(itemName) and not (offered and offered[itemName]) then
            pool[#pool + 1] = itemName
        end
    end

    return pool
end

local function draw(pool, channel)
    if #pool == 0 then return nil end

    return pool[rng.int(#pool, channel) + 1]
end

-- Only once both fresh pools are dry, drawing a repeat from either.
local function drawGlassDuplicate(ev, channel)
    local pool = unlockedGlassGear(nil)
    local weapon = generatedGlassWeapon(ev, nil)

    if weapon then pool[#pool + 1] = weapon end

    return draw(pool, channel)
end

-- The glass shop takes two items off its own list, which never reach the filter above.
event.generateShopItems.add("apGlassShopUnlocks", {
    filter = "generateShopGlass",
    order = "all",
    sequence = 1,
}, function(ev)
    if not apUtils.isAPContext() then return end

    local offered = {}
    for _, itemName in ipairs(ev.items) do offered[itemName] = true end

    local channel = rng.makeChannel(
        ev.seed or 0,
        (ev.depth or 0) * 4344 + (ev.floor or 0) * 4340 + (ev.zone or 0),
        58121 -- unique salt for glass shop restocking
    )

    for index, itemName in ipairs(ev.items) do
        if not isAvailableItem(itemName) then
            -- Unshown gear, then unshown weapon, then a repeat, then the shard nobody can lock.
            local replacement = draw(unlockedGlassGear(offered), channel)
                or generatedGlassWeapon(ev, offered)
                or drawGlassDuplicate(ev, channel)
                or GLASS_FALLBACK

            offered[replacement] = true
            ev.items[index] = itemGeneration.maybeMarkSeen(replacement)
        end
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

local function generateUnweightedItemPool(requiredComponents, seed)
    local itemTypes = {}

    for _, entity in ecs.prototypesWithComponents(requiredComponents) do
        itemTypes[#itemTypes + 1] = entity
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

local function ownedVaultItem(key)
    local best

    for _, proto in ecs.prototypesWithComponents({ "itemPoolVault" }) do
        if proto.itemPoolVault.key == key and isAvailableItem(proto.name)
            and (not best or proto.itemPoolVault.priority < best.itemPoolVault.priority) then
            best = proto
        end
    end

    return best and best.name
end

event.levelLoad.add("apReplaceUnownedPlacedItems", { order = "initialItems", sequence = 1 }, function()
    if not apUtils.isAPContext() then return end

    local stale = {}

    for entity in ecs.entitiesWithComponents({ "itemPoolVault", "item", "position" }) do
        if entity.item.holder == 0 and not isAvailableItem(entity.name) then
            stale[#stale + 1] = entity
        end
    end

    for _, entity in ipairs(stale) do
        local x, y = entity.position.x, entity.position.y
        local replacement = ownedVaultItem(entity.itemPoolVault.key)
            or itemGeneration.choice({
                chanceType = "chest",
                player = itemGeneration.randomPlayer(currentLevel.getNumber()),
            })

        object.delete(entity)

        if replacement then
            object.spawn(replacement, x, y)
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
event.shrine.override("uncertainty", function(func, ev)
    if not apUtils.isAPContext() then
        return func(ev)
    end

    local candidates = {}
    -- "weapon", not "weaponCommon": the latter is not a component.
    for _, entity in ecs.prototypesWithComponents({ "itemPoolUncertainty", "weapon" }) do
        local shape = baseWeaponName(entity)
        local revealed = entity.variant and entity.variant.base

        if shape and revealed and progression.getItems(shape)
            and not progression.getBannedItems(revealed)
        then
            candidates[#candidates + 1] = entity.name
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

    local chosen = rng.choice(candidates, ev.interactor)
    local item   = object.spawn(chosen, ev.interactor.position.x, ev.interactor.position.y)
    itemPickup.tryCollect(item, ev.interactor, true)
end)
