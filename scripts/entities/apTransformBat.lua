local action = require("necro.game.system.Action")
local commonSpell = require("necro.game.data.spell.CommonSpell")
local commonWeapon = require("necro.game.data.item.weapon.CommonWeapon")
local customEntities = require "necro.game.data.CustomEntities"
local ecs = require "system.game.Entities"
local enemy = require("necro.game.data.enemy.CommonEnemy")
local itemBan = require("necro.game.item.ItemBan")
local move = require("necro.game.system.Move")
local playableCharacters = require("necro.game.data.player.PlayableCharacters")
local utils = require("system.utils.Utilities")

customEntities.extend {
    name = "BatFormBase",
    template = customEntities.template.player(),
    modifier = function(entity)
        playableCharacters.floating(entity)
    end,
    components = {
        editorHidden = {},
        DynChar_dynamicCharacter = false,
        playableCharacter = false,
        itemUser = false,
        itemSlotUser = {
            slots = {
                hud = true,
                spell = true
            }
        },
        inventoryCheckForDropsOnDeath = {},
        actionFilter = {
            ignoreActions = {
                [action.Special.THROW] = true,
                [action.Special.BOMB] = true,
                [action.Special.ITEM_1] = true,
                [action.Special.ITEM_2] = true,
                [action.Direction.UP_RIGHT] = true,
                [action.Direction.UP_LEFT] = true,
                [action.Direction.DOWN_LEFT] = true,
                [action.Direction.DOWN_RIGHT] = true
            }
        },
        inventoryCursedSlots = {
            slots = {
                action = true,
                hud = true
            },
            banFlags = itemBan.Flag.ACTIVATE
        },
        innateWeapon = {},
        weapon = {
            damage = 4
        },
        weaponCheckOriginCollision = {},
        weaponPattern = {
            pattern = commonWeapon.daggerPattern
        },
        forceObjectVision = {
            component = "visibleByTelepathy"
        },
        forceNonSilhouetteVision = {
            component = "visibleByTelepathy"
        },
        minimapVision = {
            component = "visibleByTelepathy"
        },
        spawnApparitions = {
            component = "visibleByTelepathy"
        },
        incrementRegenerationKillCounter = {
            increment = 2
        },
        hudHideSlots = {
            hidden = {
                [action.Special.THROW] = true
            }
        },
        hudRegenerationKillCounter = {},
        regenerationKillCounter = {
            totalIncrement = 2
        },
        hudPlayerListUseAttachmentSprite = false,
        characterEquipmentSpriteRow = false,
        castOnLethalHit = false,
        grooveChainFailImmunity = {},

        transformableBloodCost = {
            damage = 1,
            killerName = "Blood Magic (Transform)"
        },
        sprite = {
            texture = "mods/AP/gfx/entities/bat_form.png",
            height = 27,
            width = 25
        }
    },
}

event.entitySchemaGenerate.add("apCreateBatForms", { order = "customEntities", sequence = 100 }, function(ev)
    local batBasic
    for _, entity in ipairs(ev.entityTypes) do
        if entity.name == "AP_BatFormBase" then
            batBasic = entity
            break
        end
    end

    if not batBasic then
        error("No bat form base detected!")
        return
    end

    local batForms = {}
    local batHeads = {}

    -- Index bat forms by original character name
    local batFormByCharacter = {}

    for _, entity in ipairs(ev.entityTypes) do
        -- === Character → Bat form ===
        if entity.playableCharacter
            and entity.characterWithAttachment
            and not entity.transformable
        then
            local batForm = utils.mergeTablesRecursive(
                utils.mergeTablesRecursive(
                    utils.fastCopy(entity),
                    utils.fastCopy(batBasic)
                ),
                {
                    name = "AP_" .. entity.name .. "Bat",
                    friendlyName = {
                        name = entity.friendlyName and entity.friendlyName.name or entity.name
                    },
                    editorName = {
                        name = (entity.friendlyName and entity.friendlyName.name or entity.name) .. " (Bat Form)"
                    },
                    characterWithAttachment = {
                        attachmentType = entity.characterWithAttachment.attachmentType
                    },
                    transformable = { targetType = entity.name },
                    playableCharacter = false,
                    voiceSpellCasterPrefix = entity.voiceSpellCasterPrefix or false,

                },
                2
            )

            batForms[#batForms + 1] = batForm
            batFormByCharacter[entity.name] = batForm

            entity.transformable = {
                targetType = batForm.name
            }

            -- === Head attachment → Bat head ===
        elseif entity.attachment
            and entity.CharacterSkins_skinnable
            and entity.CharacterSkins_skinnable.imageType == "head"
            and entity.name ~= "AP_BatFormBaseHead"
            and entity.name ~= "NocturnaHead"
        then
            local batHeadName = "AP_" .. entity.name .. "BatHead"

            local batHead = utils.mergeTablesRecursive(
                utils.fastCopy(entity),
                {
                    name = batHeadName,
                    visibilityAlwaysHidden = {},
                },
                2
            )

            batHeads[#batHeads + 1] = batHead

            -- Patch the corresponding bat form if it exists
            local characterName = entity.name:gsub("Head$", "")
            local batForm = batFormByCharacter[characterName]

            if batForm and batForm.characterWithAttachment then
                batForm.characterWithAttachment.attachmentType = batHeadName
            end
        end
    end

    utils.appendToTable(ev.entityTypes, batForms)
    utils.appendToTable(ev.entityTypes, batHeads)
end)
