local boss = require("necro.game.level.Boss")
local currentLevel = require("necro.game.level.CurrentLevel")
local enum = require("system.utils.Enum")
local gameSession = require "necro.client.GameSession"
local object = require("necro.game.object.Object")

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

event.levelSequenceUpdate.add("apBossRushSequence", { order = "bossRush" }, function(ev)
    if ev.mode.id ~= "APBossRush" then return end

    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4

    local newSeq = {}
    for _, entry in ipairs(ev.sequence) do
        if entry.boss and entry.boss ~= boss.Type.NONE and entry.zone <= lastZone then
            table.insert(newSeq, entry)
        end
    end
    ev.sequence = newSeq
end)

-- Spawn one Red, one Black, and one Purple chest at the start of the first Boss Rush floor.
-- Boss rooms are placed with their tile generator origin at world (0,0).
-- The antechamber runs from y=-3 to y=3; chests at y=2 put them in front of the player's spawn.
event.levelLoad.add("apBossRushChests", { order = "entities", sequence = 1 }, function()
    if currentLevel.getMode().id ~= "APBossRush" then return end
    if currentLevel.getSequentialNumber() ~= 1 then return end

    object.spawn("ChestRed", -2, 2)
    object.spawn("ChestBlack", 0, 2)
    object.spawn("ChestPurple", 2, 2)
end)
