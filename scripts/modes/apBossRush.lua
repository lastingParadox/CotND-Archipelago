local boss = require("necro.game.level.Boss")
local currentLevel = require("necro.game.level.CurrentLevel")
local ecs = require("system.game.Entities")
local enum = require("system.utils.Enum")
local gameSession = require "necro.client.GameSession"
local levelSequence = require "necro.game.level.LevelSequence"
local marker = require "necro.game.tile.Marker"
local object = require("necro.game.object.Object")
local proceduralRun = require "necro.game.data.level.ProceduralRun"
local rng = require "necro.game.system.RNG"

local apBossRushShop = require("AP.scripts.level.apBossRushShop")
local apCharacters = require("AP.scripts.utils.apCharacters")
local progression = require("AP.scripts.client.progression")

gameSession.Mode.extend(
    "APBossRush",
    enum.data({
        id = "APBossRush",
        name = "AP Boss Rush",
        visible = false,
        bossFlawlesses = true,
        cutscenes = true,
        diamondCounter = true,
        extraEnemiesPerFloor = 3,
        generatorOptions = {
            type = "Necro",
        },
        introText = true,
        multiCharEnabled = false,
        progressionUnlockCharacters = false,
        resetDiamonds = false,
        resetTimeScale = true,
        statisticsEnabled = true,
        statisticsTrackHardcoreClears = true,
        timerHUD = true,
        timerName = "Speedrun",
    })
)

local STORY_BOSSES = {
    { type = boss.Type.DEAD_RINGER,     zone = 4 },
    { type = boss.Type.NECRODANCER,     zone = 4 },
    { type = boss.Type.NECRODANCER_2,   zone = 4 },
    { type = boss.Type.GOLDEN_LUTE,     zone = 1 },
    { type = boss.Type.FRANKENSTEINWAY, zone = 5 },
    { type = boss.Type.CONDUCTOR,       zone = 5 },
}

-- Story bosses that make a poor last fight, kept off the end of the sequence when possible.
local WEAK_FINALE = {
    [boss.Type.FRANKENSTEINWAY] = true,
    [boss.Type.DEAD_RINGER] = true,
}

local BOSS_BLACKLIST = {
    Dorian   = { [boss.Type.NECRODANCER] = true, [boss.Type.FRANKENSTEINWAY] = true , [boss.Type.CONDUCTOR] = true },
    Monk     = { [boss.Type.NECRODANCER_2] = true },
    Tempo    = { [boss.Type.NECRODANCER] = true, [boss.Type.GOLDEN_LUTE] = true },
    Chaunter = { [boss.Type.FRANKENSTEINWAY] = true, [boss.Type.CONDUCTOR] = true, [boss.Type.GOLDEN_LUTE] = true },
    Dove     = {
        [boss.Type.DEAD_RINGER] = true,
        [boss.Type.NECRODANCER] = true,
        [boss.Type.NECRODANCER_2] = true,
        [boss.Type.GOLDEN_LUTE] = true,
        [boss.Type.FRANKENSTEINWAY] = true,
        [boss.Type.CONDUCTOR] = true,
    },
}

local function blockedBosses(prototypes)
    local blocked

    for _, prototype in ipairs(prototypes or {}) do
        local character = apCharacters.cotNDCharToAPLocation(prototype.name)
        local list = BOSS_BLACKLIST[character] or {}

        if not blocked then
            blocked = {}
            for bossType in pairs(list) do
                blocked[bossType] = true
            end
        else
            for bossType in pairs(blocked) do
                if not list[bossType] then
                    blocked[bossType] = nil
                end
            end
        end
    end

    return blocked or {}
end

local function slotKey(bossType, zone)
    return bossType .. ":" .. zone
end

local function unusedZoneBoss(used, zone)
    for _, bossType in ipairs(proceduralRun.getBossPool()) do
        if not used[slotKey(bossType, zone)] then
            return bossType
        end
    end
end

