local ecs = require("system.game.Entities")

local progression = require("AP.scripts.client.progression")

local apCharacters = {}

apCharacters.characterSet = {
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
    ["Hatsune Miku"] = true,
    ["Shovel Knight"] = true,
}

-- Entity name to AP name and back, built from the AP_npc components vanilla.lua attaches.
local npcIndex

local function getNpcIndex()
    if not npcIndex then
        npcIndex = { byEntity = {}, byAPName = {} }

        for _, typeName in ipairs(ecs.getEntityTypesWithComponents({ "AP_npc" })) do
            local apName = ecs.getEntityPrototype(typeName).AP_npc.apName

            if apName ~= "" then
                npcIndex.byEntity[typeName] = apName
                npcIndex.byAPName[apName] = typeName
            end
        end
    end

    return npcIndex
end

event.ecsSchemaReloaded.add("apResetNpcIndex", { order = "clearCache" }, function()
    npcIndex = nil
end)

apCharacters.characterRequirements = {
    ["Cadence"] = "None",
    ["Melody"] = "None",
    ["Aria"] = "None",
    ["Dorian"] = "None",
    ["Eli"] = "None",
    ["Monk"] = "None",
    ["Dove"] = "None",
    ["Coda"] = "None",
    ["Bolt"] = "None",
    ["Bard"] = "None",
    ["Nocturna"] = "Amplified",
    ["Diamond"] = "Amplified",
    ["Mary"] = "Amplified",
    ["Tempo"] = "Amplified",
    ["Reaper"] = "None",
    ["Klarinetta"] = "Synchrony",
    ["Chaunter"] = "Synchrony",
    ["Suzu"] = "Synchrony",
    ["Hatsune Miku"] = "Miku",
    ["Shovel Knight"] = "Shovel Knight",
}

apCharacters.innateStarterItems = {
    Mary = { "Marv" },
}

-- The unique gear a character is handed on selection, from the slot's own requirement list.
function apCharacters.getUniqueItems(name)
    return progression.getCharacterRequirements(name).unique
end

function apCharacters.getMissingRequiredItems(name)
    local characterUnlocks = progression.getCharacterUnlocks()
    if characterUnlocks == "item_only" then return nil end

    local requirements = progression.getCharacterRequirements(name)
    local missing = {}

    local function collectMissing(items)
        for _, item in ipairs(items or {}) do
            if not progression.getItems(item) then
                table.insert(missing, item)
            end
        end
    end

    -- Dorian is the exception to Soft's unique-gear-only rule; his boots are movement.
    if characterUnlocks == "required_items_hard" or name == "Dorian" then
        collectMissing(requirements.normal)
    end

    if progression.getIncludeUniqueItems() then
        collectMissing(requirements.unique)
    end

    return #missing > 0 and missing or nil
end

-- Excluded by the slot rather than simply not found yet.
function apCharacters.isCharacterDisabled(name)
    local character = apCharacters.cotNDCharToAPLocation(name)
    local requirement = apCharacters.characterRequirements[character]

    if progression.getCharacterBlacklist(character) then return true end
    if requirement and requirement ~= "None" and not progression.isDLCEnabled(requirement) then return true end

    return false
end

-- The full rule the character selectors enforce.
function apCharacters.isCharacterPlayable(name)
    if apCharacters.isCharacterDisabled(name) then return false end
    if not progression.getCharacters(apCharacters.cotNDCharToAPLocation(name)) then return false end

    return apCharacters.getMissingRequiredItems(name) == nil
end

function apCharacters.apLocationToCotNDChar(character)
    if character == "Klarinetta" then
        return "Sync_Klarinetta"
    elseif character == "Chaunter" then
        return "Sync_Chaunter"
    elseif character == "Suzu" then
        return "Sync_Suzu"
    elseif character == "Hatsune Miku" then
        return "Coldsteel_Coldsteel"
    elseif character == "Shovel Knight" then
        return "Goldman_Goldman"
    end

    return character
end

function apCharacters.cotNDCharToAPLocation(character)
    if not character then
        return character
    end

    if type(character) == "string" then
        character = character:gsub("^AP_", "")
        character = character:gsub("Bat$", "")
    end

    if character == "Sync_Klarinetta" then
        return "Klarinetta"
    elseif character == "Sync_Chaunter" then
        return "Chaunter"
    elseif character == "Sync_Suzu" then
        return "Suzu"
    elseif character == "Coldsteel_Coldsteel" then
        return "Hatsune Miku"
    elseif character == "Goldman_Goldman" then
        return "Shovel Knight"
    end

    return character
end

function apCharacters.apLocationToCotNDNPC(npc)
    return npc and (getNpcIndex().byAPName[npc] or npc)
end

function apCharacters.cotNDNPCToAPLocation(npc)
    return npc and (getNpcIndex().byEntity[npc] or npc)
end

function apCharacters.isCharacter(item)
    local character = apCharacters.cotNDCharToAPLocation(item)
    return apCharacters.characterSet[character] == true
end

-- Accepts either the entity name or the AP name.
function apCharacters.isNPC(item)
    if not item then return false end

    local index = getNpcIndex()
    return index.byEntity[item] ~= nil or index.byAPName[item] ~= nil
end

function apCharacters.setAPHealth(entity)
    if (entity == nil) then return end

    local proto = ecs.getEntityPrototype(entity.name)
    if (proto == nil or proto.healthLimit.limit == 1) then return end

    local apHealth = progression.getBuffHealth()

    entity.health.health = proto.health.health + apHealth
    entity.health.maxHealth = proto.health.maxHealth + apHealth

    -- Odd case where current health is above max (only seems to show with Dove)
    if entity.health.health > entity.health.maxHealth then
        entity.health.maxHealth = entity.health.health
    end
end

return apCharacters
