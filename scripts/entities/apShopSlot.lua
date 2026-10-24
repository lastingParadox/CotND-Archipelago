local collision = require("necro.game.tile.Collision")
local customEntities = require("necro.game.data.CustomEntities")
local ecs = require "system.game.Entities"
local itemPickup = require "necro.game.item.ItemPickup"
local object = require("necro.game.object.Object")
local player = require "necro.game.character.Player"
local rng = require "necro.game.system.RNG"
local tile = require "necro.game.tile.Tile"
local tileTypes = require "necro.game.tile.TileTypes"
local turn = require "necro.cycles.Turn"
local utils = require "system.utils.Utilities"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apClient = require("AP.scripts.client.client")
local apInventory = require("AP.scripts.utils.apInventory")
local apItems = require("AP.scripts.utils.apItems")
local apLocationItem = require("AP.scripts.utils.apLocationItem")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local progression = require("AP.scripts.client.progression")
local types = require("AP.scripts.utils.types")

local APShopSlot = {}

local janitorSlots = {}
local dealerSlots = {}
janitorSlots, dealerSlots = script.persist(function()
    return janitorSlots, dealerSlots
end)

customEntities.register({
    name = "AP_ShopSlot",
    position = {},
    AP_shopSlot = {
        npc = "Hephaestus",
        position = "Left"
    }
})

local TILE_HEIGHT = 24
local SOLID_WARE = collision.Type.mask(collision.Type.PLAYER, collision.Type.ITEM)

local CODEX_LOCATIONS = {
    DragonLore = "Dragon Lore",
    TrapLore   = "Trap Lore",
    BombLore   = "Bomb Lore",
    Murder     = "How to Get Away with Murder",
}

local UNSELLABLE = { "consumableHeal", "playableCharacter", "greetable", "itemLobbyProgressionUnlock", "AP_material" }

local ALT_NPCS = {
    Janitor = {
        seed = 10,
        priceTag = "AP_PriceTagLobbyRemoveFromPool",
        slots = function() return janitorSlots end,
        excluded = function() return progression.getBannedItems() or {} end,
        price = function() return 1 end,
        purchase = function(ware)
            progression.addBannedItem(ware.name)
            object.delete(ware)
        end,
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
        purchase = function(ware)
            progression.addNextRunItem(ware.name)
            for _, playerEntity in ipairs(player.getPlayerEntities()) do
                apInventory.equipNextRunItems(playerEntity, progression)
            end
        end,
    },
}

-- Rows

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

    return nil, nil
end

local function slotForLocationCode(section, locationCode)
    if not (section and section.Slots and locationCode and locationCode ~= "") then return nil, nil end

    for key, slot in pairs(section.Slots) do
        if tostring(slot.LocationCode) == locationCode then
            return slot, tonumber(key)
        end
    end

    return nil, nil
end

local function positionSection(slotEntity)
    local npcSection = progression.getShopLocations(slotEntity.AP_shopSlot.npc)
    return npcSection and npcSection[slotEntity.AP_shopSlot.position]
end

-- Spawning

local function alignShopItemSprite(item)
    if not (item and item.sprite and item.positionalSprite) then return end

    local overhang = item.sprite.height + item.positionalSprite.offsetY - TILE_HEIGHT
    if overhang > 0 then
        item.positionalSprite.offsetY = item.positionalSprite.offsetY - overhang
    end
end

-- Puts a ware on the slot, tagged back to it.
local function spawnWare(slotEntity, name, args, solid)
    args = args or {}
    args.AP_locationItem = args.AP_locationItem or {}
    args.AP_locationItem.slot = slotEntity

    local item = object.spawn(name, slotEntity.position.x, slotEntity.position.y, args)
    slotEntity.AP_shopSlot.item = item
    alignShopItemSprite(item)

    if solid then collision.setMask(item, SOLID_WARE) end

    return item
end

local function tagPrice(item, slotEntity, priceTag, cost)
    item.sale.priceTag = object.spawn(priceTag, slotEntity.position.x, slotEntity.position.y,
        { priceTagCostCurrency = { cost = cost } })
end

