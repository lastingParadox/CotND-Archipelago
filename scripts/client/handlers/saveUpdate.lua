local currentLevel = require "necro.game.level.CurrentLevel"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")

local FIELD_MAP = {
    zone_access             = "zoneAccess",
    character_locations     = "characterLocations",
    shop_locations          = "shopLocations",
    codex_locations         = "codexLocations",
    chest_locations         = "chestLocations",
    received_items          = "receivedItems",
    shop_consumed_locations = "shopConsumedLocations",
    health                  = "health",
    shop_stock              = "shopStock",
    diamonds                = "diamonds",
    character_room_key      = "characterRoomKey",
    extra_modes             = "extraModes",
    scouted_locations       = "scoutedLocations",
    banned_items            = "bannedItems",
    next_run_items          = "nextRunItems",
    buffs                   = "buffs",
    hints_purchased         = "hintsPurchased",
    starting_character      = "startingCharacter",
    unlocked_buff_items     = "unlockedBuffItems",
}

-- Mod-owned during a session; both still arrive on the State packet.
local MOD_OWNED = {
    diamonds = true,
    received_items = true,
}

handlers.register("SaveUpdate", function(message)
    local saveData = apStorage.saveData
    for snakeKey, camelKey in pairs(FIELD_MAP) do
        if not MOD_OWNED[snakeKey] then
            local value = message[snakeKey]
            if value ~= nil then
                if camelKey == "characterLocations" then
                    -- Merges rather than replaces, so a locally beaten zone survives a stale reply.
                    local existing = saveData.characterLocations or {}
                    for char, zones in pairs(value) do
                        existing[char] = existing[char] or {}
                        for zone, v in pairs(zones) do
                            if existing[char][zone] ~= true then
                                existing[char][zone] = v
                            end
                        end
                    end
                    saveData.characterLocations = existing
                elseif camelKey == "extraModes" then
                    -- Merges rather than replaces, so an unlocked mode survives a stale reply.
                    local existing = saveData.extraModes or {}
                    for mode, v in pairs(value) do
                        if existing[mode] ~= true then
                            existing[mode] = v
                        end
                    end
                    saveData.extraModes = existing
                else
                    saveData[camelKey] = value
                end
            end
        end
    end

    if currentLevel.isLobby() then visualUpdate.trigger() end
end)

return { FIELD_MAP = FIELD_MAP }
