local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"
local inventory = require("necro.game.item.Inventory")
local itemBan = require "necro.game.item.ItemBan"
local itemSlot = require "necro.game.item.ItemSlot"
local object = require("necro.game.object.Object")

local apCharacters = require("AP.scripts.utils.apCharacters")
local characterBuffs = require("AP.scripts.character.buffs.init")

local apInventory = {}

local function anyHeldItem(entity, predicate)
    if not entity or not predicate then return nil end

    for _, heldItem in ipairs(inventory.getItems(entity)) do
        if predicate(heldItem) then
            return heldItem
        end
    end

    return nil
end

local function hasItemByName(entity, itemType)
    return anyHeldItem(entity, function(heldItem)
        return heldItem.name == itemType
    end) ~= nil
end

local function getCharacterUniqueItems(entity)
    if not entity then return nil end
    return apCharacters.uniqueItemRequirements[entity.name]
end

local function getCharacterInnateItems(entity)
    if not entity then return nil end
    return apCharacters.innateStarterItems and apCharacters.innateStarterItems[entity.name]
end

local function isInItemList(itemType, list)
    if not itemType or not list then return false end

    for _, entry in ipairs(list) do
        if entry == itemType then
            return true
        end
    end

    return false
end

local function shouldGrantUniqueStarterItems(progression)
    if not progression then return false end

    if not progression.getIncludeUniqueItems() then
        return true
    end

    return progression.getCharacterUnlocks() == 0
end

local function isUniqueStarterAllowed(entity, itemType, progression)
    if not shouldGrantUniqueStarterItems(progression) then return false end
    if not entity or not itemType then return false end

    local uniqueItems = getCharacterUniqueItems(entity)
    if not uniqueItems then return false end

    return isInItemList(itemType, uniqueItems)
end

local function isInnateStarterAllowed(entity, itemType)
    return isInItemList(itemType, getCharacterInnateItems(entity))
end

local function isAlwaysAllowedHeldItem(itemEntity)
    if not itemEntity then return false end

    -- Bomb inventory can be represented by different bomb item entity names.
    -- Preserve the entire bomb slot in lobby sanitization.
    if itemEntity.itemSlot and (itemEntity.itemSlot.name == "bomb" or itemEntity.itemSlot.name == "bombs") then
        return true
    end

    if itemEntity.name and itemEntity.name:match("^Bomb") then
        return true
    end

    return false
end

local function isBombItemType(itemType)
    return itemType and itemType:match("^Bomb") ~= nil
end

local function getDesiredStarterBySlot(entity, slotName)
    if not entity or not entity.initialInventory or not entity.initialInventory.items then return nil end

    for _, itemType in ipairs(entity.initialInventory.items) do
        if ecs.typeHasComponent(itemType, "item") then
            local proto = ecs.getEntityPrototype(itemType)
            local protoSlot = proto and proto.itemSlot and proto.itemSlot.name

            if protoSlot == slotName then
                return itemType
            end
        end
    end

    return nil
end

local function getDesiredBombStarter(entity, progression)
    if not entity or not entity.initialInventory or not entity.initialInventory.items then return nil end

    for _, itemType in ipairs(entity.initialInventory.items) do
        if isBombItemType(itemType)
            and apInventory.isAllowedItem(entity, itemType, progression)
            and ecs.typeHasComponent(itemType, "item")
        then
            return itemType
        end
    end

    return nil
end

local function getCurrentBombItemName(entity)
    local bombItem = anyHeldItem(entity, function(item)
        return item.itemSlot and (item.itemSlot.name == "bomb" or item.itemSlot.name == "bombs")
    end)

    return bombItem and bombItem.name or nil
end

local function getCurrentItemNameBySlot(entity, slotName)
    local slotItem = anyHeldItem(entity, function(item)
        return item.itemSlot and item.itemSlot.name == slotName
    end)

    return slotItem and slotItem.name or nil
end

