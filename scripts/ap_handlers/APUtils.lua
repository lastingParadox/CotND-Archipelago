local extraMode = require "necro.game.data.modifier.ExtraMode"
local gfx = require "system.gfx.GFX"

local apConnection = require("AP.scripts.ap_handlers.APConnection")
local apItems = require("AP.scripts.ap_handlers.APItems")

local apUtils = {}
apUtils.apLobbyRect = {}

local healthCharExceptions = {
    ["Aria"] = true,
    ["Coda"] = true,
    ["Sync_Chaunter"] = true
}

local healthCharVarianceList = {
    ["Dorian"] = { health = 2, maxHealth = 2 },
    ["Dove"] = { health = 2, maxHealth = 2 },
    ["Coldsteel_Coldsteel"] = { health = 0, maxHealth = 2 }
}

apUtils.characterSet = {
    ["Cadence"] = true,
    ["Melody"] = true,
    ["Aria"] = true,
    ["Dorian"] = true,
    ["Eli"] = true,
    ["Monk"] = true,
    ["Dove"] = true,
    ["Coda"] = true,
    ["Bolt"] = true,
    ["Bard"] = true,
    ["Nocturna"] = true,
    ["Diamond"] = true,
    ["Mary"] = true,
    ["Tempo"] = true,
    ["Reaper"] = true,
    ["Klarinetta"] = true,
    ["Chaunter"] = true,
    ["Suzu"] = true,
    ["Miku"] = true,
}

apUtils.PriceRandomizationType = {
    VANILLA = 0,
    VANILLA_RAND = 1,
    ITEM_CLASS = 2,
    COMPLETE = 3,
}

function apUtils.apLocationToCotNDChar(character)
    if character == "Klarinetta" then return "Sync_Klarinetta"
    elseif character == "Chaunter" then return "Sync_Chaunter"
    elseif character == "Suzu" then return "Sync_Suzu"
    elseif character == "Miku" then return "Coldsteel_Coldsteel" end

    return character
end

function apUtils.cotNDCharToAPLocation(character)
    if character == "Sync_Klarinetta" then return "Klarinetta"
    elseif character == "Sync_Chaunter" then return "Chaunter"
    elseif character == "Sync_Suzu" then return "Suzu"
    elseif character == "Coldsteel_Coldsteel" then return "Miku" end

    return character
end

function apUtils.isCharacter(item)
    local character = apUtils.cotNDCharToAPLocation(item)
    return apUtils.characterSet[character] == true
end

-- To be ran on save initialization
function apUtils.parseMissingLocations(saveData, missing_locations)
    for _, location in ipairs(missing_locations) do
        -- Shop location
        local shop_name, side, item_num = string.match(location, "^(.-) %- (%a+) Shop Item (%d+)$")
        if shop_name then
            if not saveData.shopLocations[shop_name] then
                saveData.shopLocations[shop_name] = {}
            end
            if not saveData.shopLocations[shop_name][side] then
                saveData.shopLocations[shop_name][side] = { Current = 1, Slots = {} }
            end
            local slot_num = tonumber(item_num)
            if not saveData.shopLocations[shop_name][side].Slots[slot_num] then
                saveData.shopLocations[shop_name][side].Slots[slot_num] = { Item = "", ItemName = "", Checked = false }
            end
        else
            -- Character location
            local character, zone = string.match(location, "^(.-) %- (Zone %d+)$")

            if not character then
                character, zone = string.match(location, "^(.-) %- (.+ Mode)$")
            end

            if character then
                if not saveData.characterLocations[character] then
                    saveData.characterLocations[character] = {}
                end
                if saveData.characterLocations[character][zone] == nil then
                    saveData.characterLocations[character][zone] = false
                end
                if saveData.characterLocations[character]["All Zones"] == nil then
                    saveData.characterLocations[character]["All Zones"] = false
                end
            end
        end
    end
end

function apUtils.updateLocations(saveData, checked_locations)
    local character_locations = saveData.characterLocations
    local shop_locations = saveData.shopLocations

    for _, location in ipairs(checked_locations) do
        local shop_name, side, item_num = string.match(location, "^(.-) %- (%a+) Shop Item (%d+)$")
        if shop_name then
            local slot_num = tonumber(item_num) or 1
            if
                shop_locations[shop_name]
                and shop_locations[shop_name][side]
                and shop_locations[shop_name][side].Slots[slot_num]
            then
                shop_locations[shop_name][side].Slots[slot_num].Checked = true
            else
                if not shop_locations[shop_name] then shop_locations[shop_name] = {} end
                if not shop_locations[shop_name][side] then
                    shop_locations[shop_name][side] = { Current = 1, Slots = {} }
                end
                shop_locations[shop_name][side].Slots[slot_num] = { Item = "", ItemName = "", Checked = true }
            end
        else
            local character, zone = string.match(location, "^(.-)%s*%-%s*(Zone %d+)$")

            if not character then
                character, zone = string.match(location, "^(.-) %- (.+ Mode)$")
            end

            if character then
                if not character_locations[character] then
                    character_locations[character] = {}
                end
                character_locations[character][zone] = true
            end
        end
    end
end

