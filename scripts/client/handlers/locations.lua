local match = string.match

local apLog = require("AP.scripts.utils.log").apLog
local apShrines = require("AP.scripts.entities.apShrines")
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")
local progression = require("AP.scripts.client.progression")

-- Keyed by location name, since the server's lists carry those rather than entity names.
local SHRINE_LOCATION_NAMES = {}
for _, location in pairs(apShrines.SHRINE_LOCATIONS) do
    SHRINE_LOCATION_NAMES[location] = true
end

local PATTERNS = {
    SHOP       = "^(.-) %- (%a+) Shop Item (%d+)$",
    ZONE_ONLY  = "^(.-) %- (Zone %d+)$",
    ZONE_FLOOR = "^(.-) %- (Zone %d+) %- Floor %d+$",
    NECRO      = "^(.-) %- NecroDancer$",
    CONDUCTOR  = "^(.-) %- The Conductor$",
    LUTE       = "^(.-) %- Golden Lute$",
    ALL_ZONES  = "^(.-) %- (All Zones)$",
    MODE       = "^(.-) %- (.+ Mode)$",
    NPC        = "^Caged (.+)$",
    ENEMY      = "^Defeat .+$",
}


local function matchCharacterZone(location, saveData)
    local character, zone = match(location, PATTERNS.ZONE_ONLY)
    if character then return character, zone end

    -- Only the "Zone N" check marks a zone complete; floor checks do not.
    character, zone = match(location, PATTERNS.ZONE_FLOOR)
    if character then return character, nil end

    -- Beating a story boss clears the zone it lives in.
    local finalZone =
        saveData.enabledDLCs["Amplified"] and "Zone 5" or "Zone 4"

    local c = match(location, PATTERNS.NECRO)
    if c == "Cadence" or c == "Melody" then
        return c, finalZone
    end

    c = match(location, PATTERNS.CONDUCTOR)
    if c == "Nocturna" then
        return "Nocturna", finalZone
    end

    c = match(location, PATTERNS.LUTE)
    if c == "Aria" then
        return "Aria", "Zone 1"
    end

    character, zone = match(location, PATTERNS.ALL_ZONES)
    if character then return character, zone end

    return match(location, PATTERNS.MODE)
end

local function parseLocation(location, saveData)
    if SHRINE_LOCATION_NAMES[location] then
        return {
            type = "shrine",
            location = location,
        }
    end

    if match(location, PATTERNS.ENEMY) then
        return {
            type = "enemy",
            location = location,
        }
    end

    local shop, side, item = match(location, PATTERNS.SHOP)
    if shop then
        return {
            type = "shop",
            shop = shop,
            side = side,
            slot = tonumber(item) or 1,
        }
    end

    local character, zone = matchCharacterZone(location, saveData)
    if character then
        return {
            type = "character",
            character = character,
            zone = zone,
            raw = location,
        }
    end

    local npc = match(location, PATTERNS.NPC)
    if npc then
        return {
            type = "npc",
            npc = npc,
        }
    end
end

local function parseMissingLocations(saveData, missing_locations)
    apLog("Parsing " .. #missing_locations .. " missing locations")

    for _, location in ipairs(missing_locations) do
        local parsed = parseLocation(location, saveData)
        if not parsed then
            goto continue
        end

        if parsed.type == "shrine" then
            local shrines = saveData.characterLocations["Shrines"] or {}
            if shrines[parsed.location] == nil then
                shrines[parsed.location] = false
            end
            saveData.characterLocations["Shrines"] = shrines
            goto continue
        end

        if parsed.type == "enemy" then
            local enemies = saveData.characterLocations["Enemies"] or {}
            if enemies[parsed.location] == nil then
                enemies[parsed.location] = false
            end
            saveData.characterLocations["Enemies"] = enemies
            goto continue
        end

        if parsed.type == "character" then
            local zone = parsed.zone
            -- Floor checks carry no zone key, so there is nothing to seed for them.
            if zone and (match(zone, "^Zone %d+$")
                or zone == "All Zones"
                or match(zone, ".+ Mode$")) then
                local chars = saveData.characterLocations
                chars[parsed.character] = chars[parsed.character] or {}

                if chars[parsed.character][zone] == nil then
                    chars[parsed.character][zone] = false
                end
            end
        end

        ::continue::
    end
end

local function updateLocations(saveData, checked_locations)
    local character_locations = saveData.characterLocations

    for _, location in ipairs(checked_locations) do
        local parsed = parseLocation(location, saveData)
        if not parsed then
            goto continue
        end

        if parsed.type == "shrine" then
            local shrines = character_locations["Shrines"] or {}
            shrines[parsed.location] = true
            character_locations["Shrines"] = shrines
            goto continue
        end

        if parsed.type == "enemy" then
            local enemies = character_locations["Enemies"] or {}
            enemies[parsed.location] = true
            character_locations["Enemies"] = enemies
            goto continue
        end

        if parsed.type == "npc" then
            local npc = saveData.cagedNPCs[parsed.npc]
            if npc then
                npc.freed = true
            end
            goto continue
        end

        -- Character progression
        local character = parsed.character
        local zone = parsed.zone
        if not character then goto continue end

        character_locations[character] =
            character_locations[character] or {}

        -- A floor check has no zone key; only the "Zone N" check clears a zone.
        if zone == "All Zones" then
            character_locations[character]["All Zones"] = true
        elseif zone ~= nil then
            character_locations[character][zone] = true
        end

        ::continue::
    end
end


handlers.register("Locations", function(message)
    if message.missing_locations then
        parseMissingLocations(apStorage.saveData, message.missing_locations)
    end

    if message.checked_locations then
        updateLocations(apStorage.saveData, message.checked_locations)
        progression.calculateGoalCompletion(true)
    end

    apLog("Locations handler completed")
end)


return {
    handleLocations = function(message)
        if message.missing_locations then
            parseMissingLocations(apStorage.saveData, message.missing_locations)
        end

        if message.checked_locations then
            updateLocations(apStorage.saveData, message.checked_locations)
            progression.calculateGoalCompletion(true)
        end
    end
}
