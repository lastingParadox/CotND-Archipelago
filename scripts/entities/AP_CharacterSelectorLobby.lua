local CustomEntities = require("necro.game.data.CustomEntities")
local collision = require("necro.game.tile.Collision")
local minimapTheme = require("necro.game.data.tile.MinimapTheme")
local APConnection = require("AP.scripts.ap_handlers.APConnection")
local event = require("necro.event.Event")
local color = require("system.utils.Color")
local objectPreview = require("necro.render.level.ObjectPreview")
local render = require("necro.render.Render")
local Components = require("necro.game.data.Components")
local ui = require("necro.render.UI")
local SettingsStorage = require("necro.config.SettingsStorage")
local action = require("necro.game.system.Action")
local characterSelector = require("necro.client.Lobby")
local characterSwitch = require("necro.game.character.CharacterSwitch")
local currentLevel = require("necro.game.level.CurrentLevel")
local customActions = require("necro.game.data.CustomActions")
local gameDLC = require("necro.game.data.resource.GameDLC")
local gameSession = require("necro.client.GameSession")
local fastForward = require("necro.client.FastForward")
local flyaway = require("necro.game.system.Flyaway")
local localCoop = require("necro.client.LocalCoop")
local marker = require("necro.game.tile.Marker")
local menu = require("necro.menu.Menu")
local move = require("necro.game.system.Move")
local netplay = require("necro.network.Netplay")
local particle = require("necro.game.system.Particle")
local player = require("necro.game.character.Player")
local playerList = require("necro.client.PlayerList")
local rng = require("necro.game.system.RNG")
local spectator = require("necro.game.character.Spectator")
local sound = require("necro.audio.Sound")
local turn = require("necro.cycles.Turn")
local textPool = require("necro.config.i18n.TextPool")
local ecs = require("system.game.Entities")
local tick = require("necro.cycles.Tick")
local Vision = require("necro.game.vision.Vision")

local apUtils = require("AP.scripts.ap_handlers.APUtils")

local isLobby = currentLevel.isLobby

-- Duplicating components to separate events
Components.register({
    AP_interactableSelectCharacterPreview = {
        Components.field.float("offsetX", 0),
        Components.field.float("offsetY", 0),
        Components.field.float("offsetZ", 0),
        Components.field.float("offsetH", 0),
        Components.field.int("outlineColor", color.TRANSPARENT),
        Components.field.bool("shadowCopyZ", false),
    },
    AP_interactableSelectCharacterLobby = {
        Components.field.string("characterType", ""),
        Components.field.bool("resetPosition", false),
    },
})

-- This entity is taken directly from the NecroDancer code, with some slight changes.
CustomEntities.register({
    name = "AP_CharacterSelectorLobby",
    gameObject = {},
    position = {},
    worldLabel = {
        alignY = 0,
        offsetY = 6,
    },
    worldLabelEntityLookup = {
        component = "friendlyName",
        field = "name",
    },
    worldLabelCharacterStats = {},
    worldLabelMaxWidth = {},
    AP_interactableSelectCharacterLobby = {
        resetPosition = true,
    },
    AP_interactableSelectCharacterPreview = {},

    interactable = {},
    interactableSelectCharacter = {},
    interactableSelectCharacterConfirm = {},
    collision = {
        mask = collision.Type.OBJECT,
    },
    visibility = {},
    minimapStaticPixel = {
        color = minimapTheme.Color.NPC,
        depth = minimapTheme.Depth.SHRINE,
    },
})

local function isCharacterLocked(name)
    return not (APConnection.saveData.characters and APConnection.saveData.characters[name])
end

