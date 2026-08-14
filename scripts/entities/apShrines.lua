local currentLevel     = require "necro.game.level.CurrentLevel"
local ecs              = require "system.game.Entities"
local entityGeneration = require "necro.game.level.EntityGeneration"
local gameDLC          = require "necro.game.data.resource.GameDLC"
local object           = require "necro.game.object.Object"
local rng              = require "necro.game.system.RNG"
local shrineGeneration = require "necro.game.level.ShrineGeneration"

local apStorage   = require("AP.scripts.client.storage")
local apUtils     = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local SHRINE_LOCATIONS = {
    ShrineOfWar         = "Shrine of War",
    ShrineOfBlood       = "Shrine of Blood",
    ShrineOfDarkness    = "Shrine of Darkness",
    ShrineOfGlass       = "Shrine of Glass",
    ShrineOfPeace       = "Shrine of Peace",
    ShrineOfRhythm      = "Shrine of Rhythm",
    ShrineOfRisk        = "Shrine of Risk",
    ShrineOfSacrifice   = "Shrine of Sacrifice",
    ShrineOfSpace       = "Shrine of Space",
    ShrineOfChance      = "Shrine of Chance",
    ShrineOfNoReturn    = "Shrine of No Return",
    ShrineOfPhasing     = "Shrine of Phasing",
    ShrineOfPace        = "Shrine of Pace",
    ShrineOfBoss        = "Boss Shrine",
    ShrineOfPain        = "Shrine of Pain",
    ShrineOfUncertainty = "Shrine of Uncertainty",
    Sync_ShrineOfFeast  = "Shrine of the Feast",
    Sync_ShrineOfFire   = "Shrine of Fire",
}

-- Sorted for a deterministic pool order across clients.
local SHRINE_NAMES = {}
for name in pairs(SHRINE_LOCATIONS) do
    SHRINE_NAMES[#SHRINE_NAMES + 1] = name
end
table.sort(SHRINE_NAMES)

local AMPLIFIED_SUPPRESSED = {
    ShrineOfNoReturn = true,
    ShrineOfPhasing = true,
    ShrineOfPace = true,
}

for name in pairs(AMPLIFIED_SUPPRESSED) do
    event.entitySchemaLoadNamedEntity.add("apKeep" .. name .. "Weight", { key = name, sequence = 0 },
        function(ev)
            if ev.entity.shrinePoolAllZones then
                ev.entity.AP_shrinePoolWeight = { weight = ev.entity.shrinePoolAllZones.weight }
            end
        end)
end

local function unlockedShrines()
    local unlocked = {}
    for _, name in ipairs(SHRINE_NAMES) do
        if progression.getItems(name) and ecs.getEntityPrototype(name) then
            unlocked[#unlocked + 1] = name
        end
    end
    return unlocked
end

local function suppressedPool()
    if not gameDLC.isAmplifiedLoaded() or progression.isDLCEnabled("Amplified") then return nil end

    local pool = { names = {}, total = 0, competing = 0 }

    for _, name in ipairs(SHRINE_NAMES) do
        local proto = AMPLIFIED_SUPPRESSED[name] and progression.getItems(name)
            and ecs.getEntityPrototype(name)
        local weight = proto and proto.AP_shrinePoolWeight and proto.AP_shrinePoolWeight.weight or 0

        if weight > 0 then
            pool.names[#pool.names + 1] = name
            pool.total = pool.total + weight
        end
    end

    if pool.total <= 0 then return nil end

    for _, proto in ecs.prototypesWithComponents({ "shrinePoolAllZones" }) do
        pool.competing = pool.competing + proto.shrinePoolAllZones.weight
    end

    return pool
end

local function transferSeen(removed, added)
    local seen = shrineGeneration.getSeenCounts()

    if removed then entityGeneration.markSeen(removed, -1, seen) end
    if added then entityGeneration.markSeen(added, 1, seen) end
end

local function pickShrine(names, present, channel)
    local unseen, unused = {}, {}
    local seen = shrineGeneration.getSeenCounts()

    for _, name in ipairs(names) do
        if not present[name] then
            unused[#unused + 1] = name
            if (seen[name] or 0) == 0 then unseen[#unseen + 1] = name end
        end
    end

    local choices = #unseen > 0 and unseen or (#unused > 0 and unused or names)
    return #choices > 0 and rng.choice(choices, channel) or nil
end

-- Every shrine is precollected when the slot does not randomise them, so this
-- replaces nothing in that case without needing to know the option.
event.levelLoad.add("apReplaceLockedShrines", { order = "shrines", sequence = 1 }, function()
    if not apUtils.isAPContext() then return end

    local unlocked = unlockedShrines()
    local replacements = {}
    local kept = {}
    local present = {}

    for entity in ecs.entitiesWithComponents({ "shrine", "position" }) do
        if SHRINE_LOCATIONS[entity.name] and not progression.getItems(entity.name) then
            replacements[#replacements + 1] = {
                x = entity.position.x,
                y = entity.position.y,
                name = entity.name,
                entity = entity,
            }
        else
            kept[#kept + 1] = entity
            present[entity.name] = true
        end
    end

    for _, replacement in ipairs(replacements) do
        local channel = rng.makeChannel(currentLevel.getSeed(), replacement.x, replacement.y)
        local name = pickShrine(unlocked, present, channel)

        object.delete(replacement.entity)

        if name then
            object.spawn(name, replacement.x, replacement.y)
            present[name] = true
        end

        transferSeen(replacement.name, name)
    end

    local pool = suppressedPool()
    if not pool then return end

    for _, entity in ipairs(kept) do
        local x, y = entity.position.x, entity.position.y
        local channel = rng.makeChannel(currentLevel.getSeed(), x, y)

        if rng.range(1, pool.competing + pool.total, channel) > pool.competing then
            local name = pickShrine(pool.names, present, channel)

            if name then
                local removed = entity.name

                object.delete(entity)
                object.spawn(name, x, y)
                present[removed] = nil
                present[name] = true
                transferSeen(removed, name)
            end

            break
        end
    end
end)

event.objectInteract.add("apSendShrineCheck", { filter = "shrine", order = "activate", sequence = 1 }, function(ev)
    if ev.suppressed or not apUtils.isAPContext() then return end
    if not progression.getShrineChecks() then return end
    if not ev.entity.shrine or not ev.entity.shrine.active then return end

    local location = SHRINE_LOCATIONS[ev.entity.name]
    if not location then return end

    local activated = apStorage.saveData.characterLocations["Shrines"] or {}
    if activated[location] then return end

    activated[location] = true
    apStorage.saveData.characterLocations["Shrines"] = activated

    progression.sendLocationChecks(location)
end)

return { SHRINE_LOCATIONS = SHRINE_LOCATIONS }
