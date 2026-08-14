local ecs = require("system.game.Entities")
local rng = require "necro.game.system.RNG"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

apItemFactory.define({
    name = "AP_trap",
    -- Only ever seen in the level editor; APTrapSprite overwrites it on spawn.
    texture = "items/ap_item/ap_item_trap.png",
    hint = L("AP Trap", "AP.trap.hint"),
    flyaway = L("Was that a scam?", "AP.trap.scam"),
    components = {
        AP_trapItem = {},
    },
})

-- Pairs that read as each other at label size. Digit lookalikes are excluded:
-- gfx/font.png slashes its zero, flags its one, and serifs its capital I.
local HOMOGLYPHS = {
    { "m", "rn" }, { "rn", "m" },
    { "w", "vv" }, { "vv", "w" },
    { "W", "VV" }, { "VV", "W" },
    { "d", "cl" }, { "cl", "d" },
}

local VOWELS = { a = "e", e = "a", i = "e", o = "u", u = "o" }

local mutations = {}

function mutations.homoglyph(name, channel)
    local sites = {}

    for _, pair in ipairs(HOMOGLYPHS) do
        local from, to = pair[1], pair[2]
        local start = 1

        while true do
            local first, last = name:find(from, start, true)
            if not first then break end

            sites[#sites + 1] = { first = first, last = last, to = to }
            start = first + 1
        end
    end

    if #sites == 0 then return nil end

    local site = rng.choice(sites, channel)
    return name:sub(1, site.first - 1) .. site.to .. name:sub(site.last + 1)
end

function mutations.swap(name, channel)
    if #name <= 2 then return nil end

    local i = rng.range(2, #name - 1, channel)
    local previous, current = name:sub(i - 1, i - 1), name:sub(i, i)

    if not (previous:match("%a") and current:match("%a")) then return nil end

    return name:sub(1, i - 2) .. current .. previous .. name:sub(i + 1)
end

function mutations.vowel(name, channel)
    local indices = {}

    for i = 1, #name do
        if VOWELS[name:sub(i, i):lower()] then indices[#indices + 1] = i end
    end

    if #indices == 0 then return nil end

    local index = rng.choice(indices, channel)
    local original = name:sub(index, index)
    local replacement = VOWELS[original:lower()]

    if original:upper() == original then replacement = replacement:upper() end

    return name:sub(1, index - 1) .. replacement .. name:sub(index + 1)
end

function mutations.double(name, channel)
    local i = rng.range(1, #name, channel)
    local character = name:sub(i, i)

    if not character:match("%a") then return nil end

    return name:sub(1, i) .. character .. name:sub(i + 1)
end

local METHODS = { "homoglyph", "swap", "vowel", "double" }

-- Rotates rather than shuffles: rng.shuffle mutates its argument, and METHODS
-- is shared. Falling through keeps a method that cannot apply to this name from
-- leaving it spelled correctly.
local function getMisspelledName(name, channel)
    if not name or #name < 2 then
        return name
    end

    local first = rng.range(1, #METHODS, channel)

    for offset = 0, #METHODS - 1 do
        local result = mutations[METHODS[(first + offset - 1) % #METHODS + 1]](name, channel)

        if result and result ~= name then return result end
    end

    return name
end


local DISGUISE_SPRITE_FIELDS = {
    "texture", "width", "height", "textureShiftX", "textureShiftY", "scale", "color",
}

event.objectSpawn.add("APTrapSprite", { order = "overrides", filter = "AP_trapItem" }, function(ev)
    local trapEntity = ev.entity
    local itemEntities = {}

    for _, type in ipairs(ecs.getEntityTypesWithComponents({ "item" })) do
        local entity = ecs.getEntityPrototype(type)
        if not (entity.playableCharacter or entity.lobbyImmunity or entity.itemLobbyProgressionUnlock) and entity.sprite then
            table.insert(itemEntities, entity)
        end
    end

    local seedName = progression.getSeedName() or "0"
    local locationCode = tostring(trapEntity.AP_trapItem.locationCode or "0")
    local seedStr = seedName .. "-" .. locationCode

    -- rng.makeChannel requires a number; hash the string seed into one.
    local channelSeed = 0
    for i = 1, #seedStr do
        channelSeed = (channelSeed * 31 + string.byte(seedStr, i)) % 2147483647
    end

    local channel = rng.makeChannel(channelSeed)
    local chosen = rng.shuffle(itemEntities, channel)[1]

    -- Only what the disguise looks like. x/y are live render coordinates and
    -- mirrorX/visible are per-instance state, so copying the whole component
    -- would hand the trap another entity's position.
    for _, field in ipairs(DISGUISE_SPRITE_FIELDS) do
        trapEntity.sprite[field] = chosen.sprite[field]
    end

    local label = (chosen.itemHintLabel and chosen.itemHintLabel.text) or (chosen.friendlyName and chosen.friendlyName.name)
    local misspelled = getMisspelledName(label, channel)

    trapEntity.AP_itemHintLabel = { text = misspelled }
end)
