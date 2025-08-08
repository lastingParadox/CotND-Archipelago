local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require("system.game.Entities")
local extraMode = require "necro.game.data.modifier.ExtraMode"
local flyaway = require "necro.game.system.Flyaway"
local focus = require "necro.game.character.Focus"
local lobbyEffects = require "necro.render.level.LobbyEffects"
local sound = require "necro.audio.Sound"
local trapClientTrigger = require "necro.game.trap.TrapClientTrigger"

local apConnection = require("AP.scripts.ap_handlers.APConnection")
local hasPendingRunStart = false

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

    return apConnection.saveData.extraModes and
        apConnection.saveData.extraModes[supportedModes[modeID]]
end

local function tryToggleAPExtraMode(playerEntity, modeEntity, explosive)
    local modeID = modeEntity.interactableToggleExtraMode.extraModeID

    if trapClientTrigger.isPrimaryPlayerEntity(playerEntity) then
        if not (apConnection.saveData.extraModes and getModeSaveDataById(modeID)) then
            if focus.check(playerEntity, focus.Flag.FLYAWAY) then
                flyaway.create({
                    offsetY = -7,
                    entity = modeEntity,
                    text = L("Mode locked!")
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

event.objectInteract.override("changeConfiguration", { sequence = 1 }, function(func, ev)
    if (ev.entity.AP_interactable.ap) then return tryToggleAPExtraMode(ev.interactor, ev.entity) else return func(ev) end
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
