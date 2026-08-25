local collision = require("necro.game.tile.Collision")
local customEntities = require("necro.game.data.CustomEntities")
local ecs = require "system.game.Entities"
local itemPickup = require "necro.game.item.ItemPickup"
local object = require("necro.game.object.Object")
local rng = require "necro.game.system.RNG"
local tile = require "necro.game.tile.Tile"
local tileTypes = require "necro.game.tile.TileTypes"
local turn = require "necro.cycles.Turn"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apClient = require("AP.scripts.client.client")
local apInventory = require("AP.scripts.utils.apInventory")
local apItems = require("AP.scripts.utils.apItems")
local apLocationItem = require("AP.scripts.utils.apLocationItem")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local player = require "necro.game.character.Player"
local progression = require("AP.scripts.client.progression")
local types = require("AP.scripts.utils.types")

local APShopSlot = {}

local janitorSlots = {}
local dealerSlots = {}
local itemCandidates = nil
local lastItemsKey = nil
local lastBanKey = nil
janitorSlots, dealerSlots, itemCandidates, lastItemsKey, lastBanKey = script.persist(function()
    return janitorSlots, dealerSlots, itemCandidates, lastItemsKey, lastBanKey
end)

customEntities.register({
    name = "AP_ShopSlot",
    position = {},
    AP_shopSlot = {
        npc = "Hephaestus",
        position = "Left"
    }
})

local function removeSlot(item, npc)
    local slotList = npc == "Diamonddealer" and dealerSlots or janitorSlots
    local indexToRemove = nil
    for i, value in ipairs(slotList) do
        if value == item then
            indexToRemove = i
            break
        end
    end

    if indexToRemove ~= nil then table.remove(slotList, indexToRemove) end
end

local function getFirstUncheckedSlotInSection(section)
    if not section or not section.Slots then return nil, nil end

    local keys = {}
    for k in pairs(section.Slots) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)

    for _, k in ipairs(keys) do
        local slot = section.Slots[k]
        if slot.Checked == false and slot.Item and slot.Item ~= "" then
            return slot, tonumber(k)
        end
    end

    return nil, nil -- no unchecked slot
end

local TILE_HEIGHT = 24

local function alignShopItemSprite(item)
    if not (item and item.sprite and item.positionalSprite) then return end

    local overhang = item.sprite.height + item.positionalSprite.offsetY - TILE_HEIGHT
    if overhang > 0 then
        item.positionalSprite.offsetY = item.positionalSprite.offsetY - overhang
    end
end

local function spawnAPLobbyShopItemForSlot(slotEntity)
    local npcSection = progression.getShopLocations(slotEntity.AP_shopSlot.npc)
    if not npcSection then return end

    local positionSection = npcSection[slotEntity.AP_shopSlot.position]
    if not positionSection then return end

    local shopItem, index = getFirstUncheckedSlotInSection(positionSection)
    if not shopItem then return end

    -- Shop stock items are needed for normal shop slot item spawn
    if progression.getShopStock() < index - 1 then return end

    local itemData = apItems.shopItemToObjectData(shopItem)
    if not itemData then
        apLog("Failed to map shop item data for NPC " .. slotEntity.AP_shopSlot.npc, "warning")
        return
    end

    itemData.args = itemData.args or {}
    itemData.args.AP_locationItem = itemData.args.AP_locationItem or {}
    itemData.args.AP_locationItem.slot = slotEntity
    itemData.args.AP_locationItem.locationCode = tostring(shopItem.LocationCode or "")

    if type(itemData.name) ~= "string" or itemData.name == "" then
        apLog("Invalid shop item type for NPC " .. slotEntity.AP_shopSlot.npc ..
            ", location " .. tostring(shopItem.LocationCode), "warning")
        return
    end

    apLog("Spawning shop item: " .. itemData.name .. " for NPC: " ..
        slotEntity.AP_shopSlot.npc .. " at position: " .. slotEntity.AP_shopSlot.position)

    local item = object.spawn(itemData.name,
        slotEntity.position.x, slotEntity.position.y,
        itemData.args)
    slotEntity.AP_shopSlot.item = item
    alignShopItemSprite(item)

    collision.setMask(item, collision.Type.mask(
        collision.Type.PLAYER,
        collision.Type.ITEM
    ))

    local pricing = progression.getPricing()
    local classification = pricing and pricing.type or types.PriceRandomization.VANILLA
    local price = 0

    if classification == types.PriceRandomization.VANILLA
        or classification == types.PriceRandomization.VANILLA_RAND then
        price = item.itemPrice and item.itemPrice.diamonds
    end

    if not price or price == 0 then
        local seedName = progression.getSeedName()
        price = apItems.getPriceForItem(
            pricing,
            shopItem.LocationCode,
            shopItem.Classification or 0,
            seedName
        ) or itemData.price or 1
    end

    item.sale.priceTag = object.spawn("AP_PriceTagLobbyUnlock",
        slotEntity.position.x, slotEntity.position.y,
        { priceTagCostCurrency = { cost = price } }
    )
