local CustomEntities = require("necro.game.data.CustomEntities")
local collision = require("necro.game.tile.Collision")
local ecs = require("system.game.Entities")
local minimapTheme = require("necro.game.data.tile.MinimapTheme")
local event = require("necro.event.Event")
local color = require("system.utils.Color")
local action = require("necro.game.system.Action")
local characterSelector = require("necro.client.Lobby")
local characterSwitch = require("necro.game.character.CharacterSwitch")
local currentLevel = require("necro.game.level.CurrentLevel")
local customActions = require("necro.game.data.CustomActions")
local gameDLC = require("necro.game.data.resource.GameDLC")
local gameSession = require("necro.client.GameSession")
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
local textFormat = require("necro.config.i18n.TextFormat")
local textPool = require("necro.config.i18n.TextPool")
local trapClientTrigger = require "necro.game.trap.TrapClientTrigger"
local theme = require("necro.config.Theme")
local tick = require("necro.cycles.Tick")
local utils = require("system.utils.Utilities")
local Vision = require("necro.game.vision.Vision")

local outlineFilter = require("necro.render.filter.OutlineFilter")

local apCharacters = require("AP.scripts.utils.apCharacters")
local apClient = require("AP.scripts.client.client")
local apInventory = require("AP.scripts.utils.apInventory")
local apPreview = require("AP.scripts.utils.apPreview")
local progression = require("AP.scripts.client.progression")

local isLobby = currentLevel.isLobby

-- Rift skins have different frame dimensions than the prototype sprite; outlineFilter
-- reads prototype width/height, producing a misaligned outline. We draw the correct
-- outline manually and null ev.outline to skip the default handler. However, ev is
-- shared with the head attachment's nested preview, so stash and restore at sequence 1
-- instead of leaving it nil permanently.
event.objectPreview.add("apFixRiftSkinOutline", {
    filter = {"CharacterSkins_skinnable", "sprite"},
    order = "outline",
    sequence = -1,
}, function(ev)
    if not ev.outline or not ev.visual then return end

    local skinW = ev.visual.texRect[3]
    local skinH = ev.visual.texRect[4]
    local protoW = ev.entity.sprite.width
    local protoH = ev.entity.sprite.height

    if skinW <= 0 or skinH <= 0 or (skinW == protoW and skinH == protoH) then return end

    local outlineVisual = utils.fastCopy(ev.visual)
    outlineFilter.padVisual(
        outlineVisual,
        math.floor(outlineVisual.texRect[1] / skinW),
        math.floor(outlineVisual.texRect[2] / skinH)
    )
    outlineVisual.texture = outlineFilter.getPath({
        image = ev.visual.texture,
        fw = skinW,
        fh = skinH,
    })
    if type(ev.outline) == "number" then
        outlineVisual.color = color.fade(ev.outline, color.getA(outlineVisual.color or color.WHITE) / 255)
    end
    outlineVisual.z = (outlineVisual.z or 0) - 0.01
    ev.draw(outlineVisual)

    ev._apOutlineStash = ev.outline
    ev.outline = nil
end)

event.objectPreview.add("apRestoreOutlineAfterFix", {
    filter = {"CharacterSkins_skinnable", "sprite"},
    order = "outline",
    sequence = 1,
}, function(ev)
    if ev._apOutlineStash ~= nil then
        ev.outline = ev._apOutlineStash
        ev._apOutlineStash = nil
    end
end)

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
    AP_worldLabelCharacterStats = {},
    worldLabelMaxWidth = {},
    AP_interactableSelectCharacterLobby = {
        resetPosition = true,
    },
    AP_preview = {},

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
    AP_editorCategory = {},
})

local getMissingRequiredItems = apCharacters.getMissingRequiredItems

local function isCharacterLocked(name)
    local character = apCharacters.cotNDCharToAPLocation(name)
    if not apClient.isSessionConnected() then return true end
    if not progression.getCharacters(character) then return true end

    local characterUnlocks = progression.getCharacterUnlocks()
    if characterUnlocks == 1 or characterUnlocks == 2 then
        return getMissingRequiredItems(name) ~= nil
    end

    return false
end

local function getCharacterLockText(name)
    local character = apCharacters.cotNDCharToAPLocation(name)

    if not apClient.isSessionConnected() or not progression.getCharacters(character) then
        return L("Locked!", "flyaway.characterLocked.generic")
    end

    local missing = getMissingRequiredItems(name)
    if missing then
        local names = {}
        for _, item in ipairs(missing) do
            local proto = ecs.getEntityPrototype(item)
            table.insert(names, proto and proto.friendlyName and proto.friendlyName.name or item)
        end
        return "Find " .. table.concat(names, ", ") .. " to unlock!"
    end

    return L("Locked!", "flyaway.characterLocked.generic")
