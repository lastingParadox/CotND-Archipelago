local resources = require "necro.client.Resources"
local netplay = require "necro.network.Netplay"

local MOD_VERSION_FALLBACK = "3.1.1"

local function getModVersion()
    local modList = resources.getData(netplay.Resource.MOD_LIST)
    if type(modList) == "table" then
        for _, entry in ipairs(modList) do
            if type(entry) == "table"
                and (entry.namespace == "AP" or entry.name == "AP" or entry.name == "AP_io_5178782")
                and type(entry.version) == "string" and entry.version ~= "" then
                return entry.version
            end
        end
    end
    return MOD_VERSION_FALLBACK
end

-- Minimum apworld release (archipelago.json's world_version) this mod build works with.
local MIN_APWORLD_VERSION = "0.7.1"

local function parseVersion(str)
    local parts = {}
    for num in tostring(str or ""):gmatch("%d+") do
        parts[#parts + 1] = tonumber(num)
    end
    return parts
end

local function compare(a, b)
    local partsA, partsB = parseVersion(a), parseVersion(b)
    for i = 1, math.max(#partsA, #partsB) do
        local va, vb = partsA[i] or 0, partsB[i] or 0
        if va ~= vb then
            return va < vb and -1 or 1
        end
    end
    return 0
end

local function isApworldCompatible(apworldVersion)
    if not apworldVersion or apworldVersion == "" then return false end
    return compare(apworldVersion, MIN_APWORLD_VERSION) >= 0
end

return {
    getModVersion = getModVersion,
    MIN_APWORLD_VERSION = MIN_APWORLD_VERSION,
    compare = compare,
    isApworldCompatible = isApworldCompatible,
}