end

local UNSELLABLE = { "consumableHeal", "playableCharacter", "greetable", "itemLobbyProgressionUnlock", "AP_material" }

local ALT_NPCS = {
    Janitor = {
        seed = 10,
        priceTag = "AP_PriceTagLobbyRemoveFromPool",
        slots = function() return janitorSlots end,
        excluded = function() return progression.getBannedItems() or {} end,
        price = function() return 1 end,
    },
    Diamonddealer = {
        seed = 20,
        priceTag = "AP_PriceTagLobbyGrantOnce",
        composites = true,
        -- A material is a run-start item nobody can equip on its own.
        unsellable = { "AP_material" },
        slots = function() return dealerSlots end,
        excluded = function() return progression.getNextRunItems() or {} end,
        price = function(item)
            local diamonds = (item.itemDiamondDealable and item.itemDiamondDealable.diamonds)
                or (item.itemPrice and item.itemPrice.diamonds) or 1
            return diamonds ~= 0 and diamonds or 5
        end,
    },
}

local function sellable(proto, npc)
    if not (proto and proto.item) then return false end

    for _, component in ipairs(UNSELLABLE) do
        if proto[component] then return false end
    end

    for _, component in ipairs(npc.unsellable or {}) do
        if proto[component] then return false end
    end

    return true
end

