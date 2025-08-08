local apUtils = require("AP.scripts.ap_handlers.APUtils")

local function mergeTables(...)
    local result = {}
    for _, tbl in ipairs({ ... }) do
        for k, v in pairs(tbl) do
            result[k] = v
        end
    end
    return result
end

local shopLocationRange = { 742080, 742182 }

apItems = {}

apItems.baseItemsList = {
    ["ArmorLeather"] = true,
    ["ArmorChainmail"] = true,
    ["ArmorPlatemail"] = true,
    ["ArmorHeavyplate"] = true,
    ["ArmorObsidian"] = true,
    ["ArmorGlass"] = true,
    ["ArmorGi"] = true,
    ["HeadMinersCap"] = true,
    ["HeadMonocle"] = true,
    ["HeadCircletTelepathy"] = true,
    ["HeadHelm"] = true,
    ["HeadCrownOfThorns"] = true,
    ["HeadCrownOfTeleportation"] = true,
    ["HeadGlassJaw"] = true,
    ["HeadBlastHelm"] = true,
    ["HeadSunglasses"] = true,
    ["FeetBalletShoes"] = true,
    ["FeetBootsWinged"] = true,
    ["FeetBootsExplorers"] = true,
    ["FeetBootsLead"] = true,
    ["FeetGreaves"] = true,
    ["FeetBootsStrength"] = true,
    ["FeetBootsPain"] = true,
    ["FeetBootsLeaping"] = true,
    ["FeetBootsLunging"] = true,
    ["Torch1"] = true,
    ["Torch2"] = true,
    ["Torch3"] = true,
    ["TorchObsidian"] = true,
    ["TorchGlass"] = true,
    ["TorchInfernal"] = true,
    ["TorchForesight"] = true,
    ["ShovelTitanium"] = true,
    ["ShovelCrystal"] = true,
    ["ShovelObsidian"] = true,
    ["ShovelGlass"] = true,
    ["ShovelBlood"] = true,
    ["Pickaxe"] = true,
    ["RingCharisma"] = true,
    ["RingGold"] = true,
    ["RingLuck"] = true,
    ["RingMana"] = true,
    ["RingMight"] = true,
    ["RingProtection"] = true,
    ["RingRegeneration"] = true,
    ["RingShielfing"] = true,
    ["RingWar"] = true,
    ["RingCourage"] = true,
    ["RingPeace"] = true,
    ["RingShadows"] = true,
    ["RingBecoming"] = true,
    ["RingPhasing"] = true,
    ["WeaponDaggerJeweled"] = true,
    ["WeaponDaggerPhasing"] = true,
    ["WeaponDaggerFrost"] = true,
    ["WeaponBroadsword"] = true,
    ["WeaponLongsword"] = true,
    ["WeaponSpear"] = true,
    ["WeaponBow"] = true,
    ["WeaponWhip"] = true,
    ["WeaponRapier"] = true,
    ["WeaponCat"] = true,
    ["WeaponCrossbow"] = true,
    ["WeaponBlunderbuss"] = true,
    ["WeaponRifle"] = true,
    ["SpellFireball"] = true,
    ["SpellFreezeEnemies"] = true,
    ["SpellHeal"] = true,
    ["SpellBomb"] = true,
    ["SpellShield"] = true,
    ["SpellTransmute"] = true,
    ["ScrollFireball"] = true,
    ["ScrollFreezeEnemies"] = true,
    ["ScrollShield"] = true,
    ["ScrollTransmute"] = true,
    ["ScrollEarthquake"] = true,
    ["ScrollEnchantWeapon"] = true,
    ["ScrollFear"] = true,
    ["ScrollNeed"] = true,
    ["ScrollRiches"] = true,
    ["Food1"] = true,
    ["FoodMagic1"] = true,
    ["Food2"] = true,
    ["FoodMagic2"] = true,
    ["Food3"] = true,
    ["FoodMagic3"] = true,
    ["Food4"] = true,
    ["FoodMagic4"] = true,
    ["CharmStrength"] = true,
    ["CharmRisk"] = true,
    ["CharmProtection"] = true,
    ["CharmNazar"] = true,
    ["CharmGluttony"] = true,
    ["CharmFrost"] = true,
    ["MiscHeartContainer"] = true,
    ["MiscHeartContainer2"] = true,
    ["MiscHeartContainerEmpty"] = true,
    ["MiscHeartContainerEmpty2"] = true,
    ["Holster"] = true,
    ["HudBackpack"] = true,
    ["BagHolding"] = true,
    ["BloodDrum"] = true,
    ["HeartTransplant"] = true,
    ["HolyWater"] = true,
    ["CursedPotion"] = true,
    ["MiscMap"] = true,
    ["MiscCompass"] = true,
    ["MiscCoupon"] = true,
}

