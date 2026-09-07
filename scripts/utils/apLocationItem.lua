local ecs = require "system.game.Entities"
local itemBan = require "necro.game.item.ItemBan"
local itemPickup = require "necro.game.item.ItemPickup"
local itemStorage = require "necro.game.item.ItemStorage"
local object = require "necro.game.object.Object"

local apClient = require("AP.scripts.client.client")
local apItems = require("AP.scripts.utils.apItems")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local progression = require("AP.scripts.client.progression")

local apLocationItem = {}

-- Spawns the scouted item at `located`, tagged so collecting it sends the check.
function apLocationItem.spawn(located, locationName, x, y)
    if not (located and located.Item and located.Item ~= "") then return nil end

    local itemData = apItems.shopItemToObjectData(located)
    if not (itemData and type(itemData.name) == "string" and itemData.name ~= "") then
        apLog("Failed to map located item for " .. tostring(locationName), "warning")
        return nil
    end

    -- Added to rather than replaced, since shopItemToObjectData already filled fields here.
    local args = itemData.args or {}
    args.AP_locationItem = args.AP_locationItem or {}
    args.AP_locationItem.locationName = locationName
    args.AP_locationItem.locationCode = tostring(located.LocationCode or "")

    return object.spawn(itemData.name, x, y, args)
end

-- Puts the located item inside the container, in place of whatever it was holding.
function apLocationItem.store(container, located, locationName)
    if not (container and container.storage and container.position) then return false end

    -- Only overwrites a slot holding a type name, never an already-spawned entity.
    local loot = container.storage.items[1]
    if loot ~= nil and type(loot) ~= "string" then return false end
    if loot and ecs.typeHasComponent(loot, "AP_noReplace") then return false end

    local item = apLocationItem.spawn(located, locationName, container.position.x, container.position.y)
    if not item then return false end

    if not itemStorage.replaceIndex(container, 1, item.id) then
        itemStorage.store(item.id, container)
    end

    return true
end

-- Marks a carrier that acted on collection, so the returning grant does not repeat it.
function apLocationItem.markApplied(item)
    local tag = item and item.AP_locationItem
    if tag then progression.markLocationConsumed(tag.locationCode) end
end

-- Sends the check and marks it locally, so the slot stops offering it before Python replies.
function apLocationItem.consume(located, locationName)
    if not (located and locationName) then return false end

    -- Taken in person, so the grant coming back must not announce it again.
    progression.markLocationCollected(located.LocationCode)
    progression.sendLocationChecks(locationName)
    located.Checked = true

    return true
end

-- A banned item stops the pickup at "itemBans", before "priceTag", leaving the result NONE.
local function refusedByBan(ev)
    return ev.result == itemPickup.Result.NONE
        and ev.entity
        and itemBan.isBanned(ev.entity, ev.item, itemBan.Flag.PICKUP)
end

event.objectTryCollectItem.add("apCollectLocationItem", { order = "priceTag", sequence = 1 },
    function(ev)
        if not apClient.isSessionConnected() then return end

        local collected = ev.result == itemPickup.Result.SUCCESS
        if not (collected or refusedByBan(ev)) then return end
        if not (ev.item.AP_locationItem and ev.item.AP_locationItem.locationName ~= "") then return end

        local tag = ev.item.AP_locationItem
        local located = progression.getChestLocationByCode(tag.locationCode)
        if not located then return end

        if not apLocationItem.consume(located, tag.locationName) then return end

        local code = tostring(tag.locationCode)
        local kept = collected and apItems.isPhysicalItem(located.Item)

        -- The location is checked whether the item is kept or destroyed.
        if kept or not collected then
            apStorage.saveData.chestConsumedLocations[code] = ev.entity and ev.entity.id or true
        end

        if not collected then
            itemPickup.playPickupEffects(ev.item, ev.entity)
        end

        if not kept then object.delete(ev.item) end
    end)

return apLocationItem