end

local isCharacterDisabled = apCharacters.isCharacterDisabled

event.render.add("characterPreviewAP", { order = "characterPreview", sequence = 1 }, function(ev)
    for entity in
    ecs.entitiesWithComponents({
        "AP_interactableSelectCharacterLobby",
        "AP_preview",
    })
    do
        if entity.visibility.visible then
            local preview = ecs.getEntityPrototype(entity.interactableSelectCharacter.characterType)

            if preview then
                local disabled = isCharacterDisabled(preview.name)
                local locked = disabled or isCharacterLocked(preview.name)
                local character = apCharacters.cotNDCharToAPLocation(preview.name)
                local missingRequirementLock = not disabled and progression.getCharacters(character) and getMissingRequiredItems(preview.name) ~= nil

                apPreview.draw(preview, {
                    entity = entity,
                    silhouette = locked,
                    indicatorColor = apPreview.indicatorColor(disabled, missingRequirementLock),
                })
            end
        end
    end
end)

local function isCharacterComplete(charData, character)
    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4
    local goal = progression.getGoal()
    for zone = 1, lastZone do
        if charData["Zone " .. zone] ~= true then return false end
    end
    for _, boss in ipairs(progression.getStoryBosses(character)) do
        if charData[boss.name] ~= true then return false end
    end
    if goal == "All Zones" and charData["All Zones"] ~= true then return false end
    return true
end

local function getZoneStatusLine(charData, character)
    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4
    local goal = progression.getGoal()
    local GREEN = theme.Color.STATUS_OK
    local RED = color.rgb(255, 80, 80)

    local parts = {}
    for zone = 1, lastZone do
        local completed = charData["Zone " .. zone] == true
        table.insert(parts, textFormat.color(tostring(zone), completed and GREEN or RED))
    end

    -- Story bosses are checks of their own, so they read as extra segments after
    -- the zones: Cadence is 1/2/3/4/DR/ND.
    for _, boss in ipairs(progression.getStoryBosses(character)) do
        local beaten = charData[boss.name] == true
        table.insert(parts, textFormat.color(boss.abbreviation, beaten and GREEN or RED))
    end

    if goal == "All Zones" then
        local allDone = charData["All Zones"] == true
        table.insert(parts, textFormat.color("A", allDone and GREEN or RED))
    end

    return table.concat(parts, "/")
end

event.objectUpdateTextLabel.add("apPersonalStats", {
    filter = "AP_worldLabelCharacterStats",
    order = "personalStats"
}, function(ev)
    local characterType = ev.entity.AP_worldLabelCharacterStats.characterType
    if isCharacterDisabled(characterType) or isCharacterLocked(characterType) then return end

    local character = apCharacters.cotNDCharToAPLocation(characterType)
    local charData = progression.getCharacterLocations(character)
    if charData == nil then return end

    local append = function(s)
        ev.text = ev.text and ev.text .. "\n" .. s or s
    end

    if isCharacterComplete(charData, character) then
        append(textFormat.color("Complete", theme.Color.HIGHLIGHT))
        return
    end

    local line = getZoneStatusLine(charData, character)
    if line ~= "" then append(line) end
end)

local function getRandomPlayableCharacter(channel, exclude)
    local characters = {}

    for _, char in
    ipairs(ecs.getEntityTypesWithComponents({
        "playableCharacter",
        "!playableCharacterNonSelectable",
    }))
    do
        if not isCharacterDisabled(char) and not isCharacterLocked(char) and char ~= exclude then
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
                    apCharacters.setAPHealth(entity)

                    if entity then
                        local x, y = marker.lookUpFirst(marker.Type.AP_SPAWN)
                        if x == nil then x, y = marker.lookUpFirst(marker.Type.SPAWN) end
                        move.absolute(entity, x or 0, y or 0)
                        Vision.updateFieldOfView()
                    end
                end

                if apClient.isSessionConnected() then
                    for _, entity in ipairs(player.getPlayerEntities()) do
                        apInventory.applyStarterInventory(entity, progression, { sanitize = true })
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
    local playerID = trapClientTrigger.checkClientTrigger(ev.interactor, ev.entity)

    if playerID and ecs.typeHasComponent(characterType, "controllable") then
        if not localCoop.isLocal(playerID) then
            return
        end

        local disabled = isCharacterDisabled(characterType)
        local unlockText = getCharacterLockText(characterType)
        if disabled then
            unlockText = "Character Disabled!"
        end
        if disabled or isCharacterLocked(characterType) then
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
