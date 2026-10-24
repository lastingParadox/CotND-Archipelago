local apStorage  = require("AP.scripts.client.storage")
local apTest     = require("AP.scripts.test.apTest")
local apVersion  = require("AP.scripts.utils.version")
local saveUpdate = require("AP.scripts.client.handlers.saveUpdate")

local FIELD_MAP = saveUpdate.FIELD_MAP

-- The two fields saveUpdate keeps mod-owned; a rename here silently un-protects them.
local MOD_OWNED_KEYS = { "diamonds", "received_items" }

apTest.define({
    name = "fieldMapKeysAreSnakeAndValuesAreCamel",
    run = function(t)
        for snakeKey, camelKey in pairs(FIELD_MAP) do
            t.ok(snakeKey:match("^[a-z][a-z0-9_]*$"),
                ("'%s' is not a snake_case key"):format(tostring(snakeKey)))
            t.ok(type(camelKey) == "string" and not camelKey:find("_", 1, true),
                ("'%s' maps to '%s', which is not camelCase"):format(tostring(snakeKey), tostring(camelKey)))
        end
    end,
})

apTest.define({
    name = "fieldMapHasNoAliasedFields",
    run = function(t)
        local owners = {}

        for snakeKey, camelKey in pairs(FIELD_MAP) do
            t.eq(owners[camelKey], nil,
                ("'%s' and '%s' both map to '%s'"):format(
                    tostring(owners[camelKey]), snakeKey, tostring(camelKey)))
            owners[camelKey] = snakeKey
        end
    end,
})

apTest.define({
    name = "fieldMapStillCarriesTheModOwnedFields",
    run = function(t)
        for _, snakeKey in ipairs(MOD_OWNED_KEYS) do
            t.ne(FIELD_MAP[snakeKey], nil,
                ("MOD_OWNED names '%s', which FIELD_MAP no longer has"):format(snakeKey))
        end
    end,
})

apTest.define({
    name = "ensureSaveDataTablesKeepsExistingData",
    run = function(t)
        apTest.withSaveData({ receivedItems = { [1] = "marker" }, diamonds = 42 }, function()
            apStorage.ensureSaveDataTables()

            t.eq(apStorage.saveData.receivedItems[1], "marker", "an existing table was replaced")
            t.eq(apStorage.saveData.diamonds, 42, "a non-table field was clobbered")
            t.eq(type(apStorage.saveData.characterLocations), "table", "a missing table was not filled in")
        end)
    end,
})

apTest.define({
    name = "versionComparisonOrdersReleases",
    run = function(t)
        t.eq(apVersion.compare("1.0.0", "1.0.0"), 0)
        t.eq(apVersion.compare("1.2.0", "1.10.0"), -1)
        t.eq(apVersion.compare("2.0", "1.9.9"), 1)
        t.eq(apVersion.compare("1.0", "1.0.0"), 0)
    end,
})

apTest.define({
    name = "apworldCompatibilityUsesAMinimum",
    run = function(t)
        t.ok(apVersion.isApworldCompatible(apVersion.MIN_APWORLD_VERSION),
            "the declared minimum apworld version is rejected")
        t.ok(not apVersion.isApworldCompatible(""), "an empty version was accepted")
        t.ok(not apVersion.isApworldCompatible(nil), "a nil version was accepted")
        t.ok(not apVersion.isApworldCompatible("0.0.1"), "an ancient version was accepted")
    end,
})
