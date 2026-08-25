local ability = require "necro.game.system.Ability"
local action = require "necro.game.system.Action"
local collision = require "necro.game.tile.Collision"
local customWeapons = require "necro.game.data.item.weapon.CustomWeapons"
local ecs = require "system.game.Entities"
local facing = require "necro.game.character.Facing"
local inventory = require "necro.game.item.Inventory"
local itemBan = require "necro.game.item.ItemBan"
local itemSlot = require "necro.game.item.ItemSlot"
local materialColorFilter = require "necro.render.filter.MaterialColorFilter"
local render = require "necro.render.Render"
local settingsStorage = require "necro.config.SettingsStorage"
local utils = require "system.utils.Utilities"

event.entitySchemaLoadNamedEntity.add("apZweihanderShapeBase", {
    order    = "overrides",
    sequence = 1,
    key      = "Sync_WeaponReallyBigSword",
}, function(ev)
    ev.entity.itemTransmutable          = {}
    ev.entity.AP_weaponTypeZweihander   = {}
    ev.entity.weaponType     = { name = "AP_Zweihander", component = "AP_weaponTypeZweihander" }
    ev.entity.weaponMaterial = { name = "Base", component = "weaponMaterialBase" }
    ev.entity.weaponMaterialBase = {}
    ev.entity.spriteSheet    = {}
    ev.entity.itemPrice      = { coins = 15, blood = 24 }
    ev.entity.AP_itemPoolChest = { weights = { 10, 25, 5, 0 } }
    ev.entity.AP_itemPoolShop  = { weights = { 0, 5, 10, 20 } }
    ev.entity.itemGlobalBan  = { banFlags = itemBan.Type.FULL }
end)

local ZWEIHANDER_CONTROL_COMPONENTS = {
    [1] = { Sync_deployedItemRotatableSausage = {} },
    [2] = { Sync_deployedItemRotatableSausage = { ignoreDiagonals = true } },
    [3] = { Sync_deployedItemRotatableSausage = {} },
    [4] = { Sync_deployedItemRotatableDrod = {
        mapping = {
            [action.Special.ITEM_2] = action.Rotation.CCW_90,
            [action.Special.THROW]  = action.Rotation.CW_90,
        },
    } },
    [5] = { Sync_deployedItemRotatableDrod = {
        mapping = {
            [action.Special.ITEM_2] = action.Rotation.CCW_45,
            [action.Special.THROW]  = action.Rotation.CW_45,
        },
    } },
    [6] = {
        facingDirection            = { direction = action.Direction.DOWN_RIGHT },
        Sync_deployedItemRotatable = { direction = action.Direction.DOWN_RIGHT },
        Sync_deployedItem          = { dx = 1, dy = 1 },
        Sync_deployedItemRotatableAbsolute = {
            directions = {
                [action.Direction.UP_LEFT]    = true,
                [action.Direction.UP_RIGHT]   = true,
                [action.Direction.DOWN_RIGHT] = true,
                [action.Direction.DOWN_LEFT]  = true,
            },
        },
    },
}

local MATERIAL_PRICES = {
    ["Glass"]    = { coins = 40,  blood = 24 },
    ["Blood"]    = { coins = 40,  blood = 24 },
    ["Frost"]    = { coins = 60,  blood = 24 },
    ["Titanium"] = { coins = 75,  blood = 24 },
    ["Gold"]     = { coins = 90,  blood = 24 },
    ["Phasing"]  = { coins = 90,  blood = 24 },
    ["Electric"] = { coins = 90,  blood = 24 },
    ["Obsidian"] = { coins = 120, blood = 24 },
    ["Jeweled"]  = { coins = 120, blood = 24 },
}

