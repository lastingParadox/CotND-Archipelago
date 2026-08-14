local commonItem = require "necro.game.data.item.CommonItem"

local apUtils = require("AP.scripts.utils.apUtils")

-- Shapes Amplified skips (throwable/reloadable). Matched on components, not
-- ev.flags, so generated variants like the Trident's are covered.
local MATERIAL_SHAPES = {
    Dagger = true,
    Spear = true,
    Crossbow = true,
    Trident = true,
}

-- No Titanium or Obsidian entities exist for these, so the base weapon stands in.
local BASE_SHAPES = {
    Blunderbuss = true,
    Rifle = true,
}

local function shapeShortName(entity)
    local weaponType = entity.weaponType
    local name = weaponType and weaponType.name
    -- Modded shapes are namespaced, e.g. Sync_Trident.
    return name and name:match("[^_]*$") or nil
end

local function makeUncertain(ev)
    local uncertain = commonItem.variant(ev, "Uncertain")

    uncertain.contentsSprite = { name = ev.entity.name }
    uncertain.itemGenerationKey = { name = ev.entity.name }
    uncertain.sprite = {
        texture = "ext/items/weapon_uncertainty.png",
        width = 24,
        height = 25,
    }
    uncertain.positionalSprite = { offsetX = 0, offsetY = 0 }
    uncertain.itemUnlockable = ev.entity.itemUnlockable
    uncertain.itemPoolUncertainty = {}
    uncertain.AP_editorCategory = {}
    uncertain.itemPickupFlyaway = false
    uncertain.itemHintLabel = nil
    uncertain.itemHolderGrooveChainSprite = nil
    uncertain.AP_uncertainWeapon = {}
    uncertain.weaponReloadableAmmoSprite = false
    uncertain.normalAnimation = false
    uncertain.spriteSheetReset = false
    uncertain.itemSpriteChangeOnCombo = false
    uncertain.itemSpriteChangeOnConditionalDamage = false
    uncertain.itemStackSprite = false
    uncertain.itemSpriteHUD = false
    uncertain.itemSpriteOffsetHUD = false
    uncertain.itemOverlaySpriteHUD = false

    return uncertain
end

-- 0.5: after Amplified claims its variants, before DynChar sweeps ev.entities.
event.entitySchemaLoadItem.add("apUncertainWeapons", { order = "uncertainty", sequence = 0.5 }, function(ev)
    local entity = ev.entity

    if ev.data and ev.data._removed then return end
    if not entity.weapon then return end
    -- Already has one from Amplified; a second would overwrite it.
    if ev.variants and ev.variants.Uncertain then return end

    local shape = shapeShortName(entity)
    if not shape then return end

    local isMaterial = entity.weaponMaterialTitanium or entity.weaponMaterialObsidian
    local isBase = entity.weaponMaterialBase

    if (MATERIAL_SHAPES[shape] and isMaterial) or (BASE_SHAPES[shape] and isBase) then
        makeUncertain(ev)
    end
end)

event.itemGenerate.add("apHideUncertainWeapons", { order = "initParameters", sequence = 3 }, function(ev)
    if ev.itemPool ~= "itemPoolUncertainty" then return end
    if apUtils.isAPContext() then return end

    local originalFilter = ev.filter
    ev.filter = function(item, args, player)
        if item.AP_uncertainWeapon then return false end
        return originalFilter(item, args, player)
    end
end)
