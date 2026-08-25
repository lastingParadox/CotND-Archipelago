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

-- Spawns the item AP placed at `located`, tagged so collecting it sends the check.
-- `located` is a scout entry: { Item, ItemName, PlayerName, LocationCode, Classification }.
function apLocationItem.spawn(located, locationName, x, y)
    if not (located and located.Item and located.Item ~= "") then return nil end

    local itemData = apItems.shopItemToObjectData(located)
    if not (itemData and type(itemData.name) == "string" and itemData.name ~= "") then
        apLog("Failed to map located item for " .. tostring(locationName), "warning")
        return nil
    end

    -- Added to, not replaced: shopItemToObjectData already put the owning player and the
    -- classification on this component.
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

-- For a carrier that acts the moment it is collected, so the grant coming back from AP
-- knows the effect already landed.
function apLocationItem.markApplied(item)
    local tag = item and item.AP_locationItem
    if tag then progression.markLocationConsumed(tag.locationCode) end
end

-- Sends the check for a collected located item and marks it locally so the slot
-- stops offering it before Python's reply arrives.
function apLocationItem.consume(located, locationName)
    if not (located and locationName) then return false end

    -- Taken in person, so the grant coming back must not announce it again.
    progression.markLocationCollected(located.LocationCode)
    progression.sendLocationChecks(locationName)
    located.Checked = true

    return true
end

-- An item this character is banned from stops the pickup at "itemBans", which runs before
-- "priceTag" and leaves the result at NONE.
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

        -- A real item taken in person stays in the player's hands, and a banned one is
        -- destroyed: the location is checked either way.
        if kept or not collected then
            apStorage.saveData.chestConsumedLocations[code] = ev.entity and ev.entity.id or true
        end

        if not collected then
            itemPickup.playPickupEffects(ev.item, ev.entity)
        end

        if not kept then object.delete(ev.item) end
    end)

return apLocationItem