function apUtils.scoutShopLocations(saveData, location_info)
    for _, loc in ipairs(location_info) do
        local shop_name, side, item_num = string.match(loc.location, "^(.-) %- (%a+) Shop Item (%d+)$")
        if shop_name then
            local slot_num = tonumber(item_num)
            saveData.shopLocations[shop_name][side].Slots[slot_num] = {
                Item = loc.item,
                ItemName = string.gsub(loc.itemname, "_", " "),
                PlayerName = loc.playername,
                LocationCode = loc.location_code,
                Classification = loc.flags,
                Checked = false,
            }
        end
    end
end

local function getModeObjectData(itemName)
    local map = {
        APNoReturnMode = { enum = extraMode.Type.NO_RETURN, text = "No Return Mode", AP_flyaway = { text = "No Return Mode Unlocked" } },
        APHardMode = { enum = extraMode.Type.HARD, text = "Hard Mode", AP_flyaway = { text = "Hard Mode Unlocked" } },
        APPhasingMode = { enum = extraMode.Type.PHASING, text = "Phasing Mode", AP_flyaway = { text = "Phasing Mode Unlocked" } },
        APRandomizerMode = { enum = extraMode.Type.RANDOMIZER, text = "Randomizer Mode", AP_flyaway = { text = "Randomizer Mode Unlocked" } },
        APMysteryMode = { enum = extraMode.Type.MYSTERY, text = "Mystery Mode", AP_flyaway = { text = "Mystery Mode Unlocked" } },
        APNoBeatMode = { enum = extraMode.Type.NO_BEAT, text = "No Beat Mode", AP_flyaway = { text = "No Beat Mode Unlocked" } },
        APDoubleTempoMode = { enum = extraMode.Type.DOUBLE_TEMPO, text = "Double Tempo Mode", AP_flyaway = { text = "Double Tempo Mode Unlocked" } },
        APLowPercentMode = { enum = extraMode.Type.LOW_PERCENT, text = "Low Percent Mode", AP_flyaway = { text = "Low Percent Mode Unlocked" } },
    }

    local mapItem = map[itemName]
    if not mapItem then return {} end

    local shrineData = extraMode.Type.data[mapItem.enum].shrine
    local textureWidth, textureHeight = gfx.getImageSize(shrineData.texture)

    return {
        sprite = {
            texture = shrineData.texture,
            width = math.floor(textureWidth / 2),
            height = math.floor(textureHeight / 2),
        },
        spriteSheet = {
            frameX = 2,
            frameY = 1
        },
        positionalSprite = {
            offsetX = shrineData.offsetX,
            offsetY = shrineData.offsetY,
        },
        AP_itemHintLabel = {
            text = mapItem.text,
        },
    }
end

function apUtils.itemNameToObjectData(item)
    local itemId = item["Item"]
    local displayName = item["ItemName"]


    -- Check if it's a mode shrine
    local modeObjectData = getModeObjectData(itemId)
    if modeObjectData.sprite then
        modeObjectData.sprite.texture = modeObjectData.sprite.texture or "gfx/placeholder.png"
        return {
            name = "AP_ModeShrine",
            price = 8,
            args = modeObjectData
        }
    end

    -- Static items
    local map = {
        APInstantGold = {
            name = "AP_Gold",
            price = 1,
            args = {
                AP_itemHintLabel = { text = displayName },
                AP_currency = { value = 50 }
            }
        },
        APInstantGold2 = {
            name = "AP_Gold",
            price = 1,
            args = {
                AP_itemHintLabel = { text = displayName },
                AP_currency = { value = 200 }
            }
        },
        APDiamond1 = { name = "ResourceDiamond", price = 1 },
        APDiamond2 = { name = "ResourceDiamond2", price = 2 },
        APDiamond3 = { name = "ResourceDiamond3", price = 3 },
        APDiamond4 = { name = "ResourceDiamond4", price = 4 },
        APFullHeal = { name = "AP_FullHeal", price = 1 },
        APItem = {
            name = "AP_Item",
            price = 1,
            args = {
                AP_itemHintLabel = { text = displayName },
                AP_flyaway = { text = displayName .. " Obtained" }
            }
        },
    }

    local result = map[itemId] or { name = itemId, price = 1 }

    result.args = result.args or {}
    result.args.AP_player = { name = item["PlayerName"] or "" }
    result.args.AP_itemClass = { classification = item["Classification"] or 0 }

    -- Characters cost more
    if apUtils.characterSet[itemId] then
        result.price = 8
        result.args.AP_flyaway = { text = displayName .. " Unlocked" }
    end

    return result
end

function apUtils.setLobbyRect(rect)
    apUtils.apLobbyRect = rect
end

function apUtils.isInLobby(entity)
    if #apUtils.apLobbyRect == 0 then return false end
    local minX = apUtils.apLobbyRect[1]
    local minY = apUtils.apLobbyRect[2]
    local maxX = minX + apUtils.apLobbyRect[3]
    local maxY = minY + apUtils.apLobbyRect[4]

    return (entity.position.x >= minX and entity.position.x <= maxX) and
        (entity.position.y >= minY and entity.position.y <= maxY)
end

function apUtils.setAPHealth(entity)
    if healthCharExceptions[entity.name] then return end

    local variance = healthCharVarianceList[entity.name] or {}
    local base = apConnection.saveData.health or 6

    entity.health.maxHealth = base + (variance.maxHealth or 0)

    if (variance.health) then entity.health.health = base + (variance.health or 0) end
end

return apUtils
