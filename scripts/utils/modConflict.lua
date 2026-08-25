local resources = require "necro.client.Resources"
local netplay = require "necro.network.Netplay"

local apLog = require("AP.scripts.utils.log").apLog

local LEGACY_NAMES = {
    ["archipelago_io_2278285"] = true,
    ["archipelago"] = true,
}

local modConflict = {}

modConflict.WARNING = "Uninstall the old \"Archipelago\" mod!\nIt conflicts with Archipelago Redux."

local detected

local function findLegacyMod(modList)
    for _, entry in ipairs(modList) do
        if type(entry) == "table" and type(entry.name) == "string"
            and LEGACY_NAMES[entry.name:lower()] then
            return entry.name
        end
    end
end

function modConflict.hasLegacyArchipelago()
    if detected == nil then
        local modList = resources.getData(netplay.Resource.MOD_LIST)

        if type(modList) ~= "table" or #modList == 0 then
            return false
        end

        local name = findLegacyMod(modList)
        detected = name ~= nil

        if detected then
            apLog(("%s (found mod '%s')"):format(modConflict.WARNING, name), "error")
        end
    end

    return detected
end

return modConflict