-- Mirrors Sync_WeaponReallyBigSword's deployed-sword behaviour; both shapes below are
-- that weapon in a different material.
local DEPLOYED_SWORD_COMPONENTS = {
    weapon        = { damage = 1 },
    weaponPattern = { pattern = { tiles = {} } },
    team          = {},
    DynChar_dynamicItem   = false,
    facingDirection       = {},
    positionalSprite      = { offsetX = -2, offsetY = -2 },
    minimapStaticPixel    = false,
    Sync_deployedItemAttachment = {
        width = 30, height = 30,
        offsetX = 26, offsetY = 22, offsetZ = 32,
        absOffsetX = math.sqrt(2) / 2 - 1.05,
        frameCount = 1, rotate = true,
        angleOffset = math.pi * 3 / 4,
    },
    Sync_deployedItemAttachmentHover    = { offset = 5.9 + math.sqrt(2) / 2, amplitude = -1 },
    Sync_deployedItemInvisibleWhileHeld = {},
    itemTangibleWhileEquipped           = {},
    itemRequireTangibleHolder           = {},
    itemEquipmentCollision              = { remove = collision.Type.ITEM },
    Sync_deployedItem                   = {},
    Sync_deployedItemFollowHolder       = {},
    Sync_deployedItemCopyHolderTeam     = {},
    Sync_weaponCollisionCheck           = {},
    collision = { mask = collision.mask(collision.Type.FAMILIAR, collision.Type.ITEM) },
    Sync_deployedItemIdleCollision      = { add = collision.Type.ORB, remove = collision.Type.FAMILIAR },
    castOnCollision                     = { spell = "Sync_DelayedClaymoreAttack" },
    Sync_deployedItemAttackDeferred     = {},
    Sync_deployedItemAttackTargetCounter = {},
    Sync_deployedItemRotatable          = {},
    Sync_deployedItemAttackOnMove       = {},
    Sync_deployedItemAttackOnMoveFail   = {
        pattern = { tiles = { { offset = {1, 0}, swipe = "dagger" } } },
    },
    Sync_deployedItemAttackOnRotate     = {},
    itemGlobalBan                       = { banFlags = itemBan.Type.FULL },
}

local function swordComponents(extra)
    return utils.mergeTablesRecursive(utils.deepCopy(DEPLOYED_SWORD_COMPONENTS), extra or {})
end

local function applyControlScheme(entity)
    local controlVal = settingsStorage.get("mod.Sync.zweihaender.zweihaender.control") or 6
    local comps = ZWEIHANDER_CONTROL_COMPONENTS[controlVal]
    if comps then
        utils.mergeTablesRecursive(entity, comps)
    end
end

customWeapons.registerShape {
    name         = "Zweihander",
    friendlyName = "Zweihänder",
    hint         = "Sweeping attack, heavy",
    texture      = "mods/AP/gfx/items/weapons/weapon_zweihander.png",
    -- Sync_WeaponReallyBigSword is the Base member, stamped above.
    excludeMaterials = { "Base" },
    components   = swordComponents {
        AP_itemPoolChest = { weights = { 10, 25, 5, 0 } },
        AP_itemPoolShop  = { weights = { 0, 5, 10, 20 } },
        itemPrice        = { coins = 90, blood = 24 },
        itemTransmutable = {},
        spriteSheet      = {}, -- needed by groove chain sprite palette-frame shifts
    },
    modifier = function(ev)
        local matName = ev.material and ev.material.shortName or ""

        ev.entity.sprite.width  = 30
        ev.entity.sprite.height = 30
        ev.entity.AP_itemPoolEnchant = { weights = { 1 } }

        if matName == "Glass" then
            ev.entity.consumableCreateDroppedItem = { itemType = "AP_WeaponGlassZweihanderShard" }
        end

        ev.entity.itemPrice = MATERIAL_PRICES[matName] or { coins = 90, blood = 24 }
        ev.entity.itemUnlockable = false

        applyControlScheme(ev.entity)
    end,
}

customWeapons.registerShape {
    name             = "GlassZweihanderShard",
    friendlyName     = "Glass Zweihänder Shard",
    hint             = "Sweeping attack, fragile",
    texture          = "mods/AP/gfx/items/weapons/weapon_zweihander_shard.png",
    includeMaterials = { "Base" },
    components       = swordComponents(),
    modifier = function(ev)
        local glassMat = customWeapons.getMaterialData("Glass")
        if glassMat then
            ev.entity.sprite.texture = customWeapons.getTexture(
                { texture = "mods/AP/gfx/items/weapons/weapon_zweihander_shard.png" },
                glassMat
            )
        end
        ev.entity.sprite.width   = 30
        ev.entity.sprite.height  = 30
        ev.entity.itemUnlockable = false

        applyControlScheme(ev.entity)
    end,
}

-- Sync_weaponCollisionCheck is carried only by the Zweihaender family, so it needs no
-- accompanying name test.
event.inventoryEquipItem.add("APZweihanderPickUp", { order = "equip" }, function(ev)
    if ev.item.Sync_weaponCollisionCheck and ev.holder.name ~= "Sync_Klarinetta" then
        ev.holder.inputContextLayerDiagonal       = {}
        ev.holder.inventoryVirtualControlsHintHUD = {}
        ev.holder.actionRemap                     = {}
    end
end)

local DIAGONAL_ACTION_MAP = {
    [action.Special.ITEM_1]  = action.Direction.UP_LEFT,
    [action.Special.BOMB]    = action.Direction.DOWN_LEFT,
    [action.Special.SPELL_1] = action.Direction.UP_RIGHT,
    [action.Special.SPELL_2] = action.Direction.DOWN_RIGHT,
}

