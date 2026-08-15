local ecs = require "system.game.Entities"
local inventory = require "necro.game.item.Inventory"
local hasDynChar, _ = pcall(require, "DynChar.DynCharSchema")
local itemPickup = require("necro.game.item.ItemPickup")
local itemSlot = require "necro.game.item.ItemSlot"
local settingsStorage = require "necro.config.SettingsStorage"
local utils = require "system.utils.Utilities"

-- Purchasable diamonds, huh.
event.entitySchemaLoadNamedEntity.add("changeDiamonds", { key = "ResourceDiamond" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

event.entitySchemaLoadNamedEntity.add("changeDiamonds2", { key = "ResourceDiamond2" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

event.entitySchemaLoadNamedEntity.add("changeDiamonds3", { key = "ResourceDiamond3" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

event.entitySchemaLoadNamedEntity.add("changeDiamonds4", { key = "ResourceDiamond4" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

event.entitySchemaLoadNamedEntity.add("apTriggerTravelPrimaryOnlyComponents", { key = "TriggerTravelPrimaryOnly" },
    function(ev)
        ev.entity.AP_trapUnlock = {}
    end)

event.entitySchemaLoadNamedEntity.add("apTriggerTravelComponents", { key = "TriggerTravel" }, function(ev)
    ev.entity.AP_trapUnlock = {}
end)

event.entitySchemaLoadNamedEntity.add("apTriggerOpenMenuComponents", { key = "TriggerOpenMenu" }, function(ev)
    ev.entity.AP_trapUnlock = {}
end)

-- Items
local function addAPItemComponents(entity)
    entity.AP_hintLabel = {}
    entity.AP_player = {}
    entity.AP_itemClass = {}
    entity.AP_itemShowcase = {}
    entity.AP_preview = {}
    entity.AP_shopItem = {}
    entity.AP_locationItem = {}
end

event.entitySchemaLoadItem.add("addAPComponents", { order = "common", sequence = 1 }, function(ev)
    addAPItemComponents(ev.entity)
end)

-- TODO: See why Trident isn't getting these components
event.entitySchemaLoadEntity.add("apTridentComponents", { order = "overrides", sequence = 1 }, function(ev)
    if ev.entity.name == "Sync_WeaponTrident" then
        addAPItemComponents(ev.entity)
    end
end)

-- Every cageable lobby NPC, mapped to its AP item/location name. An empty name
-- means cageable but not randomised, which is what separates these from the five
-- the apworld actually ships as items.
local npcNames = {
    Beastmaster   = "",
    Hephaestus    = "",
    Medic         = "",
    Weaponmaster  = "",
    AP_Hintmaster = "Hintmaster",
    Diamonddealer = "Diamond Dealer",
    Janitor       = "Janitor",
    Merlin        = "Merlin",
    Trainer       = "Codex",
}

local chestKinds = {
    ChestRed = "Red",
    ChestPurple = "Purple",
    ChestBlack = "Black",
}

local chestUpgrades = {
    AddchestRed   = { chest = "ChestRed",    chanceType = "redChest",    order = 1 },
    AddchestWhite = { chest = "ChestPurple", chanceType = "purpleChest", order = 2 },
    AddchestBlack = { chest = "ChestBlack",  chanceType = "blackChest",  order = 3 },
}

event.entitySchemaLoadEntity.add("apChestSchema", { order = "overrides", sequence = 2 }, function(ev)
    local e = ev.entity

    local kind = chestKinds[e.name]
    if kind then
        e.AP_chestKind = { kind = kind }
    end

    local upgrade = chestUpgrades[e.name]
    if upgrade then
        e.AP_chestUpgrade = upgrade
    end
end)

-- Characters
event.entitySchemaLoadEntity.add("apMonster", { order = "overrides", sequence = 3 }, function(ev)
    local e = ev.entity

    if (e.character) then
        e.scaleEffect = e.scaleEffect or {}
        e.stun = e.stun or {}
    end
end)

-- NPCs
event.entitySchemaLoadEntity.add("apLobbyNPC", { order = "overrides", sequence = 2 }, function(ev)
    local e = ev.entity
    local apName = npcNames[e.name]

    if apName then
        e.AP_npcUnlockable = {}
        e.AP_npc = { apName = apName }
    end
end)

-- Add item pricing and collection schemas for playableCharacters
event.entitySchemaLoadEntity.add("playerAPItem", { order = "overrides", sequence = 1 }, function(ev)
    local e = ev.entity

    if (e.playableCharacter or e.enemyPoolNPC) then
        e.sale = { ["priceTag"] = {} }

        e.AP_itemShowcase = {}
        e.AP_shopItem = {}
        e.itemHintLabel = {}
        e.AP_player = {}
        e.AP_preview = {}
        e.AP_itemClass = {}
        e.AP_flyaway = {}
        e.itemSlot = { name = "misc" }
        e.inventoryCursedSlots = e.inventoryCursedSlots or {}
        e.AP_damageCountdown = {}
        e.AP_followerChain = {}

        e.rotatedSprite = e.rotatedSprite or {}

        if e.name ~= "Coldsteel_Coldsteel" then
            e.AP_spellResonanceMode = { type = "kills" }
        else
            local spellRechargeSetting = settingsStorage.get("mod.Coldsteel.coldsteelSpell.spellRechargeMode") or 2
            local mode = "combo"
            if spellRechargeSetting == 2 then mode = "combo" else mode = "kills" end
            e.AP_spellResonanceMode = { type = mode }
        end
    end
end)

-- Entity name to sprite, since the two no longer share a spelling.
local dynCharItems = {
    ArmorPlatemailDorian     = "armor_platemail_dorian",
    Sync_ArmorPlatemailShiny = "armor_platemail_klarinetta",
    Coldsteel_ArmorVirtual   = "armor_virtual_coldsteel",
}

event.entitySchemaLoadItem.add("apUniqueDynChar", { order = "overrides" },
    function(ev)
        if not hasDynChar then return end

        local sprite = dynCharItems[ev.entity.name]

        if sprite then
            ev.entity.DynChar_dynamicItem = {
                texture = "mods/AP/gfx/armors/" .. sprite .. ".png",
                framesX = 4,
            }
        end
    end)

local excludeCharacters = {
    Eli = true,
    Goldman_Goldman = true,
    Sync_Chaunter = true,
}

event.entitySchemaLoadNamedEntity.add("apKlarinettaUnbanZweihander", {
    key = "Sync_Klarinetta",
}, function(ev)
    ev.entity.inventoryUnbannedItems = {
        components = {
            Sync_weaponCollisionCheck  = true,
            AP_klarinettaWeaponScroll  = true,
        },
    }
end)

event.entitySchemaLoadNamedEntity.add("apScrollEnchantWeaponKlarinetta", {
    key = "ScrollEnchantWeapon",
}, function(ev)
    ev.entity.AP_klarinettaWeaponScroll = {}
end)

event.entitySchemaLoadPlayer.add("apDynamicCharacterExcludedItems", { order = "overrides", sequence = 2 }, function(ev)
    if not hasDynChar then return end
    ev.entity.DynChar_dynamicCharacter.excludedItems = ev.entity.DynChar_dynamicCharacter.excludedItems or {}

    if excludeCharacters[ev.entity.name] then
        ev.entity.DynChar_dynamicCharacter.excludedItems["ArmorPlatemailDorian"] = true
        ev.entity.DynChar_dynamicCharacter.excludedItems["Sync_ArmorPlatemailShiny"] = true
        ev.entity.DynChar_dynamicCharacter.excludedItems["Coldsteel_ArmorVirtual"] = true
    elseif ev.entity.name == "Coldsteel_Coldsteel" then
        ev.entity.DynChar_dynamicCharacter.excludedItems["Coldsteel_ArmorVirtual"] = true
    elseif ev.entity.name == "Sync_Klarinetta" then
        ev.entity.DynChar_dynamicCharacter.excludedItems["Sync_ArmorPlatemailShiny"] = true
    end
end)

-- Shovel Blade

event.inventoryEquipItem.add("APShovelBladePickUp", { order = "equip" }, function(ev)
    if ev.item.name == "Goldman_ShovelPogo" then
        inventory.dropSlot(ev.holder, itemSlot.Type.WEAPON)
    end
end)

event.inventoryEquipItem.add("APDropShovelBlade", { order = "equip" }, function(ev)
    local slotName = ev.item and ev.item.itemSlot and ev.item.itemSlot.name
    if slotName ~= "weapon" or not ev.holder then
        return
    end

    local items = inventory.getItems(ev.holder)
    for _, item in ipairs(items) do
        if item.name == "Goldman_ShovelPogo" then
            inventory.drop(item, ev.holder.position.x, ev.holder.position.y)
            goto continue
        end
    end

    ::continue::
end)

local uniqueItemsList = {
    ArmorPlatemailDorian = {
        coinCost = 150,
        chestChance = { 0, 0, 1, 30 },
        shopChance = { 0, 0, 10, 75 },
        diamondDealable = 4
    },
    Sync_ArmorPlatemailShiny = {
        coinCost = 150,
        chestChance = { 0, 0, 1, 30 },
        shopChance = { 0, 0, 10, 75 },
        diamondDealable = 4
    },
    Coldsteel_ArmorVirtual = {
        coinCost = 150,
        chestChance = { 0, 0, 1, 30 },
        shopChance = { 0, 0, 10, 75 },
        diamondDealable = 4
    },
    Goldman_ShovelPogo = {
        coinCost = 100,
        chestChance = { 0, 0, 1, 20 },
        shopChance = { 0, 0, 5, 50 },
        diamondDealable = 3
    },
    WeaponGoldenLute = {
        coinCost = 75,
        chestChance = { 0, 5, 25, 10 },
        shopChance = { 40, 30, 20, 0 },
        diamondDealable = 2,
        bans = { "itemBanWeaponlocked" }
    },
    WeaponEli = {
        coinCost = 40,
        chestChance = { 5, 1, 1, 0 },
        shopChance = { 10, 5, 1, 0 },
        diamondDealable = 1
    },
    WeaponFlower = {
        coinCost = 40,
        chestChance = { 7, 2, 1, 0 },
        shopChance = { 12, 7, 2, 1 },
        diamondDealable = 1
    },
    Sync_WeaponLantern = {
        coinCost = 75,
        chestChance = { 20, 10, 0 },
        shopChance = { 50, 10, 0 },
    },
    Sync_WeaponLance = {
        coinCost = 75,
        chestChance = { 20, 10, 0 },
        shopChance = { 50, 10, 0 },
    },
    Coldsteel_WeaponLeek = {
        coinCost = 75,
        chestChance = { 20, 10, 0 },
        shopChance = { 50, 10, 0 },
    },
    SpellTransform = {
        coinCost = 75,
        chestChance = { 5 },
        shopChance = { 3 },
    },
}

local poollessItemsList = {
    Sync_SpellCharm = {
        chestChance = { 3, 2, 1 },
        shopChance = { 5, 3, 1 },
    },
    FeetBootsLunging = {
        chestChance = { 3, 2, 1 },
        shopChance = { 5, 3, 1 }
    },
    RingPhasing = {
        chestChance = { 4 },
        shopChance = { 10 },
    },
}

event.entitySchemaLoadItem.add("apPoollessItemGeneration", { order = "overrides", sequence = 2 }, function(ev)
    local e = ev.entity
    local data = poollessItemsList[e.name]
    if not data then return end

    if data.chestChance then
        e.AP_itemPoolChest = { weights = data.chestChance }
        e.itemPoolSecret = { weights = data.chestChance }
    end

    if data.shopChance then
        e.AP_itemPoolShop = { weights = data.shopChance }
        e.AP_itemPoolLockedShop = { weights = data.shopChance }
    end
end)

-- Adding Unique Items to AP Generation

event.entitySchemaLoadItem.add("apUniqueItemGeneration", { order = "overrides", sequence = 2 }, function(ev)
    local e = ev.entity

    if uniqueItemsList[e.name] then
        local data = uniqueItemsList[e.name]

        if data.coinCost then
            e.itemPrice = {
                coins = data.coinCost,
                blood = utils.lowerBound({ 24, 119, 400 }, data.coinCost)
            }
        end

        if data.diamondDealable then
            e.itemDiamondDealable = { diamonds = data.diamondDealable }
        end

        if data.chestChance then
            e.AP_itemPoolChest = { weights = data.chestChance }
            e.itemPoolSecret = { weights = data.chestChance }

            -- itemSlot is a plain table at schema load, so it never equals a string.
            if (e.itemArmor or e.itemArmorLater) and e.itemSlot and e.itemSlot.name == "head" then
                e.AP_itemPoolRedChest = { weights = data.chestChance }
            elseif e.weapon or e.itemArmor or e.itemArmorLater then
                e.AP_itemPoolBlackChest = { weights = data.chestChance }
            elseif e.spellCast then
                e.AP_itemPoolPurpleChest = { weights = data.chestChance }
            end
        end

        if data.shopChance then
            e.AP_itemPoolShop = { weights = data.shopChance }
            e.AP_itemPoolLockedShop = { weights = data.shopChance }
        end

        -- Character banlists key off ban components; unique items that skip the
        -- normal type components (see WeaponGoldenLute) need them added back so
        -- restricted characters exclude them from AP generation.
        if data.bans then
            for _, banComponent in ipairs(data.bans) do
                e[banComponent] = e[banComponent] or {}
            end
        end
    end
end)

-- Marv

event.entitySchemaLoadNamedEntity.add("apMarv", { order = "overrides", sequence = 1, key = "Marv" }, function (ev)
    ev.entity.inventory = {}
    ev.entity.itemUser = {}
    ev.entity.itemCollector = {}
    ev.entity.AP_followerChain = {}

    ev.entity.AP_followerDamageParentWhileDead = {}
    -- Declares the deathlink-source name tag so death.lua can set it and
    -- apRenderMarvDeathLinkTags can draw it above the Marv.
    ev.entity.AP_marvDeathLinkTag = {}
end)

-- Miku Resonance Spell

event.entitySchemaLoadNamedEntity.add("apSpellcastResonance", { order = "overrides", sequence = 2, key = "Coldsteel_SpellResonance"}, function (ev)
    ev.entity.Coldsteel_spellCooldownStack = {
        cooldown = 7,
        remainingKills = 7,
    }
    ev.entity.Coldsteel_spellCooldownCombo = {
        cooldown = 4,
        text = "%s combo",
    }

end)

event.holderKill.override("Coldsteel_reduceSpellCooldown", function (func, ev)
    if ev.holder.AP_spellResonanceMode and ev.holder.AP_spellResonanceMode.type == "combo" then return
    else return func(ev) end
end)

event.spellItemCooldown.override("Coldsteel_stack", function (func, ev)
    local holder = ecs.getEntityByID(ev.entity.item and ev.entity.item.holder)
    if holder and holder.AP_spellResonanceMode and holder.AP_spellResonanceMode.type == "combo" then return
    else return func(ev) end
end)

event.spellItemCooldown.override("Coldsteel_visual", function (func, ev)
    local holder = ecs.getEntityByID(ev.entity.item and ev.entity.item.holder)
    if holder and holder.AP_spellResonanceMode and holder.AP_spellResonanceMode.type == "kills" then return
    else return func(ev) end
end)