event.render.add("characterPreviewAP", { order = "characterPreview" }, function(ev)
    for entity in
    ecs.entitiesWithComponents({
        "AP_interactableSelectCharacterPreview",
    })
    do
        if entity.visibility.visible then
            local preview = ecs.getEntityPrototype(entity.interactableSelectCharacter.characterType)

            if preview then
                local locked = isCharacterLocked(preview.name)
                local component = entity.AP_interactableSelectCharacterPreview
                local args = {
                    x = entity.position.x,
                    y = entity.position.y,
                    offsetX = component.offsetX,
                    offsetY = component.offsetY,
                    offsetZ = component.offsetZ,
                    offsetH = component.offsetH,
                    animationSpeed = preview.previewAnimationSpeed and preview.previewAnimationSpeed.factor,
                    color = locked and color.BLACK,
                    outline = locked and color.rgb(114, 126, 133)
                        or component.outlineColor ~= color.TRANSPARENT and component.outlineColor
                        or nil,
                    shadowCopyZ = component.shadowCopyZ,
                    playerID = playerList.getLocalPlayerID(),
                }

                objectPreview.draw(preview, args)

                if locked then
                    local x, y = render.tileCenter(entity.position.x, entity.position.y)

                    if preview.playableCharacterLockedIndicatorOffset then
                        x = x + preview.playableCharacterLockedIndicatorOffset.offsetX
                        y = y + (preview.playableCharacterLockedIndicatorOffset.offsetsY[args.frameX] or 0)

                        if args.hoverY then
                            y = y + args.hoverY
                        end
                    end

                    ui.drawText({
                        alignX = 0.5,
                        alignY = 1,
                        text = "?",
                        font = ui.Font.MEDIUM,
                        fillColor = color.rgb(255, 87, 106),
                        shadowColor = color.TRANSPARENT,
                        x = x,
                        y = y + component.offsetH + component.offsetY,
                        z = y + component.offsetZ,
                        buffer = render.Buffer.OBJECT,
                    })
                end
            end
        end
    end
end)

