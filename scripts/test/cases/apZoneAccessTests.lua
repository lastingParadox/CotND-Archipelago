local apStorage   = require("AP.scripts.client.storage")
local apTest      = require("AP.scripts.test.apTest")
local progression = require("AP.scripts.client.progression")

local ZONES = { 1, 2, 3, 4, 5 }

local withSaveData = apTest.withSaveData

apTest.define({
    name = "progressiveZoneAccessOpensCountPlusOne",
    run = function(t)
        withSaveData({ zoneAccessKeys = "progressive", startingZone = 1, zoneAccess = {} }, function()
            for count = 0, 6 do
                apStorage.saveData.zoneAccess = { progressiveCount = count }

                local expected = math.min(count + 1, #ZONES)
                t.eq(#progression.getAccessibleZones(ZONES), expected,
                    ("progressiveCount %d should open %d zones"):format(count, expected))
            end
        end)
    end,
})

apTest.define({
    name = "startingZoneIsNotAddedOnTopOfTheCount",
    run = function(t)
        -- The apworld precollects startingZone - 1 copies, so they are already in the count.
        for startingZone = 1, #ZONES do
            withSaveData({
                zoneAccessKeys = "progressive",
                startingZone = startingZone,
                zoneAccess = { progressiveCount = startingZone - 1 },
            }, function()
                t.eq(#progression.getAccessibleZones(ZONES), startingZone,
                    ("a fresh slot starting in zone %d should open exactly %d zones")
                        :format(startingZone, startingZone))
            end)
        end
    end,
})

apTest.define({
    name = "nothingIncrementsTheProgressiveCount",
    run = function(t)
        -- Reading a missing module member raises, so its absence shows up as a failed read.
        local exists = pcall(function() return progression.addProgressiveZoneAccess end)
        t.ok(not exists, "Python recomputes progressiveCount absolutely; a relative increment double-counts")
    end,
})

apTest.define({
    name = "separateZoneAccessOpensTheStartingZoneAndItsKeys",
    run = function(t)
        withSaveData({
            zoneAccessKeys = "separate",
            startingZone = 2,
            zoneAccess = { ["4"] = true },
        }, function()
            local accessible = progression.getAccessibleZones(ZONES)

            t.eq(#accessible, 2, "the starting zone and one key should open two zones")
            t.eq(accessible[1], 2)
            t.eq(accessible[2], 4)
        end)
    end,
})

apTest.define({
    name = "disabledZoneAccessOpensEverything",
    run = function(t)
        withSaveData({ zoneAccessKeys = "disabled" }, function()
            t.eq(#progression.getAccessibleZones(ZONES), #ZONES)
        end)
    end,
})
