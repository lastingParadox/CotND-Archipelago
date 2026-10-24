local ecs     = require "system.game.Entities"
local itemBan = require "necro.game.item.ItemBan"

local apTest  = require("AP.scripts.test.apTest")

local PICKUP = itemBan.Flag.PICKUP

apTest.define({
    name = "goldenLuteIsTakeableByEveryCharacter",
    run = function(t)
        local characters = ecs.getEntityTypesWithComponents({ "playableCharacter" })
        t.ok(characters[1], "no playable characters registered")

        for _, character in ipairs(characters) do
            t.unbanned(character, "WeaponGoldenLute", PICKUP)
        end
    end,
})

apTest.define({
    name = "everyCharacterCarriesTheUnbanComponent",
    run = function(t)
        for _, character in ipairs(ecs.getEntityTypesWithComponents({ "playableCharacter" })) do
            t.hasComponent(character, "AP_unbannedItems")
        end
    end,
})

apTest.define({
    name = "zweihanderIsKlarinettaOnly",
    run = function(t)
        t.hasComponent("Sync_WeaponReallyBigSword", "Sync_weaponCollisionCheck")
        t.unbanned("Sync_Klarinetta", "Sync_WeaponReallyBigSword", PICKUP)
        t.banned("Cadence", "Sync_WeaponReallyBigSword", PICKUP)
    end,
})

apTest.define({
    name = "klarinettaTakesEnchantWeaponScroll",
    run = function(t)
        t.hasComponent("ScrollEnchantWeapon", "AP_klarinettaWeaponScroll")
        t.unbanned("Sync_Klarinetta", "ScrollEnchantWeapon", PICKUP)
    end,
})