-- Object data for a location's ware, tagged with its code, or nil when it cannot be mapped.
local function locationWareData(located, label)
    local itemData = apItems.shopItemToObjectData(located)
    if not (itemData and type(itemData.name) == "string" and itemData.name ~= "") then
        apLog("Failed to map shop item for " .. label .. ", location " .. tostring(located.LocationCode), "warning")
        return nil
    end

    itemData.args = itemData.args or {}
    itemData.args.AP_locationItem = itemData.args.AP_locationItem or {}
    itemData.args.AP_locationItem.locationCode = tostring(located.LocationCode or "")

    return itemData
end

local function locationPrice(item, shopItem, itemData)
    local pricing = progression.getPricing()
    local classification = pricing and pricing.type or types.PriceRandomization.VANILLA
    local price = 0

    if classification == types.PriceRandomization.VANILLA
        or classification == types.PriceRandomization.VANILLA_RAND then
        price = item.itemPrice and item.itemPrice.diamonds
    end

    if not price or price == 0 then
        price = apItems.getPriceForItem(pricing, shopItem.LocationCode, shopItem.Classification or 0,
            progression.getSeedName()) or itemData.price or 1
    end

    return price
end

local function spawnShopWare(slotEntity)
    local shopItem, index = getFirstUncheckedSlotInSection(positionSection(slotEntity))
    if not shopItem or progression.getShopStock() < index - 1 then return end

    local itemData = locationWareData(shopItem, slotEntity.AP_shopSlot.npc)
    if not itemData then return end

    apLog("Spawning shop item: " .. itemData.name .. " for NPC: " ..
        slotEntity.AP_shopSlot.npc .. " at position: " .. slotEntity.AP_shopSlot.position)

    local item = spawnWare(slotEntity, itemData.name, itemData.args, true)
    tagPrice(item, slotEntity, "AP_PriceTagLobbyUnlock", locationPrice(item, shopItem, itemData))
end

local function spawnCodexWare(slotEntity)
    local codexLocation = progression.getCodexLocations(slotEntity.AP_shopSlot.type)
    if not (codexLocation and codexLocation.Item and not codexLocation.Checked) then return end

    local itemData = locationWareData(codexLocation, tostring(slotEntity.AP_shopSlot.type))
    if not itemData then return end

    spawnWare(slotEntity, itemData.name, itemData.args, true)
end

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

-- Variants combining a base shape and a material the player already owns.
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

local function spawnAltWare(slotEntity, npcName)
    local npc = ALT_NPCS[npcName]
    local itemsList = progression.getItems()
    if not (itemsList and next(itemsList)) then return end

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

    local item = spawnWare(slotEntity, chosen)
    tagPrice(item, slotEntity, npc.priceTag, npc.price(item))
end

local function spawnVictoryWare(slotEntity)
    if (progression.getCharacterLocations("ExpensivePurchase") or {})["Completed"] then return end

    local item = spawnWare(slotEntity, "AP_VictoryItem", nil, true)
    tagPrice(item, slotEntity, "AP_PriceTagVictory", progression.getExpensivePurchasePrice())
end

-- Buying: each returns true once the ware is paid for.

local function charge(ware)
    local tag = ware.sale and ecs.getEntityByID(ware.sale.priceTag)
    if tag then
        progression.changeDiamonds(-(tag.priceTagCostCurrency.cost or 1))
    end
end

local function buyLocationWare(ware, located, locationName)
    if not located or located.Checked then return false end
    if not apLocationItem.consume(located, locationName) then return false end

    charge(ware)
    object.delete(ware)

    return true
end

local function buyShopWare(ware, slot)
    local shopItem, index = slotForLocationCode(positionSection(slot), ware.AP_locationItem.locationCode)

    return buyLocationWare(ware, shopItem,
        slot.AP_shopSlot.npc .. " - " .. slot.AP_shopSlot.position .. " Shop Item " .. tostring(index))
end

local function buyCodexWare(ware, slot)
    local codexKey = slot.AP_shopSlot.type

    return buyLocationWare(ware, progression.getCodexLocations(codexKey), CODEX_LOCATIONS[codexKey])
end

local function buyAltWare(ware, npcName)
    local npc = ALT_NPCS[npcName]

    charge(ware)
    npc.purchase(ware)
    utils.arrayRemove(npc.slots(), ware.name)

    return true
end

local function buyVictoryWare(ware)
    charge(ware)
    apStorage.saveData.characterLocations["ExpensivePurchase"] = { Completed = true }
    progression.calculateGoalCompletion(true)
    object.delete(ware)

    return true
end

local LOCATION_SHOP = { spawn = spawnShopWare, buy = buyShopWare, notifyOutOfStock = true }

