local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")

local function attach(progression)
    function progression.getShopStock()
        return apStorage.saveData.shopStock or 0
    end

    function progression.addShopStock(amount)
        local originalAmount = apStorage.saveData.shopStock or 0
        apStorage.saveData.shopStock = originalAmount + amount

        if apStorage.saveData.shopStock < 0 then
            apStorage.saveData.shopStock = 0
        end

        apLog("Shop stock changed by " .. amount .. ", new total: " .. apStorage.saveData.shopStock)
    end

    function progression.getPricing()
        return apStorage.saveData.pricing or {}
    end

    function progression.getLocationHints()
        return apStorage.saveData.locationHints or {}
    end

    function progression.getShopLocations(shopLocation)
        local locations = apStorage.saveData.shopLocations or {}
        if shopLocation then
            return locations[shopLocation]
        end
        return locations
    end

    -- "stocked" (an item is on display), "gated" (a slot remains but needs more
    -- Shop Restock), or "empty" (every slot bought out; restock won't help).
    function progression.getShopState(npc)
        local sections = progression.getShopLocations(npc)
        if not sections then return "stocked" end

        local shopStock = progression.getShopStock()
        local gated = false

        for _, section in pairs(sections) do
            local slots = section.Slots or {}
            local keys = {}
            for key in pairs(slots) do keys[#keys + 1] = key end
            table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)

            for _, key in ipairs(keys) do
                local slot = slots[key]
                if slot.Checked == false and slot.Item and slot.Item ~= "" then
                    if shopStock >= tonumber(key) - 1 then
                        return "stocked"
                    end
                    gated = true
                    break
                end
            end
        end

        return gated and "gated" or "empty"
    end

    function progression.getCodexLocations(codexKey)
        local locations = apStorage.saveData.codexLocations or {}
        if codexKey then
            return locations[codexKey]
        end
        return locations
    end

    function progression.getChestLocations(zone, kind)
        local zones = apStorage.saveData.chestLocations or {}
        if not zone then return zones end

        local located = zones[tostring(zone)]
        if not located or not kind then return located end

        return located[kind]
    end

    function progression.getNextChestLocation(zone, kind)
        for _, located in ipairs(progression.getChestLocations(zone, kind) or {}) do
            if located.Item and located.Item ~= "" and not located.Checked then
                return located
            end
        end

        return nil
    end

    function progression.getChestLocationByCode(locationCode)
        if not locationCode then return nil end
        local code = tostring(locationCode)

        for _, kinds in pairs(apStorage.saveData.chestLocations or {}) do
            for _, entries in pairs(kinds) do
                for _, located in ipairs(entries) do
                    if tostring(located.LocationCode) == code then return located end
                end
            end
        end

        return nil
    end

    function progression.getScoutedLocations()
        return apStorage.saveData.scoutedLocations or false
    end
end

return {
    attach = attach,
}
