local boss              = require "necro.game.level.Boss"
local currentLevel      = require "necro.game.level.CurrentLevel"
local enum              = require "system.utils.Enum"
local proceduralRun     = require "necro.game.data.level.ProceduralRun"
local segment           = require "necro.game.tile.Segment"

local apLevelGeneration = require("AP.scripts.level.apLevelGeneration")
local apTest            = require("AP.scripts.test.apTest")
local apUtils           = require("AP.scripts.utils.apUtils")
local progression       = require("AP.scripts.client.progression")

apTest.define({
    name = "onlyFortissimoleIsGatedOnAmplified",
    run = function(t)
        local amplified = progression.isDLCEnabled("Amplified")

        t.eq(apLevelGeneration.isBossExcluded(boss.Type.FORTISSIMOLE), not amplified,
            "Fortissimole's exclusion no longer tracks the slot's Amplified setting")

        for bossID in enum.dataPairs(boss.Type) do
            if bossID ~= boss.Type.FORTISSIMOLE then
                t.ok(not apLevelGeneration.isBossExcluded(bossID),
                    ("boss %s is excluded but is not an Amplified boss"):format(tostring(bossID)))
            end
        end
    end,
})

apTest.define({
    name = "bossPoolCanAlwaysReplaceAnAmplifiedBoss",
    run = function(t)
        local pool = proceduralRun.getBossPool()
        t.ok(pool and pool[1], "the procedural boss pool is empty")

        local replacement = false
        for _, bossID in ipairs(pool or {}) do
            replacement = replacement or not apLevelGeneration.isBossExcluded(bossID)
        end

        t.ok(replacement, "no substitutable boss in the pool: an Amplified boss would survive")
    end,
})

apTest.define({
    name = "floorHasNoExcludedBoss",
    level = true,
    run = function(t)
        if not apUtils.isAPContext() then return end

        local bossType = currentLevel.getBossType()
        if not bossType or bossType == 0 then return end

        t.ok(not apLevelGeneration.isBossExcluded(bossType),
            ("%s is an excluded boss but generated anyway"):format(tostring(bossType)))
    end,
})

apTest.define({
    name = "floorZoneRespectsAmplified",
    level = true,
    run = function(t)
        if not apUtils.isAPContext() or progression.isDLCEnabled("Amplified") then return end

        t.ok(currentLevel.getZone() <= 4,
            ("generated zone %s with Amplified disabled"):format(tostring(currentLevel.getZone())))
    end,
})

apTest.define({
    name = "floorSegmentHasArea",
    level = true,
    run = function(t)
        local _, _, width, height = segment.getBounds(segment.MAIN)

        t.ok(type(width) == "number" and width > 0, "the main segment has no width")
        t.ok(type(height) == "number" and height > 0, "the main segment has no height")
    end,
})
