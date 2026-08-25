local collision = require("necro.game.tile.Collision")
local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local extraMode = require "necro.game.data.modifier.ExtraMode"
local minimapTheme = require("necro.game.data.tile.MinimapTheme")

local itemPickup = require "necro.game.item.ItemPickup"

local apBuffItem = require("AP.scripts.items.apBuffItem")
local apCharacters = require("AP.scripts.utils.apCharacters")
local apClient = require("AP.scripts.client.client")
local apPreview = require("AP.scripts.utils.apPreview")
local progression = require("AP.scripts.client.progression")

local apItemShowcase = {}

local function orderedTable(pairsArray)
    local result = {}
    local order = {}

    for _, pair in ipairs(pairsArray) do
        result[pair.key] = pair.value
        table.insert(order, pair.key)
    end

    result.__keyOrder = order
    return result
end

-- Display data for the AP-only unlocks. Membership and category come from the
-- slot's shipped item list; these entries only say how to draw each one, and an
-- entry is only needed when the AP id is not itself a drawable prototype.
apItemShowcase.apShowcaseList = orderedTable({
    { key = "ShrineOfWar",             value = { category = "shrine" } },
    { key = "ShrineOfBlood",           value = { category = "shrine" } },
    { key = "ShrineOfDarkness",        value = { category = "shrine" } },
    { key = "ShrineOfGlass",           value = { category = "shrine" } },
    { key = "ShrineOfPeace",           value = { category = "shrine" } },
    { key = "ShrineOfRhythm",          value = { category = "shrine" } },
    { key = "ShrineOfRisk",            value = { category = "shrine" } },
    { key = "ShrineOfSacrifice",       value = { category = "shrine" } },
    { key = "ShrineOfSpace",           value = { category = "shrine" } },
    { key = "ShrineOfChance",          value = { category = "shrine" } },
    { key = "ShrineOfNoReturn",        value = { category = "shrine" } },
    { key = "ShrineOfPhasing",         value = { category = "shrine" } },
    { key = "ShrineOfPace",            value = { category = "shrine" } },
    { key = "ShrineOfBoss",            value = { category = "shrine" } },
    { key = "ShrineOfPain",            value = { category = "shrine" } },
    { key = "ShrineOfUncertainty",     value = { category = "shrine" } },
    { key = "Sync_ShrineOfFeast",      value = { category = "shrine" } },
    { key = "Sync_ShrineOfFire",       value = { category = "shrine" } },

    -- modeName is the key the slot's extraModes table is stored under.
    { key = "APNoReturnMode",          value = { label = "No Return Mode", category = "mode", modeType = extraMode.Type.NO_RETURN,     modeName = "No Return" } },
    { key = "APHardMode",              value = { label = "Hard Mode", category = "mode", modeType = extraMode.Type.HARD,          modeName = "Hard" } },
    { key = "APPhasingMode",           value = { label = "Phasing Mode", category = "mode", modeType = extraMode.Type.PHASING,       modeName = "Phasing" } },
    { key = "APRandomizerMode",        value = { label = "Randomizer Mode", category = "mode", modeType = extraMode.Type.RANDOMIZER,    modeName = "Randomizer" } },
    { key = "APMysteryMode",           value = { label = "Mystery Mode", category = "mode", modeType = extraMode.Type.MYSTERY,       modeName = "Mystery" } },
    { key = "APNoBeatMode",            value = { label = "No Beat Mode", category = "mode", modeType = extraMode.Type.NO_BEAT,       modeName = "No Beat" } },
    { key = "APDoubleTempoMode",       value = { label = "Double Tempo Mode", category = "mode", modeType = extraMode.Type.DOUBLE_TEMPO,  modeName = "Double Tempo" } },
    { key = "APLowPercentMode",        value = { label = "Low Percent Mode", category = "mode", modeType = extraMode.Type.LOW_PERCENT,   modeName = "Low Percent" } },

    { key = "PermHeart2",              value = { label = "Permanent Health", category = "upgrade", showCount = true } },

    -- Vanilla's own label says "Per Run"; the mod grants one per zone instead.
    { key = "AddchestRed",             value = { label = "+1 Red Chest Per Zone", category = "upgrade" } },
    { key = "AddchestWhite",           value = { label = "+1 Purple Chest Per Zone", category = "upgrade" } },
    { key = "AddchestBlack",           value = { label = "+1 Black Chest Per Zone", category = "upgrade" } },

    { key = "APGoldenLuteShard",       value = { label = "Golden Lute Shard", category = "upgrade", preview = "AP_GoldenLuteShard", showCount = true } },
    { key = "APShopStock",             value = { label = "Shop Restock", category = "upgrade", preview = "AP_ShopStock", showCount = true } },
    { key = "APProgressivePotions",    value = { label = "Progressive Potions", category = "upgrade", preview = "AP_ProgressivePotions", showCount = true } },
    { key = "APProgressiveCoinMultiplier", value = { label = "Progressive Coin Multiplier", category = "upgrade", preview = "AP_ProgressiveCoinMultiplier", showCount = true } },
    { key = "APProgressiveZoneAccess", value = { label = "Progressive Zone Access", category = "upgrade", preview = "AP_ProgressiveZoneAccess", showCount = true } },
    { key = "APZone1Access",           value = { label = "Zone 1 Access", category = "upgrade", preview = "AP_Zone1Access" } },
    { key = "APZone2Access",           value = { label = "Zone 2 Access", category = "upgrade", preview = "AP_Zone2Access" } },
    { key = "APZone3Access",           value = { label = "Zone 3 Access", category = "upgrade", preview = "AP_Zone3Access" } },
    { key = "APZone4Access",           value = { label = "Zone 4 Access", category = "upgrade", preview = "AP_Zone4Access" } },
    { key = "APZone5Access",           value = { label = "Zone 5 Access", category = "upgrade", preview = "AP_Zone5Access" } },
    { key = "APCharRoomKey",           value = { label = "Character Room Key", category = "upgrade", preview = "AP_CharRoomKey" } },

    { key = "AP_MaterialGold",         value = { category = "material" } },
    { key = "AP_MaterialGlass",        value = { category = "material" } },
    { key = "AP_MaterialBlood",        value = { category = "material" } },
    { key = "AP_MaterialObsidian",     value = { category = "material" } },
    { key = "AP_MaterialOnyx",         value = { category = "material" } },
    { key = "AP_MaterialTitanium",     value = { category = "material" } },

    { key = "Trainer",                 value = { category = "npc" } },
    { key = "Merlin",                  value = { category = "npc" } },
    { key = "AP_Hintmaster",           value = { category = "npc" } },
    { key = "Janitor",                 value = { category = "npc" } },
    { key = "Diamonddealer",           value = { category = "npc", offsetY = 4 } },
})

