local extraMode                 = require "necro.game.data.modifier.ExtraMode"

local apExtraModeConfiguration  = require("AP.scripts.entities.apExtraModeConfiguration")
local apStorage                 = require("AP.scripts.client.storage")
local apTest                    = require("AP.scripts.test.apTest")
local apUtils                   = require("AP.scripts.utils.apUtils")
local progression               = require("AP.scripts.client.progression")

local SUPPORTED = apExtraModeConfiguration.SUPPORTED_MODES

apTest.define({
    name = "supportedExtraModeIdsStillResolve",
    run = function(t)
        for modeID, name in pairs(SUPPORTED) do
            local data = extraMode.Type.data[modeID]

            if t.ok(data, ("extra mode id %d no longer exists"):format(modeID)) then
                t.ok(data.i18n or data.displayName,
                    ("extra mode id %d resolves to something unnamed, so %s may be the wrong id")
                        :format(modeID, name))
            end
        end
    end,
})

apTest.define({
    name = "ensembleIsNotAnAPManagedMode",
    run = function(t)
        -- The mode whose initial-item exclusions ate Mary's cookies in an AP run.
        t.eq(SUPPORTED[extraMode.Type.ENSEMBLE], nil,
            "Ensemble is now listed as AP-managed; this fixture needs rethinking")
    end,
})

apTest.define({
    name = "unmanagedExtraModesReadAsLocked",
    run = function(t)
        apTest.withSaveData({ extraModes = { ["Hard"] = true } }, function()
            -- getExtraModes with no name returns the whole table, so a missing id must not reach it.
            t.eq(type(progression.getExtraModes()), "table")
            t.eq(progression.getExtraModes("Hard"), true)
            t.eq(progression.getExtraModes("Ensemble"), nil)
        end)
    end,
})

apTest.define({
    name = "noUnmanagedExtraModeIsActiveInAnAPRun",
    level = true,
    run = function(t)
        if not apUtils.isAPContext() then return end

        for _, mode in ipairs(extraMode.listAvailableModes()) do
            if extraMode.isActive(mode) then
                t.ok(SUPPORTED[mode],
                    ("%s is active but is not an AP-managed extra mode")
                        :format(tostring(extraMode.Type.data[mode].displayName or mode)))
            end
        end
    end,
})