event.levelSequenceUpdate.add("apBossRushSequence", { order = "bossRush" }, function(ev)
    if ev.mode.id ~= "APBossRush" then return end

    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4

    local sequence = {}
    local used = {}

    -- The zone bosses the All Zones sequence already picked, at their own depths.
    for _, entry in ipairs(ev.sequence) do
        if entry.boss and entry.boss ~= boss.Type.NONE and entry.zone <= lastZone then
            sequence[#sequence + 1] = entry
            used[slotKey(entry.boss, entry.zone)] = true
        end
    end

    local blacklist = blockedBosses(ev.characterPrototypes)

    local function append(bossType, zone)
        local entry = proceduralRun.addBoss(sequence, bossType)
        if entry then
            entry.zone, entry.depth = zone, zone
            used[slotKey(bossType, zone)] = true
        end
    end

    local slots = lastZone

    local story = {}
    for _, entry in ipairs(STORY_BOSSES) do
        if entry.zone <= lastZone and not blacklist[entry.type] then
            story[#story + 1] = entry
        end
    end

    rng.shuffle(story, ev.rng)

    -- Already shuffled, so trimming the tail drops a random boss rather than a fixed one.
    for _ = slots + 1, #story do
        table.remove(story)
    end

    -- A weak finale closes a run only when nothing else survived blacklisting and trimming.
    if #story > 1 and WEAK_FINALE[story[#story].type] then
        local candidates = {}

        for i = 1, #story - 1 do
            if not WEAK_FINALE[story[i].type] then candidates[#candidates + 1] = i end
        end

        if #candidates > 0 then
            local swap = candidates[rng.int(#candidates, ev.rng) + 1]
            story[#story], story[swap] = story[swap], story[#story]
        end
    end

    -- Fillers first, at the deepest zone, so the run still ends on a story boss.
    for _ = 1, slots - #story do
        local bossType = unusedZoneBoss(used, lastZone)
        if not bossType then break end
        append(bossType, lastZone)
    end

    for _, entry in ipairs(story) do
        append(entry.type, entry.zone)
    end

    -- A shop breaks up the fights at the midpoint of the run.
    if #sequence > 1 then
        local shopIndex = math.floor(#sequence / 2) + 1
        table.insert(sequence, shopIndex, apBossRushShop.levelEntry(sequence[shopIndex - 1]))
    end

    ev.sequence = sequence
end)

-- Spawn one Red, one Black, and one Purple chest at the start of the first Boss Rush floor.
event.levelLoad.add("apBossRushChests", { order = "entities", sequence = 1 }, function()
    if currentLevel.getMode().id ~= "APBossRush" then return end
    if currentLevel.getSequentialNumber() ~= 1 then return end

    local loadout = { AP_bossRushChest = { loadout = true } }

    object.spawn("ChestRed", -2, 2, loadout)
    object.spawn("ChestBlack", 0, 2, loadout)
    object.spawn("ChestPurple", 2, 2, loadout)
end)

local function isLoadoutChest(entity)
    return entity.AP_bossRushChest ~= nil and entity.AP_bossRushChest.loadout
end

--  The three chests that open a Boss Rush are a loadout, not a choice.
event.objectDeath.override("despawnOtherFlawlessChests", function(func, ev)
    if currentLevel.getMode().id ~= "APBossRush" then return func(ev) end
    if not currentLevel.isBoss() then return end
    if isLoadoutChest(ev.entity) then return end

    for entity in ecs.entitiesWithComponents({ "chestXMLMapping" }) do
        if not isLoadoutChest(entity) then object.delete(entity) end
    end
end)

local function isStoryBossLevel(index)
    local entry = index and levelSequence.get(index)

    -- The midpoint shop sits between two fights, so the food looks past it.
    if entry and entry.type == apBossRushShop.GENERATOR_TYPE then
        entry = levelSequence.get(index + 1)
    end

    local data = entry and entry.boss and boss.Type.data[entry.boss]

    return data ~= nil and data.story == true
end

event.bossFightEnd.add("apBossRushFood", { order = "flawlessChests", sequence = 1 }, function()
    if currentLevel.getMode().id ~= "APBossRush" then return end
    if not isStoryBossLevel(currentLevel.getSequentialNumber() + 1) then return end

    local stairsX, stairsY = marker.lookUpFirst(marker.Type.STAIRS)
    if not stairsX then return end

    object.spawn("Food2", stairsX, stairsY + 2)
end)
