local components = require "necro.game.data.Components"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require("system.game.Entities")
local extraMode = require "necro.game.data.modifier.ExtraMode"
local flyaway = require "necro.game.system.Flyaway"
local focus = require "necro.game.character.Focus"
local lobbyEffects = require "necro.render.level.LobbyEffects"
local sound = require "necro.audio.Sound"
local trapClientTrigger = require "necro.game.trap.TrapClientTrigger"

local apPreview = require("AP.scripts.utils.apPreview")

local apClient = require("AP.scripts.client.client")
local progression = require("AP.scripts.client.progression")

local hasPendingRunStart = false

event.entitySchemaLoadNamedEntity.add("shrineOfConfigurationAP", { key = "ShrineOfConfiguration" }, function(ev)
    ev.entity.AP_interactable = { ["ap"] = false, ["active"] = false }
    ev.entity.AP_interactableExtraModeLobby = {}
    ev.entity.AP_preview = {}
end)

local function errorNotification(entity, text, positionEntity)
    if not hasPendingRunStart and text then
        if focus.check(entity, focus.Flag.FLYAWAY) then
            flyaway.create({
                offsetY = -7,
                entity = positionEntity or entity,
                text = text
            })
        end

        if focus.check(entity, focus.Flag.SOUND_PLAYBACK) then
            sound.playFromEntity("error", positionEntity or entity, {
                deduplicationID = entity.id,
                port = sound.Port.PERSONAL
            })
        end
    end
end

local function errorNotificationHostOnly(entity, positionEntity)
    return errorNotification(entity, L("Host only!", "error.localPlayerNotLobbyHost"), positionEntity)
end

local function getModeSaveDataById(modeID)
    local supportedModes = {
        [8] = "No Return",
        [9] = "Hard",
        [10] = "Phasing",
        [11] = "Randomizer",
        [12] = "Mystery",
        [13] = "No Beat",
        [20] = "Double Tempo",
        [23] = "Low Percent"
    }

    return progression.getExtraModes(supportedModes[modeID])
end

local function isExtraModeLocked(mode)
    return not (apClient.isSessionConnected() and progression.getExtraModes() and getModeSaveDataById(mode))
end

local function isExtraModeDisabled(mode)
    return progression.getExtraModes() and getModeSaveDataById(mode) == nil
end

local function tryToggleAPExtraMode(playerEntity, modeEntity, explosive)
    local modeID = modeEntity.interactableToggleExtraMode.extraModeID

    if trapClientTrigger.isPrimaryPlayerEntity(playerEntity) then
        if isExtraModeLocked(modeID) then
            if focus.check(playerEntity, focus.Flag.FLYAWAY) then
                flyaway.create({
                    offsetY = -7,
                    entity = modeEntity,
                    text = isExtraModeDisabled(modeID) and "Mode Disabled!" or
                        L("locked!", "flyaway.characterLocked.generic")
                })
            end

            sound.playIfFocused("error", playerEntity)

            return
        end

        lobbyEffects.playConfigShrineEffects(modeEntity, playerEntity, explosive)

        local active = not extraMode.isActive(modeID)

        if extraMode.Type.data[modeID].toggle == false and not active then
            return
        end

        modeEntity.interactableToggleExtraMode.active = active
        modeEntity.AP_interactable.active = active

        if trapClientTrigger.checkClientTrigger(playerEntity, modeEntity) then
            extraMode.setActive(modeID, active)
        end
    else
        errorNotificationHostOnly(playerEntity, modeEntity)
    end
end

event.render.add("apExtraModePreview", { order = "characterPreview", sequence = 2 }, function()
    for entity in ecs.entitiesWithComponents({
        "AP_interactable",
        "interactableToggleExtraMode"
    })
    do
        if entity.visibility.visible and entity.AP_interactable.ap then
            local extraModeInt = entity.AP_interactableExtraModeLobby.extraMode
            local locked = isExtraModeLocked(extraModeInt)

            apPreview.draw(entity, {
                entity = entity,
                silhouette = locked,
                indicatorColor = apPreview.indicatorColor(isExtraModeDisabled(extraModeInt), false),
            })
        end
    end
end)

event.objectInteract.override("changeConfiguration", { sequence = 1 }, function(func, ev)
    if (ev.entity.AP_interactable.ap) then
        return tryToggleAPExtraMode(ev.interactor, ev.entity)
    else
        return func(ev)
    end
end)
event.objectTakeDamage.override("changeConfiguration", { sequence = 1 }, function(func, ev)
    if (ev.entity.AP_interactable.ap) then
        return tryToggleAPExtraMode(ev.attacker, ev.entity, true)
    else
        return func(ev)
    end
end)

-- TODO: This shouldn't be overriding without using the callback
event.objectGetHUDEquipment.override("showExtraModes", { sequence = 1 }, function(func, ev)
    if currentLevel.isSafe() and not ev.lobbyShrinesAdded then
        ev.lobbyShrinesAdded = true

        for entity in ecs.entitiesWithComponents({
            "interactableToggleExtraModeSpriteChange"
        }) do
            -- TODO: Find out a way to have an item come from AP_interactable when activated and not the vanilla shrine
            if entity.interactableToggleExtraMode.active and not entity.AP_interactable.ap then
                ev.slots.misc = ev.slots.misc or {}

                table.insert(ev.slots.misc, entity)
            end
        end
    end
end)