function apInventory.isAllowedItem(entity, itemType, progression)
    return progression.getItems(itemType)
        -- Diamond Dealer purchases count as starting inventory until a run
        -- consumes them, so lobby sanitization must not delete them.
        or progression.getNextRunItems(itemType)
        or isUniqueStarterAllowed(entity, itemType, progression)
        or isInnateStarterAllowed(entity, itemType)
end

-- Equips every Diamond Dealer nextRunItem this character can use. Called last in
-- applyStarterInventory (and on purchase) so a bought weapon/armor overrides the
-- character's default starter. Items the character can't pick up are skipped.
function apInventory.equipNextRunItems(entity, progression)
    if not entity then return end
    for itemType in pairs(progression.getNextRunItems()) do
        if ecs.typeHasComponent(itemType, "item")
            and not itemBan.isBanned(entity, itemType, itemBan.Flag.PICKUP) then
            inventory.replaceIfUncursed(itemType, entity)
        end
    end
end

function apInventory.grantItem(entity, itemType)
    if not entity or not itemType then return end
    if hasItemByName(entity, itemType) then return end

    local item = object.spawn(itemType, entity.position.x, entity.position.y, {
        gameObject = {
            tangible = false
        },
        itemInitial = {
            active = true
        }
    })

    inventory.fireAddEvent({
        item = item,
        holder = entity
    })
end

function apInventory.grantAllowedInitialItems(entity, progression)
    if not entity or not entity.initialInventory or not entity.initialInventory.items then return end

    for _, itemType in ipairs(entity.initialInventory.items) do
        if apInventory.isAllowedItem(entity, itemType, progression) and ecs.typeHasComponent(itemType, "item") then
            apInventory.grantItem(entity, itemType)
        end
    end
end

local function grantAllInitialItems(entity)
    if not entity or not entity.initialInventory or not entity.initialInventory.items then return end

    for _, itemType in ipairs(entity.initialInventory.items) do
        if ecs.typeHasComponent(itemType, "item") then
            apInventory.grantItem(entity, itemType)
        end
    end
end

local function grantAllUniqueStarterItems(entity)
    if not entity then return end

    local uniqueItems = getCharacterUniqueItems(entity)
    if not uniqueItems then return end

    for _, itemType in ipairs(uniqueItems) do
        if ecs.typeHasComponent(itemType, "item") then
            apInventory.grantItem(entity, itemType)
        end
    end
end

function apInventory.grantMissingUniqueStarterItems(entity, progression)
    if not shouldGrantUniqueStarterItems(progression) then return end
    if not entity then return end

    local uniqueItems = getCharacterUniqueItems(entity)
    if not uniqueItems then return end

    for _, itemType in ipairs(uniqueItems) do
        if ecs.typeHasComponent(itemType, "item") then
            apInventory.grantItem(entity, itemType)
        end
    end
end

function apInventory.grantMissingInnateStarterItems(entity)
    if not entity then return end

    local innateItems = getCharacterInnateItems(entity)
    if not innateItems then return end

    for _, itemType in ipairs(innateItems) do
        if ecs.typeHasComponent(itemType, "item") then
            apInventory.grantItem(entity, itemType)
        end
    end
end

-- Vanilla lobby upgrades AP hands out as permanent innate items, e.g. the coin
-- multipliers. The chest upgrades are excluded by the innate slot: they set a run
-- flag rather than being carried.
function apInventory.grantAPInnateItems(entity, progression)
    if not (entity and progression) then return end

    for _, proto in ecs.prototypesWithComponents({ "itemLobbyProgressionUnlock", "itemSlot" }) do
        if proto.itemSlot.name == "innate" and progression.getItems(proto.name) then
            apInventory.grantItem(entity, proto.name)
        end
    end
end

function apInventory.sanitizeLobbyInventory(entity, progression)
    if not entity then return end

    for _, item in ipairs(inventory.getItems(entity)) do
        if not isAlwaysAllowedHeldItem(item) and not apInventory.isAllowedItem(entity, item.name, progression) then
            object.delete(item)
        end
    end
end

