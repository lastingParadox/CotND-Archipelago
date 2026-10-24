local ecs          = require "system.game.Entities"

local apCharacters = require("AP.scripts.utils.apCharacters")
local apGrants     = require("AP.scripts.items.apGrants")
local apStorage    = require("AP.scripts.client.storage")
local apTest       = require("AP.scripts.test.apTest")

-- Chaunter's possession points the player at an enemy, which carries no character sheet.
local POSSESSED_SHELL = "Slime"

apTest.define({
    name = "everyCharacterSheetDeclaresAHealthLimit",
    run = function(t)
        local characters = ecs.getEntityTypesWithComponents({ "playableCharacter" })
        t.ok(characters[1], "no playable characters registered")

        for _, character in ipairs(characters) do
            t.hasComponent(character, "healthLimit")
        end
    end,
})

apTest.define({
    name = "possessedShellHasNoHealthLimit",
    run = function(t)
        if not ecs.isValidEntityType(POSSESSED_SHELL) then return end

        t.ok(not ecs.typeHasComponent(POSSESSED_SHELL, "healthLimit"),
            "the possession fixture now has a healthLimit, so it no longer tests the guard")
    end,
})

apTest.define({
    name = "setAPHealthIgnoresAPossessedShell",
    run = function(t)
        if not ecs.isValidEntityType(POSSESSED_SHELL) then return end

        local ok, err = pcall(apCharacters.setAPHealth, { name = POSSESSED_SHELL })
        t.ok(ok, "setAPHealth threw without a healthLimit to read: " .. tostring(err))
    end,
})

apTest.define({
    name = "permanentHealthUpgradeSurvivesAPossessedShell",
    run = function(t)
        local rule = apGrants.resolve("PermHeart2")
        if not t.ok(rule, "PermHeart2 resolves to no grant rule") then return end

        local ok, err, banked

        apTest.withSaveData({ health = 0 }, function()
            ok, err = pcall(rule.apply, nil, nil, { players = { { name = POSSESSED_SHELL } } })
            banked = apStorage.saveData.health
        end)

        t.ok(ok, "the grant threw without a healthLimit to read: " .. tostring(err))
        t.eq(banked, 2, "the upgrade should still bank even when no body can take it")
    end,
})