apItems.amplifiedItemsList = {
    ["ArmorHeavyglass"] = true,
    ["ArmorQuartz"] = true,
    ["HeadSpikedEars"] = true,
    ["FeetGlassSlippers"] = true,
    ["TorchWalls"] = true,
    ["TorchStrength"] = true,
    ["ShovelCourage"] = true,
    ["ShovelStrength"] = true,
    ["ShovelBattle"] = true,
    ["RingFrost"] = true,
    ["RingPiercing"] = true,
    ["RingPain"] = true,
    ["WeaponDaggerElectric"] = true,
    ["WeaponStaff"] = true,
    ["WeaponHarp"] = true,
    ["WeaponWarhammer"] = true,
    ["WeaponCutlass"] = true,
    ["WeaponAxe"] = true,
    ["SpellEarth"] = true,
    ["SpellPulse"] = true,
    ["ScrollPulse"] = true,
    ["TomeFireball"] = true,
    ["TomeFreeze"] = true,
    ["TomeShield"] = true,
    ["TomeTransmute"] = true,
    ["TomePulse"] = true,
    ["TomeEarth"] = true,
    ["FoodCarrot"] = true,
    ["FoodMagicCarrot"] = true,
    ["FoodCookies"] = true,
    ["FoodMagicCookies"] = true,
    ["CharmBomb"] = true,
    ["CharmGrenade"] = true,
    ["MiscHeartContainerCursed"] = true,
    ["MiscHeartContainerCursed2"] = true,
    ["FamiliarDove"] = true,
    ["FamiliarIceSpirit"] = true,
    ["FamiliarShopkeeper"] = true,
    ["FamiliarRat"] = true,
    ["WarDrum"] = true,
    ["ThrowingStars"] = true,
    ["MiscMonkeyPaw"] = true,
}

apItems.synchronyItemsList = {
    ["Sync_WeaponTrident"] = true,
    ["Sync_ShieldWooden"] = true,
    ["Sync_ShieldTitanium"] = true,
    ["Sync_ShieldHeavy"] = true,
    ["Sync_ShieldObsidian"] = true,
    ["Sync_ShieldStrength"] = true,
    ["Sync_ShieldReflective"] = true,
    ["Sync_SpellBerzerk"] = true,
    ["Sync_SpellDash"] = true,
    ["Sync_SpellCharm"] = true,
    ["Sync_ScrollBerzerk"] = true,
    ["Sync_CharmThrowing"] = true,
}

apItems.apItemsList = {
    ["APInstantGold"] = true,
    ["APInstantGold2"] = true,
    ["APDiamond1"] = true,
    ["APDiamond2"] = true,
    ["APDiamond3"] = true,
    ["APDiamond4"] = true,
    ["APFullHeal"] = true,
    ["APNoReturnMode"] = true,
    ["APHardMode"] = true,
    ["APPhasingMode"] = true,
    ["APRandomizerMode"] = true,
    ["APMysteryMode"] = true,
    ["APNoBeatMode"] = true,
    ["APDoubleTempoMode"] = true,
    ["APLowPercentMode"] = true,
}

apItems.allItemsList = mergeTables(apItems.baseItemsList, apItems.amplifiedItemsList, apItems.synchronyItemsList)

apItems.isCurrencyItem = function(item)
    return string.find(item, "Diamond") or string.find(item, "Gold")
end

apItems.isOwnShopItem = function(item, slotName)
    return item.playername == slotName and item.location_code and
        tonumber(item.location_code) >= shopLocationRange[1] and tonumber(item.location_code) <= shopLocationRange[2]
end

apItems.getPriceForItem = function(pricingObj, locationCode, classification, seed)
    if not pricingObj or not pricingObj.type then
        return 1
    end

    -- Create a unique key by combining locationCode and seed
    local key = tostring(locationCode) .. "|" .. tostring(seed)

    -- Simple deterministic hash function
    local function hash(str)
        local h = 0
        for i = 1, #str do
            h = (h * 31 + str:byte(i)) % 2 ^ 31
        end
        return h
    end

    local min, max = 1, 1

    local type = pricingObj.type
    if type == apUtils.PriceRandomizationType.VANILLA or type == apUtils.PriceRandomizationType.ITEM_CLASS then
        local ranges = {
            [0] = { pricingObj.filler.min, pricingObj.filler.max },
            [1] = { pricingObj.progression.min, pricingObj.progression.max },
            [2] = { pricingObj.useful.min, pricingObj.useful.max },
        }

        min, max = ranges[classification][1], ranges[classification][2]
    else
        min, max = pricingObj.general.min, pricingObj.general.max
    end

    local hashed = hash(key)
    local price = min + (hashed % (max - min + 1))
    return price
end

return apItems
