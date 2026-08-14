local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")

local function locationNameToCodexKey(locationName)
    if locationName == "Dragon Lore" then
        return "DragonLore"
    elseif locationName == "Trap Lore" then
        return "TrapLore"
    elseif locationName == "Bomb Lore" then
        return "BombLore"
    elseif locationName == "How to Get Away with Murder" then
        return "Murder"
    end
    return nil
end

local function scoutLocations(saveData, location_info)
    apLog("Scouting " .. #location_info .. " locations")
    saveData.codexLocations = saveData.codexLocations or {}

    for _, loc in ipairs(location_info) do
        local codexKey = locationNameToCodexKey(loc.location)
        if codexKey and loc.source == "Tutorial" then
            if not saveData.codexLocations[codexKey] then
                saveData.codexLocations[codexKey] = {
                    Item = loc.item,
                    ItemName = string.gsub(loc.itemname, "_", " "),
                    PlayerName = loc.playername,
                    LocationCode = loc.location_code,
                    Classification = loc.flags,
                    Checked = false,
                }
            end
            goto continue
        end

        -- Populated by Python via SaveUpdate; skip so they aren't read as hints.
        if loc.source == "Shop" or loc.source == "Chest" or loc.source == "Flawless_Chest" then
            goto continue
        end

        if not saveData.hintedItems then saveData.hintedItems = {} end
        local itemName = string.gsub(loc.itemname, "_", " ")
        apLog("Hinted item discovered: " .. itemName .. " from " .. loc.playername)
        saveData.hintedItems[loc.item] = {
            ItemName = itemName,
            PlayerName = loc.playername,
            LocationCode = loc.location_code,
            Classification = loc.flags,
        }

        ::continue::
    end
end

handlers.register("LocationInfo", function(message)
    scoutLocations(apStorage.saveData, message.location_info)

    apLog("Completed location info update.")

    if message.location_hint_amounts then
        apStorage.saveData.locationHints = message.location_hint_amounts
    end
end)
