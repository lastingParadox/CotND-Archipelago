local attack = require "necro.game.character.Attack"
local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local flyaway = require "necro.game.system.Flyaway"
local focus = require "necro.game.character.Focus"
local player = require "necro.game.character.Player"
local rng = require "necro.game.system.RNG"
local sound = require "necro.audio.Sound"
local tile = require("necro.game.tile.Tile")
local tileTypes = require "necro.game.tile.TileTypes"
local hasStorage, _ = pcall(require, "system.file.Storage")
local hasClient, _ = pcall(require, "system.network.Client")

local apClient = require("AP.scripts.client.client")
local apCharacters = require("AP.scripts.utils.apCharacters")
local modConflict = require("AP.scripts.utils.modConflict")
local progression = require("AP.scripts.client.progression")

-- Entity definition
customEntities.register({
    name = "TriggerAPTrap",
    position = {},
    trap = { targetFlags = attack.Flag.PLAYER_CONTROLLED },
    AP_trapUnlock = { lockType = "zoneProgress" },
    trapStartRun = { mode = "AP_APAllZones" },
})

customEntities.register({
    name = "AP_TriggerHintTrap",
    position = {},
    trap = { targetFlags = attack.Flag.PLAYER_CONTROLLED },
    AP_trapUnlock = { lockType = "hintMode" },
    AP_hintTrap = {},
    trapStartRun = { mode = "AP_APHintMode" },
})

local function errorNotification(entity, text, positionEntity)
    if text then
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

local function zoneAccessAllowed(zone, characterName, lastZone)
    if progression.getZoneAccessKeys() == "separate" then
        return progression.hasZoneAccess(zone)
    end

    local totalAccessible = 1 + progression.getProgressiveZoneAccessCount()

    if characterName == "Aria" then
        -- Aria runs in reverse: zone lastZone first, then lastZone-1, etc.
        return zone >= (lastZone - totalAccessible + 1)
    end

    return zone <= totalAccessible
end

local function getZoneAccessKeyLockedText(zone)
    local mode = progression.getZoneAccessKeys()
    if mode == "disabled" then return nil end

    -- Separate keys name their zone, so the starting zone is already open.
    if mode == "separate" and zone and zone > 0 and zone == progression.getStartingZone() then
        return nil
    end

    return "Receive access to unlock!"
end


local function isBossRushPartyCapable()
    local selected = player.getSelectedPlayerCharacters()
    local anySelected = false

    for _, characterName in pairs(selected) do
        anySelected = true
        if apCharacters.cotNDCharToAPLocation(characterName) ~= "Dove" then
            return true
        end
    end

    return not anySelected
end

local function isZoneProgressUnlocked(entity)
    -- Zone progression requires AP connection
    if not apClient.isSessionConnected() then return false end

    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4

    if entity.trapStartRun.mode == "AP_APAllZones" then
        return true
    end

    if entity.trapStartRun.mode == "AP_APEnsemble" or entity.trapStartRun.mode == "AP_APBossRush" then
        local _, goalMet = progression.calculateGoalCompletion(false)
        if not (goalMet and progression.allZonesUnlocked(lastZone)) then return false end

        if entity.trapStartRun.mode == "AP_APBossRush" then
            return isBossRushPartyCapable()
        end

        return true
    end

    local zone = entity.trapStartRun.zone
    if zone <= 0 then return false end

    -- Disallow Zone 5 if Amplified is off
    if (lastZone == 4 and zone == 5) then return false end

    for _, characterName in pairs(player.getSelectedPlayerCharacters()) do
        local name = apCharacters.cotNDCharToAPLocation(characterName)
        if progression.getCharacters(name) and zoneAccessAllowed(zone, characterName, lastZone) then
            return true
        end
    end

    return false
end

-- Slots that do not lock the room are granted the key up front.
local function isCharacterRoomKeyUnlocked(_)
    return progression.hasCharacterRoomKey()
end

local function isAPModulesUnlocked(_)
    return hasStorage and hasClient
end

local function isAlwaysUnlocked(_)
    return true
end

local function isHintModeUnlocked(_)
    return apClient.isSessionConnected()
end

local function isModConflictFree(_)
    return not modConflict.hasLegacyArchipelago()
end

local lockEvaluators = {
    none = isAlwaysUnlocked,
    zoneProgress = isZoneProgressUnlocked,
    characterRoomKey = isCharacterRoomKeyUnlocked,
    apModules = isAPModulesUnlocked,
    hintMode = isHintModeUnlocked,
    modConflict = isModConflictFree,
}

local function getLockType(entity)
    return entity.AP_trapUnlock and entity.AP_trapUnlock.lockType or "none"
end

-- Helper to determine if a trap is unlocked
local function isUnlocked(entity)
    local evaluator = lockEvaluators[getLockType(entity)] or lockEvaluators.none
    return evaluator(entity)
end

local function isZoneDisabled(entity)
    if getLockType(entity) ~= "zoneProgress" then
        return false
    end

    if not entity.trapStartRun
        or entity.trapStartRun.mode == "AP_APAllZones"
        or entity.trapStartRun.mode == "AP_APEnsemble"
        or entity.trapStartRun.mode == "AP_APBossRush" then
        return false
    end

    local zone = entity.trapStartRun.zone or 0
    return zone == 5 and not progression.isDLCEnabled("Amplified")
end

-- How each lock draws while shut; zoneProgress varies per slot and is built below.
local lockedTiles = {
    apModules = "LobbyStairsDisabled",
    modConflict = "LobbyStairsDisabled",
    characterRoomKey = "LobbyLockedStairs",
}