event.objectCheckAbility.add("APZweihanderActionFilter", { order = "actionFilter" }, function(ev)
    local weapon = inventory.getItemInSlot(ev.entity, itemSlot.Type.WEAPON)
    if not (weapon and weapon.Sync_weaponCollisionCheck
            and weapon.Sync_deployedItemRotatableAbsolute
            and not ev.entity.inputContextLayerDiagonal) then return end

    if ev.action == action.Special.THROW or ev.action == action.Special.ITEM_2 then
        ev.flags = ability.Flag.mask(ev.flags, ability.Flag.IGNORE_ACTION)
        ev.action = action.Special.IDLE
    end
end)

event.objectSpecialAction.add("APZweihanderDiagonalRotate", { order = "tween" }, function(ev)
    if ev.result ~= nil then return end
    local dir = DIAGONAL_ACTION_MAP[ev.action]
    if not dir then return end
    local weapon = inventory.getItemInSlot(ev.entity, itemSlot.Type.WEAPON)
    if not (weapon and weapon.Sync_weaponCollisionCheck
            and weapon.Sync_deployedItemRotatableAbsolute
            and not ev.entity.inputContextLayerDiagonal) then return end
    facing.setDirection(weapon, dir)
    ev.result = action.Result.ATTACK
end)

local OBSIDIAN_GLOW_TEX = {}

local function getObsidianGlowTex(level)
    if OBSIDIAN_GLOW_TEX[level] then return OBSIDIAN_GLOW_TEX[level] end

    local obsMat = customWeapons.getMaterialData("Obsidian")
    if not (obsMat and obsMat.palette and obsMat.palette[level]) then return nil end

    local src = obsMat.palette[level]
    local args = { image = "mods/AP/gfx/items/weapons/weapon_zweihander.png" }
    for k, v in pairs(src) do
        args[k] = v
    end

    local tex = materialColorFilter.getPath(args)
    OBSIDIAN_GLOW_TEX[level] = tex
    return tex
end

local DIR_ANGLES = {
    [action.Direction.RIGHT]      = 0,
    [action.Direction.DOWN_RIGHT] = math.pi * 0.25,
    [action.Direction.DOWN]       = math.pi * 0.5,
    [action.Direction.DOWN_LEFT]  = math.pi * 0.75,
    [action.Direction.LEFT]       = math.pi,
    [action.Direction.UP_LEFT]    = math.pi * 1.25,
    [action.Direction.UP]         = math.pi * 1.5,
    [action.Direction.UP_RIGHT]   = math.pi * 1.75,
}

event.render.add("apObsidianZweihanderGlow", { order = "objects", sequence = 3 }, function()
    local buffer = render.getBuffer(render.Buffer.ATTACHMENT)
    for entity in ecs.entitiesWithComponents {
        "Sync_deployedItemAttachment",
        "itemHolderGrooveChainSprite",
        "spriteSheet",
    } do
        if not (entity.name and entity.name:find("ObsidianZweihander", 1, true)) then goto continue end
        local glowFrame = entity.spriteSheet.frameX
        if not glowFrame or glowFrame <= 1 then goto continue end

        local holder = ecs.getEntityByID(entity.item.holder)
        if not (holder and holder.sprite and holder.sprite.visible
                and (not holder.visibility or holder.visibility.visible)) then
            goto continue
        end

        local tex = getObsidianGlowTex(glowFrame)
        if not tex then goto continue end

        local attach    = entity.Sync_deployedItemAttachment
        local angle     = DIR_ANGLES[entity.facingDirection.direction] or 0
        local dx, dy    = math.cos(angle), math.sin(angle)
        local pSprite   = holder.positionalSprite or { offsetX = 0, offsetY = 0 }
        local shadowPos = holder.shadowPosition or holder.sprite
        local w, h      = 30, 30

        buffer.draw {
            texture = tex,
            rect    = {
                holder.sprite.x - pSprite.offsetX + dx * attach.offsetX + attach.absOffsetX * (holder.sprite.mirrorX or 1),
                holder.sprite.y - pSprite.offsetY + dy * attach.offsetY + (attach.absOffsetY or 0),
                w, h,
            },
            texRect = { 0, 0, w, h },
            z       = attach.offsetZ + shadowPos.y + (holder.rowOrder and holder.rowOrder.z or 0) + dy + 0.1,
            color   = holder.sprite.color,
            angle   = attach.rotate and angle + attach.angleOffset,
            origin  = { 12, 12 },
        }

        ::continue::
    end
end)