local function getRandomPlayableCharacter(channel, exclude)
    local characters = {}

    for _, char in
    ipairs(ecs.getEntityTypesWithComponents({
        "playableCharacter",
        "!playableCharacterNonSelectable",
    }))
    do
        if not isCharacterLocked(char) and char ~= exclude then
            characters[#characters + 1] = char
        end
    end

    return rng.choice(characters, channel)
end

local function showConfirmationMenu(args)
    -- TODO: Find where this setting is located
    -- if not SettingsStorage.get("misc.menu.showLobbyConfirmations") and not args.forceConfirm then
    --     return args.yes()
    -- end

    local protoBestiary = ecs.getEntityPrototype(args.bestiaryEntityType)
    local protoMessage = ecs.getEntityPrototype(args.messageEntityType)
    local lookupResult = protoMessage
        and protoMessage[args.messageComponent]
        and protoMessage[args.messageComponent][args.messageField]

    menu.suppressKeyControlForTick()
    menu.open("bestiary", {
        targetMenu = "confirm",
        image = protoBestiary and protoBestiary.bestiary and protoBestiary.bestiary.image,
        backgroundImage = args.bestiaryBackground and "ext/gui/bg_gradient.png",
        message = textPool.format(args.messageKey, lookupResult or args.messageEntityType),
        yes = args.yes,
        no = args.no,
        closeDelay = args.closeDelay,
    })
end

local function getPrimaryPlayer(includeSpectators)
    local primaryPlayerID = gameSession.getDungeonOptions().primaryPlayerID

    if primaryPlayerID and (includeSpectators or not spectator.isSpectating(primaryPlayerID)) then
        return primaryPlayerID
    else
        for _, entity in ipairs(player.getPlayerEntities()) do
            if
                entity.controllable
                and entity.controllable.playerID ~= 0
                and (includeSpectators or not spectator.isSpectating(entity.controllable.playerID))
            then
                return entity.controllable.playerID
            end
        end

        if includeSpectators == nil then
            return getPrimaryPlayer(true)
        end
    end
end

local function updateCharacterPreference(playerID, characterTypeName)
    if localCoop.isLocal(playerID) then
        localCoop.setPlayerAttribute(playerID, netplay.PlayerAttribute.CHARACTER, characterTypeName)
        characterSelector.setPreferredCharacter(localCoop.getCoopPlayerNumber(playerID), characterTypeName)
    end
end

spectateLocalPlayersDeferred = tick.delay(function()
    spectator.setSpectating(nil, true)
end)

local function spectateIfUnowned(entityType)
    if not gameDLC.isCharacterOwned(entityType or player.getLateJoinCharacterOverride()) then
        spectateLocalPlayersDeferred()
    end
end

local _, triggerChangeCharacter = customActions.registerSystemAction({
    id = "TriggerChangeCharacterAP",
    callback = function(playerID, args)
        if type(args) ~= "table" then
            args = {
                type = args,
            }
        end

        if isLobby() then
            local isPrimary = playerID == getPrimaryPlayer()

            if isPrimary then
                if args.lock or args.lock == nil and player.getLateJoinCharacterOverride() then
                    player.setLateJoinCharacterOverride(args.lock or args.type)
                elseif args.lock == false then
                    player.setLateJoinCharacterOverride(nil)
                end
            end

            if player.isValidCharacterType(args.type) then
                updateCharacterPreference(playerID, args.type)

                if not player.isCharacterLockEnabled() then
                    characterSwitch.perform(player.getPlayerEntity(playerID), args.type, {
                        resetHealth = true,
                        immediate = true,
                    })
                elseif isPrimary then
                    spectateIfUnowned(args.type)

                    for _, entity in ipairs(player.getPlayerEntities()) do
                        characterSwitch.perform(entity, args.type, {
                            resetHealth = true,
                            immediate = true,
                        })
                    end
                end

                if args.reset then
                    local entity = player.getPlayerEntity(playerID)
                    apUtils.setAPHealth(entity)

                    if entity then
                        local x, y = marker.lookUpFirst(marker.Type.AP_SPAWN)
                        if x == nil then x, y = marker.lookUpFirst(marker.Type.SPAWN) end
                        move.absolute(entity, x or 0, y or 0)
                        Vision.updateFieldOfView()
                    end
                end
            end
        end
    end,
})

event.objectInteract.add("characterSelectAP", {
    filter = "AP_interactableSelectCharacterLobby",
    order = "configInteractable",
}, function(ev)
    local characterType = ev.entity.interactableSelectCharacter.characterType

    if ev.entity.interactableSelectCharacterRandom then
        characterType = getRandomPlayableCharacter(ev.entity, ev.interactor.name)
    end

    particle.play(ev.entity, "particlePuff")

    ev.result = action.Result.INTERACT
    local playerID = ev.interactor.id

    if playerID and ecs.typeHasComponent(characterType, "controllable") then
        if not localCoop.isLocal(playerID) then
            return
        end

        local unlockText = L("Locked!", "flyaway.characterLocked.generic")
        if not gameDLC.isCharacterOwned(characterType) then
            local prototype = ecs.getEntityPrototype(characterType)

            if prototype and prototype.playableCharacterDLC then
                if gameDLC.isPurchasable(prototype.playableCharacterDLC.dlc) then
                    local dlc = gameDLC.getTitle(prototype.playableCharacterDLC.dlc)
                    unlockText = L.formatKey("%s DLC required!", "flyaway.characterLocked.needDLC", dlc)
                else
                    unlockText = L("Coming soon!", "flyaway.characterLocked.comingSoon")
                end
            end

            flyaway.create({
                text = unlockText,
                entity = ev.entity,
            })
            sound.playFromEntity("error", ev.entity, {
                deduplicationID = ev.interactor.id,
            })

            return
        elseif isCharacterLocked(characterType) then
            flyaway.create({
                text = unlockText,
                entity = ev.entity,
            })
            sound.playFromEntity("error", ev.entity, {
                deduplicationID = ev.interactor.id,
            })

            return
        end

        local resetPosition = ev.entity.AP_interactableSelectCharacterLobby.resetPosition and not localCoop.isActive()

        if ev.entity.interactableSelectCharacterConfirm then
            return showConfirmationMenu({
                closeDelay = true,
                messageComponent = "textCharacterSelectionMessage",
                messageField = "text",
                messageKey = "label.lobby.confirm.generic",
                messageEntityType = characterType,
                bestiaryEntityType = characterType,
                yes = function()
                    triggerChangeCharacter(playerID, {
                        type = characterType,
                        reset = resetPosition,
                    })
                end,
            })
        else
            return triggerChangeCharacter(playerID, {
                type = characterType,
                reset = resetPosition,
            })
        end
    end
end)
