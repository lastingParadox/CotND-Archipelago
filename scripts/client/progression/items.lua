local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")

local permItems = {
    Bomb = true,
    Bomb3 = true,
    BombInfinity = true,
    BombGrenade = true,
    BombGrenade3 = true,
    -- Barrel/Crates have a chance to spawn a Skeleton/Monkey
    EnemyPlaceholder = true,
}

local function magicFoodBase(itemName)
    local suffix = itemName:match("^FoodMagic(.+)$")
    return suffix and ("Food" .. suffix) or nil
end

local function resolveCompositeItem(items, itemName)
    if not itemName then
        return items
    end

    if items[itemName] then
        return items[itemName]
    end

    do
        -- The prefix keeps modded weapons resolvable, e.g. Sync_WeaponTitaniumTrident.
        local prefix, material, shape = itemName:match("^(.-)Weapon([A-Z][a-z]+)(.+)$")
        if material and shape then
            local baseWeapon = prefix .. "Weapon" .. shape
            local materialItem = "AP_Material" .. material

            if items[baseWeapon] and items[materialItem] then
                return { items[baseWeapon], items[materialItem] }
            end
        end
    end

    do
        local baseFood = magicFoodBase(itemName)
        if baseFood and items[baseFood] then
            return items[baseFood]
        end
    end
end

local function resolveCompositeBan(banned, itemName)
    if not itemName then
        return banned
    end

    if banned[itemName] then
        return banned[itemName]
    end

    do
        -- The prefix keeps modded weapons resolvable, e.g. Sync_WeaponTitaniumTrident.
        local prefix, material, shape = itemName:match("^(.-)Weapon([A-Z][a-z]+)(.+)$")
        if material and shape then
            local baseWeapon = prefix .. "Weapon" .. shape
            local materialItem = "AP_Material" .. material

            if banned[baseWeapon] or banned[materialItem] then
                return { banned[baseWeapon], banned[materialItem] }
            end
        end
    end

    do
        local baseFood = magicFoodBase(itemName)
        if baseFood and banned[baseFood] then
            return banned[baseFood]
        end
    end
end

local itemCache = {}
local receivedCounts = {}

-- Locations whose item already took hold when the player physically picked the carrier
-- up -- a diamond credits the balance on pickup -- so the AP grant that follows must not
-- apply it a second time. Kept mod-side: Python derives shopConsumedLocations from the
-- checked SHOP locations and has no way to know a chest carrier applied itself.
local appliedLocations = {}

-- Locations whose carrier the player picked up in person, so the grant that follows must
-- not announce it a second time -- the carrier already said its piece on pickup.
local collectedLocations = {}

itemCache, receivedCounts, appliedLocations, collectedLocations = script.persist(function()
    return itemCache, receivedCounts, appliedLocations, collectedLocations
end)

-- A reload restores through the *previous* script version's closure, so any slot added
-- since it was written comes back nil until the game is restarted outright.
itemCache = itemCache or {}
receivedCounts = receivedCounts or {}
appliedLocations = appliedLocations or {}
collectedLocations = collectedLocations or {}

local function attach(progression)
    function progression.getItems(itemName)
        if permItems[itemName] then
            return permItems[itemName]
        end

        return resolveCompositeItem(itemCache, itemName)
    end

    -- How many copies of an item the slot has received, for items that stack.
    function progression.getReceivedCount(itemName)
        return itemName and receivedCounts[itemName] or 0
    end

    function progression.markItemReceived(itemId)
        if itemId then
            itemCache[itemId] = true
        end
    end

    function progression.markReceivedCount(itemId)
        if itemId then
            receivedCounts[itemId] = (receivedCounts[itemId] or 0) + 1
        end
    end

    function progression.rebuildItemCache(apCharacters, apItems)
        itemCache = {}
        receivedCounts = {}
        for _, entry in pairs(apStorage.saveData.receivedItems or {}) do
            if entry.item then
                receivedCounts[entry.item] = (receivedCounts[entry.item] or 0) + 1
            end

            if entry.itemType == "item" then
                itemCache[entry.item] = true
            elseif not entry.itemType then
                -- Fallback for entries without itemType (shouldn't happen, but safe)
                local id = entry.item
                if id and not apCharacters.isCharacter(id) and not apItems.apItemsList[id] then
                    itemCache[id] = true
                end
            end
        end
    end

    function progression.isItemProcessed(apIndex)
        return apStorage.saveData.receivedItems[tostring(apIndex)] ~= nil
    end

    -- Server grants (-1) and starting inventory (-2) share their codes across every slot,
    -- and an empty code would key every untagged carrier to the same entry.
    local function consumableCode(locationCode)
        if locationCode == nil or locationCode == "" then return nil end

        local code = tostring(locationCode)
        return (tonumber(code) or 0) > 0 and code or nil
    end

    function progression.markLocationConsumed(locationCode)
        local code = consumableCode(locationCode)
        if code then appliedLocations[code] = true end
    end

    function progression.isLocationConsumed(locationCode)
        local code = consumableCode(locationCode)
        return code ~= nil and appliedLocations[code] == true
    end

    function progression.markLocationCollected(locationCode)
        if not locationCode then return end
        collectedLocations[tostring(locationCode)] = true
    end

    function progression.isLocationCollected(locationCode)
        return locationCode ~= nil and collectedLocations[tostring(locationCode)] == true
    end

    function progression.getBannedItems(itemName)
        local banned = apStorage.saveData.bannedItems or {}
        return resolveCompositeBan(banned, itemName)
    end

    function progression.addBannedItem(itemName)
        if not itemName then return end

        apLog("Item banned: " .. itemName)
        apStorage.saveData.bannedItems[itemName] = true
        apStorage.sendChangeRunItems()
    end

    function progression.removeBannedItem(itemName)
        if not itemName then return end

        apLog("Item unbanned: " .. itemName)
        apStorage.saveData.bannedItems[itemName] = nil
        apStorage.sendChangeRunItems()
    end

    function progression.clearBannedItems()
        apLog("All banned items cleared")
        apStorage.saveData.bannedItems = {}
        apStorage.sendChangeRunItems()
    end

    function progression.getNextRunItems(itemName)
        local items = apStorage.saveData.nextRunItems or {}
        if itemName then
            return items[itemName]
        end
        return items
    end

    function progression.addNextRunItem(itemName)
        if not itemName then return end

        apLog("Next run item added: " .. itemName)
        apStorage.saveData.nextRunItems[itemName] = true
        apStorage.sendChangeRunItems()
    end

    function progression.removeNextRunItem(itemName)
        if not itemName then return end

        apLog("Next run item removed: " .. itemName)
        apStorage.saveData.nextRunItems[itemName] = nil
        apStorage.sendChangeRunItems()
    end

    function progression.clearNextRunItems()
        apLog("All next run items cleared")
        apStorage.saveData.nextRunItems = {}
        apStorage.sendChangeRunItems()
    end
end

return {
    attach = attach,
}