for _, buff in ipairs(apBuffItem.buffs) do
    apItemShowcase.apShowcaseList[buff.entity] = {
        category = "buff",
        label = buff.character .. " Buff",
    }
    table.insert(apItemShowcase.apShowcaseList.__keyOrder, buff.entity)
end

-- Hub display order. `section` splits the room's two halves; the geometry
-- fields are per-category overrides for the chamber generator.
apItemShowcase.categories = {
    { id = "character", name = "Characters",      section = "game", offsetY = 0 },
    { id = "weapon",    name = "Weapons",         section = "game" },
    { id = "shovel",    name = "Shovels",         section = "game" },
    { id = "shield",    name = "Shields",         section = "game" },
    { id = "armor",     name = "Armors",          section = "game" },
    { id = "head",      name = "Headwear",        section = "game" },
    { id = "feet",      name = "Footwear",        section = "game" },
    { id = "torch",     name = "Torches",         section = "game" },
    { id = "ring",      name = "Rings",           section = "game" },
    { id = "spell",     name = "Spells",          section = "game" },
    { id = "scroll",    name = "Scrolls & Tomes", section = "game" },
    { id = "action",    name = "Actions",         section = "game" },
    { id = "misc",      name = "Misc",            section = "game" },

    { id = "shrine",    name = "Shrines",         section = "ap", offsetY = -1 },
    { id = "mode",      name = "Modes",           section = "ap", offsetY = -1 },
    { id = "buff",      name = "Buffs",           section = "ap" },
    { id = "upgrade",   name = "Upgrades",        section = "ap" },
    { id = "material",  name = "Materials",       section = "ap" },
    { id = "npc",       name = "NPCs",            section = "ap", offsetY = 0 },
}

apItemShowcase.categoryByID = {}
for _, descriptor in ipairs(apItemShowcase.categories) do
    apItemShowcase.categoryByID[descriptor.id] = descriptor
end

-- Mode shrines are drawn as the shrine itself rather than the carrier item, so
-- each needs its own prototype; apModeShrine registers them from these entries.
function apItemShowcase.getModeShrineDisplay(modeName)
    return "AP_ModeShrine" .. modeName:gsub("%s", "")
end

for _, name in ipairs(apItemShowcase.apShowcaseList.__keyOrder) do
    local entry = apItemShowcase.apShowcaseList[name]

    if entry.modeType then
        entry.preview = apItemShowcase.getModeShrineDisplay(entry.modeName)
    end
end

-- Showcases sit one tile apart, so a name wider than its tile runs into its
-- neighbour's. Break it across lines instead.
local LABEL_LINE_LENGTH = 11