function apInventory.ensureWeapon(entity, progression)
    if not entity then return end

    local desiredWeapon = getDesiredStarterBySlot(entity, "weapon")
    local currentWeapon = getCurrentItemNameBySlot(entity, "weapon")

    -- Characters without a starter weapon (e.g. Shovel Knight) should stay weaponless.
    if not desiredWeapon then return end

    if currentWeapon == desiredWeapon then return end

    if progression and apInventory.isAllowedItem(entity, desiredWeapon, progression) then
        inventory.replaceIfUncursed(desiredWeapon, entity)
    elseif currentWeapon ~= "WeaponDagger" then
        -- Fallback only when a starter weapon exists but is unavailable/removed.
        inventory.replaceIfUncursed("WeaponDagger", entity)
    end
end

function apInventory.ensureShovel(entity)
    if not entity then return end
    if entity.name == "Coldsteel_Coldsteel" then return end

    if #inventory.getItemsInSlot(entity, itemSlot.Type.SHOVEL) == 0 then
        inventory.add(object.spawn("ShovelBasic", entity.position.x, entity.position.y), entity)
    end
end

function apInventory.ensureBombStarter(entity, progression)
    if not entity then return end

    local desiredBomb = getDesiredBombStarter(entity, progression)
    if not desiredBomb then return end

    local currentBomb = getCurrentBombItemName(entity)
    if currentBomb == desiredBomb then return end

    inventory.replaceIfUncursed(desiredBomb, entity)
end

function apInventory.ensureFamiliarStarter(entity)
    if not entity then return end

    local desiredFamiliar = getDesiredStarterBySlot(entity, "familiar")
    if not desiredFamiliar then return end

    local currentFamiliar = getCurrentItemNameBySlot(entity, "familiar")
    if currentFamiliar == desiredFamiliar then return end

    inventory.replaceIfUncursed(desiredFamiliar, entity)
end

function apInventory.applyStarterInventory(entity, progression, options)
    if not entity then return end

    if options and options.sanitize then
        apInventory.sanitizeLobbyInventory(entity, progression)
    end

    local isSoftUnlocks = progression and progression.getCharacterUnlocks() == 1

    if isSoftUnlocks then
        -- Soft mode: starting inventory is gated on received AP items.
        apInventory.grantMissingUniqueStarterItems(entity, progression)
        apInventory.grantMissingInnateStarterItems(entity)
        apInventory.grantAPInnateItems(entity, progression)
        apInventory.ensureBombStarter(entity, progression)
        apInventory.ensureFamiliarStarter(entity)
        apInventory.ensureWeapon(entity, progression)
    else
        -- Item only / Hard mode: full default starting inventory, no gating.
        grantAllInitialItems(entity)
        grantAllUniqueStarterItems(entity)
        apInventory.grantMissingInnateStarterItems(entity)
        apInventory.grantAPInnateItems(entity, progression)
    end

    apInventory.ensureShovel(entity)

    -- Klarinetta's weapon slot is cursed, so the vanilla Sync_WeaponReallyBigSword
    -- from initialInventory cannot be removed or replaced via normal inventory APIs.
    -- Convert it in-place to the AP variant; object.convert preserves the deployed
    -- entity's world state (dx, dy, direction, holder reference, etc.).
    if entity.name == "Sync_Klarinetta" then
        local weapon = inventory.getItemInSlot(entity, itemSlot.Type.WEAPON)
        if weapon and weapon.name == "Sync_WeaponReallyBigSword" then
            object.convert(weapon, "AP_WeaponZweihander")
            object.processPendingConversions()
        end
    end

    -- In the lobby, Diamond Dealer purchases are part of the starting inventory
    -- until a run consumes them; equip them last so they win over the default
    -- starters. In a run this is skipped: grantNextRunItems grants and consumes.
    if currentLevel.isLobby() then
        apInventory.equipNextRunItems(entity, progression)
    end

    -- Apply any character-specific buff that is active in the buff room.
    characterBuffs.apply(entity, progression)
end

return apInventory