-- Variants the player owns the makings of but not the weapon itself: a base shape they
-- have, plus a material they have. Built from the base list, so composites of composites
-- never arise.
local function compositeWeapons(itemsList, bases, excluded)
    local composites = {}

    for item in pairs(itemsList) do
        local material = item:match("^AP_Material(.+)$")

        if material then
            for _, base in ipairs(bases) do
                local shape = base:match("^Weapon(.+)$")
                local composite = shape and ("Weapon" .. material .. shape)
                local proto = composite and not excluded[composite] and ecs.getEntityPrototype(composite)

                if proto and proto.item then composites[#composites + 1] = composite end
            end
        end
    end

    return composites
end

local function itemSlotName(itemName)
    local proto = ecs.getEntityPrototype(itemName)
    return proto and proto.itemSlot and proto.itemSlot.name
end

-- Spread the NPC's slots across categories
local function pickAltItem(candidates, npc)
    local taken, usedSlots = {}, {}

    for _, spawned in ipairs(npc.slots()) do
        taken[spawned] = true
        local slotName = itemSlotName(spawned)
        if slotName then usedSlots[slotName] = true end
    end

    local channel = rng.makeChannel(rng.getDungeonSeed() + turn.getCurrentTurnID() + npc.seed)
    local fallback

    for _, item in ipairs(rng.shuffle(candidates, channel)) do
        if not taken[item] then
            fallback = fallback or item
            local slotName = itemSlotName(item)
            if not (slotName and usedSlots[slotName]) then return item end
        end
    end

    return fallback
end

local function spawnAPLobbyAltItemForSlot(slotEntity, npcName)
    local npc = ALT_NPCS[npcName]
    local itemsList = progression.getItems()
    if not (npc and itemsList and next(itemsList)) then return end

    local excluded = npc.excluded()
    local candidates = {}

    for item in pairs(itemsList) do
        if not excluded[item] and sellable(ecs.getEntityPrototype(item), npc) then
            candidates[#candidates + 1] = item
        end
    end

    if npc.composites then
        for _, composite in ipairs(compositeWeapons(itemsList, candidates, excluded)) do
            candidates[#candidates + 1] = composite
        end
    end

    table.sort(candidates)

    local chosen = pickAltItem(candidates, npc)
    if not chosen then return end

    table.insert(npc.slots(), chosen)

    local item = object.spawn(chosen, slotEntity.position.x, slotEntity.position.y,
        { AP_locationItem = { slot = slotEntity } })
    slotEntity.AP_shopSlot.item = item
    alignShopItemSprite(item)

    item.sale.priceTag = object.spawn(npc.priceTag,
        slotEntity.position.x, slotEntity.position.y,
        { priceTagCostCurrency = { cost = npc.price(item) } }
    )
end

local function spawnCodexItemForSlot(slotEntity)
    local codexLocation = progression.getCodexLocations(slotEntity.AP_shopSlot.type)
    if not (codexLocation and codexLocation.Item and not codexLocation.Checked) then return end

    local itemData = apItems.shopItemToObjectData(codexLocation)
    if not itemData then
        apLog("Failed to map codex item data for " .. tostring(slotEntity.AP_shopSlot.type), "warning")
        return
    end

    itemData.args = itemData.args or {}
    itemData.args.AP_locationItem = itemData.args.AP_locationItem or {}
    itemData.args.AP_locationItem.slot = slotEntity
    itemData.args.AP_locationItem.locationCode = tostring(codexLocation.LocationCode or "")

    if type(itemData.name) ~= "string" or itemData.name == "" then
        apLog("Invalid codex item type for " .. tostring(slotEntity.AP_shopSlot.type) ..
            ", location " .. tostring(codexLocation.LocationCode), "warning")
        return
    end

    local item = object.spawn(itemData.name,
        slotEntity.position.x, slotEntity.position.y,
        itemData.args)
    slotEntity.AP_shopSlot.item = item
    alignShopItemSprite(item)

    collision.setMask(item, collision.Type.mask(
        collision.Type.PLAYER,
        collision.Type.ITEM
    ))
end

local NPCHandlers = {
    Janitor = {
        spawn = function(slot) return spawnAPLobbyAltItemForSlot(slot, "Janitor") end,
        notifyOutOfStock = false,
        noRefresh = true
    },
    Diamonddealer = {
        spawn = function(slot) return spawnAPLobbyAltItemForSlot(slot, "Diamonddealer") end,
        notifyOutOfStock = false,
        noRefresh = true
    },
    Codex = {
        spawn = function(slot) return spawnCodexItemForSlot(slot) end,
        notifyOutOfStock = false,
        noRefresh = true
    },
    Hephaestus = {
        spawn = spawnAPLobbyShopItemForSlot,
        notifyOutOfStock = true
    },
    ["Dungeon Master"] = {
        spawn = spawnAPLobbyShopItemForSlot,
        notifyOutOfStock = true
    },
    Merlin = {
        spawn = spawnAPLobbyShopItemForSlot,
        notifyOutOfStock = true
    },
    VictoryItem = {
        spawn = function(slot)
            if (progression.getCharacterLocations("ExpensivePurchase") or {})["Completed"] then return end

            local item = object.spawn("AP_VictoryItem", slot.position.x, slot.position.y, {
                AP_locationItem = { slot = slot }
            })
            slot.AP_shopSlot.item = item
            alignShopItemSprite(item)

            collision.setMask(item, collision.Type.mask(
                collision.Type.PLAYER,
                collision.Type.ITEM
            ))

            item.sale.priceTag = object.spawn("AP_PriceTagVictory",
                slot.position.x, slot.position.y,
                { priceTagCostCurrency = { cost = progression.getExpensivePurchasePrice() } }
            )
        end,
        notifyOutOfStock = false,
        noRefresh = true,
    },
}

local function spawnShopItem(slotEntity)
    if not apClient.isSessionConnected() then
        return
    end
    local npc = slotEntity.AP_shopSlot.npc
    local handler = NPCHandlers[npc] or NPCHandlers.default

    handler.spawn(slotEntity)


    -- Out-of-stock handling (shared)
    if handler.notifyOutOfStock then
        local tileName = tileTypes.getTileInfo(tile.get(slotEntity.position.x, slotEntity.position.y)).name
        if not ecs.entityExists(slotEntity.AP_shopSlot.item) then
            tile.setType(slotEntity.position.x, slotEntity.position.y, "OutOfStockFloor")
        elseif tileName == "OutOfStockFloor" then
            tile.setType(slotEntity.position.x, slotEntity.position.y, "Floor")
        end
    end

    visualUpdate.trigger()
end

function APShopSlot.refreshShopSlots(npcFilter)
    for slot in ecs.entitiesWithComponents({ "AP_shopSlot" }) do
        if npcFilter and slot.AP_shopSlot.npc ~= npcFilter then goto continue end

        local item = ecs.getEntityByID(slot.AP_shopSlot.item)
        if item then
            object.delete(item)
            removeSlot(item.name, slot.AP_shopSlot.npc)
            visualUpdate.trigger()
        end

        spawnShopItem(slot)
        ::continue::
    end
end

event.tick.add("apRefreshShopSlots", { order = "lobby", sequence = 3 }, function()
    for slot in ecs.entitiesWithComponents({ "AP_shopSlot" }) do
        local npc = slot.AP_shopSlot.npc
        local handler = NPCHandlers[npc]
        if handler.noRefresh then goto continue end
        if handler and handler.refresh then
            handler.refresh(slot)
        elseif not ecs.entityExists(slot.AP_shopSlot.item) and
            not collision.check(slot.position.x, slot.position.y, collision.Type.PLAYER) then
            spawnShopItem(slot)
            if ecs.entityExists(slot.AP_shopSlot.item) then visualUpdate.trigger() end
        end
        ::continue::
    end
end)

-- Clear state on level load
event.levelLoad.add("apClearAltSlots", { order = "lobbyLevel" }, function()
    janitorSlots, dealerSlots = {}, {}
end)

-- Spawn on entity creation
event.objectSpawn.add("apSpawnShopItem", { filter = "AP_shopSlot", order = "items" }, function(ev)
    spawnShopItem(ev.entity)
end)

-- Populate shop items on connect
event.apConnect.add("apPopulateShopItems", { order = "connected", sequence = 1 }, function(ev)
    if ev.status == "Connected" then APShopSlot.refreshShopSlots() end
end)

local function codexKeyToLocationName(codexKey)
    if codexKey == "DragonLore" then
        return "Dragon Lore"
    elseif codexKey == "TrapLore" then
        return "Trap Lore"
    elseif codexKey == "BombLore" then
        return "Bomb Lore"
    elseif codexKey == "Murder" then
        return "How to Get Away with Murder"
    end
    return nil
end


event.objectUpdateTargetability.add("apShopItemNoTargeting", { order = "apply", filter = "AP_locationItem", sequence = -1 },
    function(ev)
        if ev.entity.AP_locationItem.slot ~= 0 then
            ev.targetable = false

            if (ev.entity.controllable.playerID ~= 0) then
                player.setControlledEntity(0, ev.entity.id)
            end
        end
    end)

-- Item pickup event
event.objectTryCollectItem.add("apPurchaseShopItem", { order = "priceTag", sequence = 1 }, function(ev)
    if not (apClient.isSessionConnected() and ev.result == itemPickup.Result.SUCCESS and ev.item.AP_locationItem and ev.item.AP_locationItem.slot ~= 0) then
        return
    end

    local slot = ecs.getEntityByID(ev.item.AP_locationItem.slot)
    local npc = slot.AP_shopSlot.npc
    if npc == "Janitor" or npc == "Diamonddealer" then
        progression.changeDiamonds(-(ecs.getEntityByID(ev.item.sale.priceTag).priceTagCostCurrency.cost or 1))

        if npc == "Janitor" then
            progression.addBannedItem(ev.item.name)
            object.delete(ev.item)
        elseif slot.AP_shopSlot.npc == "Diamonddealer" then
            progression.addNextRunItem(ev.item.name)
            for _, playerEntity in ipairs(player.getPlayerEntities()) do
                apInventory.equipNextRunItems(playerEntity, progression)
            end
        end

        removeSlot(ev.item.name, npc)
        return
    end

    if npc == "VictoryItem" then
        if ev.item.sale and ev.item.sale.priceTag ~= 0 then
            progression.changeDiamonds(-(ecs.getEntityByID(ev.item.sale.priceTag).priceTagCostCurrency.cost or 1))
        end
        apStorage.saveData.characterLocations["ExpensivePurchase"] = { Completed = true }
        progression.calculateGoalCompletion(true)
        object.delete(ev.item)
        return
    end

    local shopItem, locationName = nil, nil

    if npc == "Codex" then
        shopItem = progression.getCodexLocations(slot.AP_shopSlot.type)
        locationName = codexKeyToLocationName(slot.AP_shopSlot.type)
    else
        local npcSection = progression.getShopLocations(npc)
        if not npcSection then return end

        local positionSection = npcSection[slot.AP_shopSlot.position]
        if not positionSection then return end

        local index
        shopItem, index = getFirstUncheckedSlotInSection(positionSection)
        locationName = npc .. " - " .. slot.AP_shopSlot.position .. " Shop Item " .. tostring(index)
    end

    if not apLocationItem.consume(shopItem, locationName) then return end

    if ev.item.sale and ev.item.sale.priceTag ~= 0 then
        progression.changeDiamonds(-(ecs.getEntityByID(ev.item.sale.priceTag).priceTagCostCurrency.cost or 1))
    end

    object.delete(ev.item)
end)

return APShopSlot