local function wrapLabel(text)
    if #text <= LABEL_LINE_LENGTH then return text end

    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        if line == "" then
            line = word
        elseif #line + #word + 1 <= LABEL_LINE_LENGTH then
            line = line .. " " .. word
        else
            lines[#lines + 1] = line
            line = word
        end
    end
    lines[#lines + 1] = line

    return table.concat(lines, "\n")
end

-- friendlyName covers real prototypes; the rest name themselves.
function apItemShowcase.getShowcaseLabel(name, data, proto)
    local text = data.label
        or (proto and proto.friendlyName and proto.friendlyName.name)
        or name

    return wrapLabel(text)
end

-- Display data for a shipped item: whatever apShowcaseList declares, else the id
-- doubles as its own prototype. The slot's category always wins, since it comes
-- from the apworld's own item pool.
local function showcaseDataFor(id, category)
    local declared = apItemShowcase.apShowcaseList[id]
    if not declared then
        return { category = category, preview = id }
    end

    local data = { preview = id }
    for key, value in pairs(declared) do
        data[key] = value
    end
    data.category = category

    return data
end

local roomIndex, roomSource

-- Rebuilt whenever a State packet swaps the table out, so it never goes stale.
local function getRoomIndex()
    local room = progression.getItemRoom()

    if roomSource ~= room then
        roomIndex = {}
        for _, entry in ipairs(room) do
            roomIndex[entry.id] = showcaseDataFor(entry.id, entry.category)
        end
        roomSource = room
    end

    return roomIndex
end

function apItemShowcase.getShowcaseData(name)
    if not name then return nil end
    return getRoomIndex()[name] or apItemShowcase.apShowcaseList[name]
end

-- The shipped list is already filtered to what this slot can receive, so the only
-- thing left to check is whether the sprite exists in this install.
function apItemShowcase.getShowcaseCategories()
    local index = getRoomIndex()
    local byCategory = {}

    for _, entry in ipairs(progression.getItemRoom()) do
        local data = index[entry.id]

        if data and ecs.getEntityPrototype(data.preview) then
            local bucket = byCategory[data.category]
            if not bucket then
                bucket = {}
                byCategory[data.category] = bucket
            end
            bucket[#bucket + 1] = { name = entry.id, data = data }
        end
    end

    local result = {}
    for _, descriptor in ipairs(apItemShowcase.categories) do
        result[#result + 1] = {
            descriptor = descriptor,
            items = byCategory[descriptor.id] or {},
        }
    end

    return result
end

customEntities.register({
    name = "AP_ItemShowcase",
    gameObject = {},
    position = {},
    AP_itemShowcase = { active = true, item = "Food1" },
    AP_preview = {},

    collision = {
        mask = collision.Type.OBJECT,
    },
    visibility = {},
    minimapStaticPixel = {
        color = minimapTheme.Color.NPC,
        depth = minimapTheme.Depth.SHRINE,
    },
})

-- Each AP-only category tracks its unlocks somewhere other than the item cache.
local unlockedByCategory = {
    character = function(item)
        return progression.getCharacters(apCharacters.cotNDCharToAPLocation(item))
    end,
    buff = function(item)
        return progression.hasBuffItem(apBuffItem.characterOf[item])
    end,
    mode = function(item, data)
        return progression.getExtraModes(data.modeName)
    end,
    upgrade = function(item)
        return progression.getReceivedCount(item) > 0
    end,
}

local function isItemLocked(item, data)
    if not apClient.isSessionConnected() then return true end

    local resolver = unlockedByCategory[data.category]
    if resolver then
        return not resolver(item, data)
    end
    return not progression.getItems(item)
end


local function countText(item, data)
    if not data.showCount then return nil end

    local count = item == "APProgressiveZoneAccess"
        and progression.getProgressiveZoneAccessCount()
        or progression.getReceivedCount(item)

    return count > 0 and ("x" .. count) or nil
end

event.objectTryCollectItem.add("apPickupShowcaseFail", { order = "checkItem" }, function(ev)
    if (ev.item.AP_itemShowcase and ev.item.AP_itemShowcase.active == true) then
        ev.result = itemPickup.Result.FAILURE
    end
end)


event.render.add("apItemShowCasePreview", { order = "characterPreview", sequence = 3 }, function()
    for entity in ecs.entitiesWithComponents({ "AP_itemShowcase" }) do
        if entity.visibility and entity.visibility.visible and entity.AP_itemShowcase.active then
            local item = entity.AP_itemShowcase.item
            local data = apItemShowcase.getShowcaseData(item) or {}
            local preview = ecs.getEntityPrototype(data.preview or item)

            if preview then
                -- Everything the slot excludes is filtered out of the room, so
                -- what is here is either found or simply not found yet.
                local locked = isItemLocked(item, data)
                local descriptor = apItemShowcase.categoryByID[data.category]

                apPreview.draw(preview, {
                    entity = entity,
                    silhouette = locked,
                    -- Sprites within a category vary enough in height that some
                    -- need their own nudge off the label.
                    offsetY = data.offsetY or (descriptor and descriptor.offsetY) or 5,
                    countText = not locked and countText(item, data) or nil,
                })
            end
        end
    end
end)

return apItemShowcase
