local apConnection = require("AP.scripts.ap_handlers.APConnection")
local apUtils = require("AP.scripts.ap_handlers.APUtils")
local apItems = require("AP.scripts.ap_handlers.APItems")
local ecs = require "system.game.Entities"
local object = require("necro.game.object.Object")
local itemPickup = require "necro.game.item.ItemPickup"
local gameState = require("necro.client.GameState")
local flyaway = require "necro.game.system.Flyaway"
local sound = require "necro.audio.Sound"

local apShops = {}
local shopItemByPosition = {}

local shopOffsets = {}
local shopObjects = {}

local function getFirstUncheckedSlotInSection(section)
    if not section or not section.Slots then return nil, nil end

    for i, slot in ipairs(section.Slots) do
        if slot.Checked == false then
            return slot, i
        end
    end

    return nil, nil -- no unchecked slot
end

function apShops.populateLobbyShops(hephaestus, dungeonMaster, merlin)
    local shopLocations = apConnection.saveData.shopLocations or {}
    if not shopLocations or next(shopLocations) == nil then
        return
    end

    shopOffsets = {
        ["Dungeon Master"] = { offsetX = dungeonMaster.x, offsetY = dungeonMaster.y },
        ["Hephaestus"] = { offsetX = hephaestus.x, offsetY = hephaestus.y },
        ["Merlin"] = { offsetX = merlin.x, offsetY = merlin.y },
    }

    local shopPositionByIndex = { "Left", "Center", "Right" }

    local items = {
        ["Hephaestus"] = {
            shopLocations["Hephaestus"] and getFirstUncheckedSlotInSection(shopLocations["Hephaestus"]["Left"]) or nil,
            shopLocations["Hephaestus"] and getFirstUncheckedSlotInSection(shopLocations["Hephaestus"]["Center"]) or nil,
            shopLocations["Hephaestus"] and getFirstUncheckedSlotInSection(shopLocations["Hephaestus"]["Right"]) or nil
        },
        ["Dungeon Master"] = {
            shopLocations["Dungeon Master"] and getFirstUncheckedSlotInSection(shopLocations["Dungeon Master"]["Left"]) or
            nil,
            shopLocations["Dungeon Master"] and getFirstUncheckedSlotInSection(shopLocations["Dungeon Master"]["Center"]) or
            nil,
            shopLocations["Dungeon Master"] and getFirstUncheckedSlotInSection(shopLocations["Dungeon Master"]["Right"]) or
            nil
        },
        ["Merlin"] = {
            shopLocations["Merlin"] and getFirstUncheckedSlotInSection(shopLocations["Merlin"]["Left"]) or nil,
            shopLocations["Merlin"] and getFirstUncheckedSlotInSection(shopLocations["Merlin"]["Center"]) or nil,
            shopLocations["Merlin"] and getFirstUncheckedSlotInSection(shopLocations["Merlin"]["Right"]) or nil
        },
    }

    for shopName, itemList in pairs(items) do
        local offset = shopOffsets[shopName]
        if offset then
            for i = 1, #itemList do
                local shopItem = itemList[i]
                if shopItem == nil then goto continue end

                local itemData = apUtils.itemNameToObjectData(shopItem)
                local spawnX = offset.offsetX + i - 1
                local spawnY = offset.offsetY

                local item = object.spawn(itemData.name, spawnX, spawnY, itemData.args
                )

                table.insert(shopObjects, item)

                local price = 0
                local classification = apConnection.saveData.pricing and apConnection.saveData.pricing.type or
                    apUtils.PriceRandomizationType.VANILLA

                if classification == apUtils.PriceRandomizationType.VANILLA or apUtils.PriceRandomizationType.VANILLA_RAND then
                    price = item.itemPrice and item.itemPrice.diamonds
                end
                if price == nil or price == 0 then
                    price = apItems.getPriceForItem(apConnection.saveData.pricing,
                        shopItem["LocationCode"], shopItem["Classification"] or 0, apConnection.saveData.seed) or 1
                end

                item.sale.priceTag = object.spawn("PriceTagLobbyUnlock", spawnX, spawnY, {
                    priceTagCostCurrency = { cost = price },
                })

                local shopItemData = {
                    itemCode = shopItem["Item"],
                    locationCode = shopItem["LocationCode"],
                    position = { item.position.x, item.position.y },
                    shop = shopName,
                    shopPosition = shopPositionByIndex[i] or "unknown"
                }

                local posKey = item.position.x .. ":" .. item.position.y
                shopItemByPosition[posKey] = shopItemData

                ::continue::
            end
        else
            print("No offset defined for shop: " .. shopName)
        end
    end
end

function apShops.clearShops()
    for _, item in pairs(shopItemByPosition) do
        local posKey = (item.position.x or 0) .. ":" .. (item.position.y or 0)
        shopItemByPosition[posKey] = nil
    end

    for _, shopObject in pairs(shopObjects) do
        if shopObject then object.delete(shopObject) end
    end

    shopOffsets = {}
end

event.objectTryCollectItem.add("purchaseAPLobbyItem", { order = "priceTag", sequence = 1 }, function(ev)
    if not (gameState.isInLobby() and apUtils.isInLobby(ev.entity)) then return end
    if not ev.item.sale or ev.item.sale.priceTag == 0 or ev.result ~= itemPickup.Result.SUCCESS then return end

    local itemPos = ev.item.position
    local key = itemPos.x .. ":" .. itemPos.y
    local shopItem = shopItemByPosition[key]

    if shopItem then
        local shopLocations = apConnection.saveData.shopLocations[shopItem.shop]
        local item, index = getFirstUncheckedSlotInSection(shopLocations[shopItem.shopPosition])
        if apConnection.outputData["Location"] == nil then
            apConnection.outputData["Location"] = {}
        end

        table.insert(apConnection.outputData["Location"],
            shopItem.shop .. " - " .. shopItem.shopPosition .. " Shop Item " .. tostring(index))
        item.Checked = true

        apConnection.addCheckToCollectedCache(shopItem.locationCode)

        apConnection.changeDiamonds(-(ecs.getEntityByID(ev.item.sale.priceTag).priceTagCostCurrency.cost or 1))

        if not string.find(ev.item.name, "ResourceDiamond") then object.delete(ev.item) end
    end
end)

event.objectTryCollectItem.add("APPurchaseDisconnected", { order = "priceTag" }, function(ev)
    if not (gameState.isInLobby() and apUtils.isInLobby(ev.entity)) then return end

    if ev.result == itemPickup.Result.SUCCESS and not apConnection.connected then
        ev.result = itemPickup.Result.FAILURE

        sound.playFromEntity("error", ev.entity)

        flyaway.create({
            text = L("AP Disconnected!", "ap.item.disconnected"),
            entity = ev.entity,
        })
    end
end)

apShops.shopItemByPosition = shopItemByPosition

return apShops