local function getLockedTileType(entity)
    local lockType = getLockType(entity)

    if lockType == "zoneProgress" then
        if isZoneDisabled(entity) then
            return "LobbyStairsDisabled"
        end

        if progression.getZoneAccessKeys() == "disabled" then
            return "LobbyLockedStairs"
        end

        return "LobbyLockedStairs"
    end

    return lockedTiles[lockType]
        or (entity.AP_trapUnlock and entity.AP_trapUnlock.lockedTileType)
        or "LobbyLockedStairs"
end

local function getZoneProgressLockedText(trap, victim)
    local zone = trap.trapStartRun.zone or 0
    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4

    if not progression.isDLCEnabled("Amplified") and zone == 5 then
        return "Zone Disabled!"
    end

    if trap.trapStartRun.mode == "AP_APEnsemble" or trap.trapStartRun.mode == "AP_APBossRush" then

        local goalText = progression.getGoalUnlockText()
        if goalText then return goalText end

        if trap.trapStartRun.mode == "AP_APBossRush" and not isBossRushPartyCapable() then
            return "Locked! Pick another character!"
        end

        return "Unlock every zone\nto enter!"
    end

    local character = victim and victim.name or "Cadence"
    local keyText = getZoneAccessKeyLockedText(zone)
    if keyText and not zoneAccessAllowed(zone, character, lastZone) then
        return keyText
    end

    local variance = character ~= "Aria" and -1 or 1
    local text = L.format(trap.AP_trapUnlock.lockedText, zone + variance)

    return text
end

local function getCharacterRoomKeyLockedText(trap, _)
    return trap.AP_trapUnlock.lockedText or "Find the key to unlock!"
end

local function getAPModulesLockedText(trap, _)
    return trap.AP_trapUnlock.lockedText or
        "Enable system.network.Client and system.file.Storage in config.json to use Archipelago."
end

local function getHintModeLockedText(_, _)
    return "Connect to Archipelago to play a Hint Run!"
end

local lockMessageResolvers = {
    zoneProgress = getZoneProgressLockedText,
    characterRoomKey = getCharacterRoomKeyLockedText,
    apModules = getAPModulesLockedText,
    hintMode = getHintModeLockedText,
}

-- Spawn event
event.objectSpawn.add("apCheckTriggerUnlock", { filter = "AP_trapUnlock", order = "unlock" }, function(ev)
    local unlocked = isUnlocked(ev.entity)
    tile.setType(ev.x, ev.y, unlocked and "LobbyStairs" or getLockedTileType(ev.entity))
end)

-- Visual update event
event.updateVisuals.add("apTrapVisuals", { order = "trapVisuals", sequence = 1 }, function(_)
    for entity in ecs.entitiesWithComponents({ "AP_trapUnlock" }) do
        -- No tile info before the level is sized.
        local tileInfo = tileTypes.getTileInfo(tile.get(entity.position.x, entity.position.y))
        if tileInfo then
            local unlocked = isUnlocked(entity)
            local desiredTile = unlocked and "LobbyStairs" or getLockedTileType(entity)
            if tileInfo.name ~= desiredTile then
                tile.setType(entity.position.x, entity.position.y, desiredTile)
            end
        end
    end
end)

event.trapTrigger.add("apHintTrapSetup", {
    filter = "AP_hintTrap",
    order = "unlock",
    sequence = -1,
}, function(ev)
    if not ev.success then return end

    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4

    local availChars = {}
    for _, charName in ipairs(ecs.getEntityTypesWithComponents({ "playableCharacter", "!playableCharacterNonSelectable" })) do
        local charId = apCharacters.cotNDCharToAPLocation(charName)
        if progression.getCharacters(charId) then
            table.insert(availChars, charName)
        end
    end

    if #availChars == 0 then
        ev.success = false
        errorNotification(ev.victim, "No unlocked characters available!")
        return
    end

    local seed = rng.getDungeonSeed() + (ev.victim and ev.victim.id or 0)
    local chosenChar = rng.choice(availChars, rng.makeChannel(seed))

    -- Collect zones accessible to the chosen character.
    local accessibleZones = {}
    for zone = 1, lastZone do
        if zoneAccessAllowed(zone, chosenChar, lastZone) then
            table.insert(accessibleZones, zone)
        end
    end

    if #accessibleZones == 0 then
        accessibleZones = { progression.getStartingZone() }
    end

    local chosenZone = rng.choice(accessibleZones, rng.makeChannel(seed + 10000))
    ev.trap.trapStartRun.zone = chosenZone

    -- Override the character for the run via trapStartRun.options (merged into gameSession.start parameters).
    ev.trap.trapStartRun.options = { characterOverride = chosenChar }
end)

-- Switches to "APSingleZone" when only one zone is reachable.
event.trapTrigger.add("apZonesModeSingleZone", {
    filter = "trapStartRun",
    order = "descend",
    sequence = -1,
}, function(ev)
    if not ev.success then return end
    if ev.trap.trapStartRun.mode ~= "AP_APAllZones" then return end

    local accessible = progression.getAccessibleZones()
    if #accessible ~= 1 then return end

    ev.trap.trapStartRun.mode = "AP_APSingleZone"
    ev.trap.trapStartRun.zone = accessible[1]
end)

event.trapTrigger.add("handleAPTrapUnlock", {
    filter = "AP_trapUnlock",
    order = "unlock"
}, function(ev)
    if ev.success and not isUnlocked(ev.trap) then
        ev.success = false

        local resolver = lockMessageResolvers[getLockType(ev.trap)] or lockMessageResolvers.zoneProgress
        local text = resolver(ev.trap, ev.victim)

        if getLockType(ev.trap) == "zoneProgress" and not apClient.isSessionConnected() then
            text = L("AP Disconnected!")
        end

        errorNotification(ev.victim, text)
    end
end)
