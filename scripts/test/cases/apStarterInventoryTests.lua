local apInventory  = require("AP.scripts.utils.apInventory")
local apStorage    = require("AP.scripts.client.storage")
local apTest       = require("AP.scripts.test.apTest")
local progression  = require("AP.scripts.client.progression")

-- No "Weapon" segment, so the composite-item resolver cannot claim it, and no live slot
-- can have received it; only the unique-starter rule can allow it.
local FIXTURE   = "APUniqueStarterFixture"
local CHARACTER = { name = "Mary" }

local UNLOCK_MODES = { "item_only", "required_items_soft", "required_items_hard" }

local function withUnlocks(mode, includeUnique, body)
    apTest.withSaveData({
        characterUnlocks = mode,
        includeUniqueItems = includeUnique,
        characterRequirements = { Mary = { normal = {}, unique = { FIXTURE } } },
        nextRunItems = {},
    }, body)
end

apTest.define({
    name = "characterUnlocksIsAlwaysAStringMode",
    run = function(t)
        for _, mode in ipairs(UNLOCK_MODES) do
            withUnlocks(mode, true, function()
                -- A numeric comparison against this can never match, however it is written.
                t.eq(type(progression.getCharacterUnlocks()), "string")
                t.eq(progression.getCharacterUnlocks(), mode)
            end)
        end

        withUnlocks(nil, true, function()
            t.eq(progression.getCharacterUnlocks(), "item_only", "the default mode changed")
        end)
    end,
})

apTest.define({
    name = "itemOnlyHandsCharactersTheirUniqueGear",
    run = function(t)
        withUnlocks("item_only", true, function()
            t.ok(apInventory.isAllowedItem(CHARACTER, FIXTURE, progression),
                "item_only should not gate a character's own unique gear")
        end)
    end,
})

apTest.define({
    name = "requiredItemModesGateUniqueGear",
    run = function(t)
        for _, mode in ipairs({ "required_items_soft", "required_items_hard" }) do
            withUnlocks(mode, true, function()
                t.ok(not apInventory.isAllowedItem(CHARACTER, FIXTURE, progression),
                    ("%s should gate unique gear on receiving it"):format(mode))
            end)
        end
    end,
})

apTest.define({
    name = "uniqueGearOutsideThePoolIsAlwaysGranted",
    run = function(t)
        for _, mode in ipairs(UNLOCK_MODES) do
            withUnlocks(mode, false, function()
                t.ok(apInventory.isAllowedItem(CHARACTER, FIXTURE, progression),
                    ("%s should grant unique gear that is not in the item pool"):format(mode))
            end)
        end
    end,
})
