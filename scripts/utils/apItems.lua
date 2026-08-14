local ecs = require "system.game.Entities"
local extraMode = require "necro.game.data.modifier.ExtraMode"
local gfx = require "system.gfx.GFX"

local apCharacters = require("AP.scripts.utils.apCharacters")
local types = require("AP.scripts.utils.types")

local shopLocationRange = { 742080, 742182 }

apItems = {}

apItems.apItemsList = {
    ["APItem"] = true,
    ["APInstantGold"] = true,
    ["APInstantGold2"] = true,
    ["APDiamond1"] = true,
    ["APDiamond2"] = true,
    ["APDiamond3"] = true,
    ["APDiamond4"] = true,
    ["APFullHeal"] = true,
    ["APNoReturnMode"] = true,
    ["APHardMode"] = true,
    ["APPhasingMode"] = true,
    ["APRandomizerMode"] = true,
    ["APMysteryMode"] = true,
    ["APNoBeatMode"] = true,
    ["APDoubleTempoMode"] = true,
    ["APLowPercentMode"] = true,
    ["APShopStock"] = true,
    ["APZone1Access"] = true,
    ["APZone2Access"] = true,
    ["APZone3Access"] = true,
    ["APZone4Access"] = true,
    ["APZone5Access"] = true,
    ["APProgressiveZoneAccess"] = true,
    ["APProgressivePotions"] = true,
    ["APCharRoomKey"] = true,
    ["APGoldenLuteShard"] = true,
}


apItems.isTrapItem = function(item)
    return string.find(item, "Trap") ~= nil
end

apItems.isOwnShopItem = function(item, slotName)
    return item.playername == slotName and item.location_code and
        tonumber(item.location_code) >= shopLocationRange[1] and tonumber(item.location_code) <= shopLocationRange[2]
end

apItems.isPhysicalItem = function(itemId)
    if not itemId or itemId == "" then return false end
    if apItems.isTrapItem(itemId) then return false end
    if apItems.apItemsList[itemId] then return false end
    if apCharacters.isCharacter(itemId) or apCharacters.isNPC(itemId) then return false end

    -- Spawning one would drop an activatable shrine at the player's feet.
    local proto = ecs.getEntityPrototype(itemId)
    if proto and proto.shrine then return false end

    return true
end

apItems.getPriceForItem = function(pricingObj, locationCode, classification, seed)
    if not pricingObj or not pricingObj.type then
        return 1
    end

    -- Create a unique key by combining locationCode and seed
    local key = tostring(locationCode) .. "|" .. tostring(seed)

    -- Simple deterministic hash function
    local function hash(str)
        local h = 0
        for i = 1, #str do
            h = (h * 31 + str:byte(i)) % 2 ^ 31
        end
        return h
    end

    local min, max = 1, 1

    local type = pricingObj.type
    if type == types.PriceRandomization.VANILLA or type == types.PriceRandomization.ITEM_CLASS then
        local ranges = {
            [0] = { pricingObj.filler.min, pricingObj.filler.max },
            [1] = { pricingObj.progression.min, pricingObj.progression.max },
            [2] = { pricingObj.useful.min, pricingObj.useful.max },
            [3] = { pricingObj.progression.min, pricingObj.progression.max + pricingObj.useful.max },
        }

        -- Trap classification
        if classification == 4 or classification == nil or ranges[classification] == nil then
            min, max = ranges[2][1], ranges[2][2]
        else
            min, max = ranges[classification][1], ranges[classification][2]
        end
    else
        min, max = pricingObj.general.min, pricingObj.general.max
    end

    local hashed = hash(key)
    local price = min + (hashed % (max - min + 1))
    return price
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

local GOLD_VALUES = {
    APInstantGold = 50,
    APInstantGold2 = 200,
}

-- Classification flags combine, so they are tested as bits rather than matched
-- as values: AP's progression_skip_balancing is 9, not a class of its own.
local CLASSIFICATIONS = {
    { flag = 4, name = "trap" },
    { flag = 1, name = "progression" },
    { flag = 2, name = "useful" },
}

