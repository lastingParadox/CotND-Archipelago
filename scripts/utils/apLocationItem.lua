local ecs = require "system.game.Entities"
local itemPickup = require "necro.game.item.ItemPickup"
local object = require "necro.game.object.Object"

local apClient = require("AP.scripts.client.client")
local apItems = require("AP.scripts.utils.apItems")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local progression = require("AP.scripts.client.progression")

local apLocationItem = {}

-- Spawns the item AP placed at `located`, tagged so collecting it sends the check.
-- `located` is a scout entry: { Item, ItemName, PlayerName, LocationCode, Classification }.
function apLocationItem.spawn(located, locationName, x, y)
    if not (located and located.Item and located.Item ~= "") then return nil end

    local itemData = apItems.shopItemToObjectData(located)
    if not (itemData and type(itemData.name) == "string" and itemData.name ~= "") then
        apLog("Failed to map located item for " .. tostring(locationName), "warning")
        return nil
    end

    local args = itemData.args or {}
    args.AP_locationItem = {
        locationName = locationName,
        locationCode = tostring(located.LocationCode or ""),
    }

    return object.spawn(itemData.name, x, y, args)
end

-- Carriers whose effect lands the moment they're picked up, so the AP grant that
-- follows must not apply it a second time.
local function appliesOnPickup(itemName)
    local proto = itemName and ecs.getEntityPrototype(itemName)
    if not proto then return false end

    return (proto.itemCurrency or proto.AP_currency or proto.AP_shopStock) ~= nil
end

local function cacheCurrencyItem(located, itemName)
    if appliesOnPickup(itemName) then
        progression.markLocationConsumed(located.LocationCode)
    end
end

-- Sends the check for a collected located item and marks it locally so the slot
-- stops offering it before Python's reply arrives.
function apLocationItem.consume(located, locationName, itemName)
    if not (located and locationName) then return false end

    cacheCurrencyItem(located, itemName)
    progression.sendLocationChecks(locationName)
    located.Checked = true

    return true
end

event.objectTryCollectItem.add("apCollectLocationItem", { order = "priceTag", sequence = 1 },
    function(ev)
        if not (apClient.isSessionConnected() and ev.result == itemPickup.Result.SUCCESS) then return end
        if not (ev.item.AP_locationItem and ev.item.AP_locationItem.locationName ~= "") then return end

        local tag = ev.item.AP_locationItem
        local located = progression.getChestLocationByCode(tag.locationCode)
        if not located then return end

        if not apLocationItem.consume(located, tag.locationName, ev.item.name) then return end

        -- Real items stay in the player's hands; the grant that comes back is
        -- suppressed for them so they don't end up with two.
        if apItems.isPhysicalItem(located.Item) then
            apStorage.saveData.chestConsumedLocations[tostring(tag.locationCode)] =
                ev.entity and ev.entity.id or true
        else
            object.delete(ev.item)
        end
    end)

return apLocationItem
