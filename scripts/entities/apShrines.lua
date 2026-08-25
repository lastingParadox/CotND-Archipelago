local action           = require "necro.game.system.Action"
local currentLevel     = require "necro.game.level.CurrentLevel"
local ecs              = require "system.game.Entities"
local entityGeneration = require "necro.game.level.EntityGeneration"
local gameDLC          = require "necro.game.data.resource.GameDLC"
local itemBan          = require "necro.game.item.ItemBan"
local object           = require "necro.game.object.Object"
local player           = require "necro.game.character.Player"
local rng              = require "necro.game.system.RNG"
local shrineGeneration = require "necro.game.level.ShrineGeneration"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apGrants    = require("AP.scripts.items.apGrants")
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

local levelShrines = {}

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

-- The engine will not generate a shrine its holder is banned from: Bard never meets the
-- rhythm shrines, Aria and Coda never meet the ones that cost health. Swapping a locked
-- shrine has to honour that too, or the replacement is one the party cannot use. Mirrors
-- ShrineGeneration's own filter rather than restating the ban table.
local function allowedForParty(proto)
    local players = player.getPlayerEntities()
    if #players == 0 then return true end

    for _, entity in ipairs(players) do
        if not itemBan.isBanned(entity, proto, itemBan.Flag.GENERATE_ITEM_POOL) then
            return true
        end
    end

    return false
end

-- shrineGeneration.choice adds "sale" and "!shrinePoolExcludeFromShriner" to its required
-- components when asked for a shriner pool, which is what keeps Sacrifice, Pain, the Feast
-- and Fire (all unsellable) plus Chance out of his stock. Mirrors that rather than
-- restating the list.
local function shrinerEligible(proto)
    if not proto.sale or proto.shrinePoolExcludeFromShriner then return false end
    if player.getCount() < 2 and proto.shrinePoolExcludeFromSinglePlayer then return false end

    return true
end

local function unlockedShrines(eligible)
    local unlocked = {}

    for _, name in ipairs(SHRINE_NAMES) do
        local proto = progression.getItems(name) and ecs.getEntityPrototype(name)

        if proto and allowedForParty(proto) and (not eligible or eligible(proto)) then
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
        local weight = proto and allowedForParty(proto)
            and proto.AP_shrinePoolWeight and proto.AP_shrinePoolWeight.weight or 0

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

local function pendingShrines(names)
    if not progression.getShrineChecks() then return names end

    local checked = apStorage.saveData.characterLocations["Shrines"] or {}
    local pending = {}

    for _, name in ipairs(names) do
        if not checked[SHRINE_LOCATIONS[name]] then
            pending[#pending + 1] = name
        end
    end

    return #pending > 0 and pending or names
end

local function pickShrine(names, present, channel)
    names = pendingShrines(names)

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

-- Snapshotted here rather than at the end of the pass above, which returns early whenever
-- there is no suppressed pool, and refreshed per level because entity ids get reused.
event.levelLoad.add("apSnapshotLevelShrines", { order = "secretRoom", sequence = -1 }, function()
    levelShrines = {}

    if not apUtils.isAPContext() then return end

    for entity in ecs.entitiesWithComponents({ "shrine", "position" }) do
        levelShrines[entity.id] = true
    end
end)


event.levelLoad.add("apReplaceShrinerShrines", { order = "secretRoom", sequence = 1 }, function()
    if not apUtils.isAPContext() then return end

    local unlocked = unlockedShrines(shrinerEligible)
    local offered, present = {}, {}

    for entity in ecs.entitiesWithComponents({ "shrine", "position" }) do
        if not levelShrines[entity.id] and SHRINE_LOCATIONS[entity.name] then
            offered[#offered + 1] = {
                x = entity.position.x,
                y = entity.position.y,
                name = entity.name,
                entity = entity,
            }
        end
    end

    for _, offer in ipairs(offered) do
        local channel = rng.makeChannel(currentLevel.getSeed(), offer.x, offer.y)
        local name = pickShrine(unlocked, present, channel)

        object.delete(offer.entity)

        if name then
            object.spawn(name, offer.x, offer.y)
            present[name] = true
        end

        transferSeen(offer.name, name)
    end
end)

event.objectInteract.add("apSendShrineCheck", { filter = "shrine", order = "activate", sequence = 1 }, function(ev)
    if ev.suppressed or not apUtils.isAPContext() then return end
    if not progression.getShrineChecks() then return end

    -- Not shrine.active: activateShrine sets it, then fires the shrine event, and a
    -- Shrine of Fire taking explosive damage clears it again as it is destroyed.
    if ev.result ~= action.Result.INTERACT then return end

    local location = SHRINE_LOCATIONS[ev.entity.name]
    if not location then return end

    local activated = apStorage.saveData.characterLocations["Shrines"] or {}
    if activated[location] then return end

    activated[location] = true
    apStorage.saveData.characterLocations["Shrines"] = activated

    progression.sendLocationChecks(location)
end)

-- Spawning the entity would drop an activatable shrine at the player's feet, so a granted
-- shrine only ever unlocks the right to generate one.
apGrants.defineFamily({
    order = 30,
    match = function(itemId) return SHRINE_LOCATIONS[itemId] ~= nil end,
    apply = function()
        if currentLevel.isLobby() then visualUpdate.trigger() end
    end,
})

return {
    SHRINE_LOCATIONS = SHRINE_LOCATIONS,
    unlockedShrines = unlockedShrines,
}