function apItems.itemClassName(classification)
    for _, entry in ipairs(CLASSIFICATIONS) do
        if bit.band(classification or 0, entry.flag) ~= 0 then return entry.name end
    end

    return "filler"
end

-- Someone else's item has no CotND entity of its own, so it stands in as a
-- placeholder drawn by how their world classified it.
local FOREIGN_ITEM_ENTITIES = {
    filler = "AP_ItemFiller",
    progression = "AP_ItemProgression",
    useful = "AP_ItemUseful",
    trap = "AP_ItemTrap",
}

function apItems.shopItemToObjectData(item)
    local itemId = item["Item"]
    local displayName = item["ItemName"]


    local result = {}

    -- Check if it's a mode shrine
    local modeObjectData = getModeObjectData(itemId)

    if modeObjectData.sprite then
        modeObjectData.sprite.texture = modeObjectData.sprite.texture or "gfx/placeholder.png"
        result = {
            name = "AP_ModeShrine",
            price = 8,
            args = modeObjectData
        }
    elseif apItems.isTrapItem(itemId) then
        result = {
            name = "AP_trap",
            args = {
                AP_trapItem = {
                    locationCode = item["LocationCode"],
                    trap = itemId
                }
            }
        }
    else
        -- Static items
        local map = {
            APDiamond1 = { name = "AP_ResourceDiamond1", price = 1 },
            APDiamond2 = { name = "AP_ResourceDiamond2", price = 2 },
            APDiamond3 = { name = "AP_ResourceDiamond3", price = 3 },
            APDiamond4 = { name = "AP_ResourceDiamond4", price = 4 },
            APFullHeal = { name = "AP_FullHeal", price = 1 },
            APShopStock = { name = "AP_ShopStock", price = 1 },
            APProgressivePotions = { name = "AP_ProgressivePotions", price = 2 },
            APGoldenLuteShard = { name = "AP_GoldenLuteShard", price = 4, named = true },

            APItem = {
                name = FOREIGN_ITEM_ENTITIES[apItems.itemClassName(item["Classification"])],
                price = 1,
                named = true,
            },

            -- Vanilla names these "Per Run", so the apworld's name is the honest
            -- one and has to override the prototype's own label.
            AddchestRed = { name = "AddchestRed", price = 1, named = true },
            AddchestWhite = { name = "AddchestWhite", price = 1, named = true },
            AddchestBlack = { name = "AddchestBlack", price = 1, named = true },

            APProgressiveZoneAccess = { name = "AP_ProgressiveZoneAccess", price = 1 },
            APZone1Access = { name = "AP_Zone1Access", price = 1 },
            APZone2Access = { name = "AP_Zone2Access", price = 1 },
            APZone3Access = { name = "AP_Zone3Access", price = 1 },
            APZone4Access = { name = "AP_Zone4Access", price = 1 },
            APZone5Access = { name = "AP_Zone5Access", price = 1 },
            APCharRoomKey = { name = "AP_CharRoomKey", price = 1 },
        }

        for gold, value in pairs(GOLD_VALUES) do
            map[gold] = {
                name = "AP_Gold",
                price = 1,
                named = true,
                args = { AP_currency = { value = value } },
            }
        end

        result = map[itemId] or { name = itemId, price = 1 }

        -- Carriers share a prototype, so the shop name and flyaway are per-item.
        if result.named then
            result.named = nil
            result.args = result.args or {}
            result.args.AP_itemHintLabel = { text = displayName }
            result.args.AP_flyaway = { text = displayName .. " Obtained!" }
        end
    end

    result.args = result.args or {}
    result.args.AP_player = { name = item["PlayerName"] or "" }
    result.args.AP_itemClass = { classification = item["Classification"] or 0 }

    if apCharacters.isCharacter(itemId) or apCharacters.isNPC(itemId) then
        result.name = "AP_Character"
        result.price = 8
        result.args.AP_character = { name = itemId }
        result.args.AP_itemHintLabel = { text = displayName }
        result.args.AP_flyaway = { text = displayName .. " Unlocked!" }
    end

    return result
end

return apItems