local NPCHandlers = {
    Hephaestus         = LOCATION_SHOP,
    ["Dungeon Master"] = LOCATION_SHOP,
    Merlin             = LOCATION_SHOP,
    Codex = {
        spawn = spawnCodexWare,
        buy = buyCodexWare,
        noRefresh = true,
    },
    Janitor = {
        spawn = function(slot) return spawnAltWare(slot, "Janitor") end,
        buy = function(ware) return buyAltWare(ware, "Janitor") end,
        noRefresh = true,
    },
    Diamonddealer = {
        spawn = function(slot) return spawnAltWare(slot, "Diamonddealer") end,
        buy = function(ware) return buyAltWare(ware, "Diamonddealer") end,
        noRefresh = true,
    },
    VictoryItem = {
        spawn = spawnVictoryWare,
        buy = buyVictoryWare,
        noRefresh = true,
    },
}

local function spawnShopItem(slotEntity)
    if not apClient.isSessionConnected() then return end

    local npc = slotEntity.AP_shopSlot.npc
    local handler = NPCHandlers[npc]
    if not handler then
        apLog("No shop handler for NPC " .. tostring(npc), "warning")
        return
    end

    handler.spawn(slotEntity)

    if handler.notifyOutOfStock then
        local x, y = slotEntity.position.x, slotEntity.position.y
        local tileName = tileTypes.getTileInfo(tile.get(x, y)).name

        if not ecs.entityExists(slotEntity.AP_shopSlot.item) then
            tile.setType(x, y, "OutOfStockFloor")
        elseif tileName == "OutOfStockFloor" then
            tile.setType(x, y, "Floor")
        end
    end

    visualUpdate.trigger()
end

function APShopSlot.refreshShopSlots(npcFilter)
    for slot in ecs.entitiesWithComponents({ "AP_shopSlot" }) do
        local npc = slot.AP_shopSlot.npc

        if not npcFilter or npc == npcFilter then
            local item = ecs.getEntityByID(slot.AP_shopSlot.item)
            if item then
                object.delete(item)
                if ALT_NPCS[npc] then utils.arrayRemove(ALT_NPCS[npc].slots(), item.name) end
                visualUpdate.trigger()
            end

            spawnShopItem(slot)
        end
    end
end

event.tick.add("apRefreshShopSlots", { order = "lobby", sequence = 3 }, function()
    for slot in ecs.entitiesWithComponents({ "AP_shopSlot" }) do
        local handler = NPCHandlers[slot.AP_shopSlot.npc]

        if handler and not handler.noRefresh
            and not ecs.entityExists(slot.AP_shopSlot.item)
            and not collision.check(slot.position.x, slot.position.y, collision.Type.PLAYER) then
            spawnShopItem(slot)
        end
    end
end)

event.levelLoad.add("apClearAltSlots", { order = "lobbyLevel" }, function()
    janitorSlots, dealerSlots = {}, {}
end)

event.objectSpawn.add("apSpawnShopItem", { filter = "AP_shopSlot", order = "items" }, function(ev)
    spawnShopItem(ev.entity)
end)

event.apConnect.add("apPopulateShopItems", { order = "connected", sequence = 1 }, function(ev)
    if ev.status == "Connected" then APShopSlot.refreshShopSlots() end
end)

event.objectUpdateTargetability.add("apShopItemNoTargeting", { order = "apply", filter = "AP_locationItem", sequence = -1 },
    function(ev)
        if ev.entity.AP_locationItem.slot ~= 0 then
            ev.targetable = false

            if (ev.entity.controllable.playerID ~= 0) then
                player.setControlledEntity(0, ev.entity.id)
            end
        end
    end)

event.objectTryCollectItem.add("apPurchaseShopItem", { order = "priceTag", sequence = 1 }, function(ev)
    if not (apClient.isSessionConnected() and ev.result == itemPickup.Result.SUCCESS) then return end

    local tag = ev.item.AP_locationItem
    local slot = tag and tag.slot ~= 0 and ecs.getEntityByID(tag.slot)
    local handler = slot and slot.AP_shopSlot and NPCHandlers[slot.AP_shopSlot.npc]
    if not handler then return end

    if handler.buy(ev.item, slot) then
        -- Untagged once bought, so a repeated pickup of the same ware cannot buy it again.
        tag.slot = 0
    end
end)

return APShopSlot
