local boss = require "necro.game.level.Boss"
local currency = require "necro.game.item.Currency"
local currentLevel = require("necro.game.level.CurrentLevel")
local ecs = require "system.game.Entities"
local extraMode = require "necro.game.data.modifier.ExtraMode"
local flyaway = require "necro.game.system.Flyaway"
local gameSession = require "necro.client.GameSession"
local instantReplay = require "necro.client.replay.InstantReplay"
local inventory = require("necro.game.item.Inventory")
local itemBan = require "necro.game.item.ItemBan"
local itemGeneration = require "necro.game.item.ItemGeneration"
local itemPickup = require "necro.game.item.ItemPickup"
local itemSlot = require "necro.game.item.ItemSlot"
local object = require("necro.game.object.Object")
local player = require("necro.game.character.Player")
local playerList = require("necro.client.PlayerList")
local replayPlayer = require "necro.client.replay.ReplayPlayer"
local speedrunTimer = require "necro.client.SpeedrunTimer"

local apCharacters = require("AP.scripts.utils.apCharacters")
local apClient = require("AP.scripts.client.client")
local apInventory = require("AP.scripts.utils.apInventory")
local apStorage = require("AP.scripts.client.storage")
local apItems = require("AP.scripts.utils.apItems")
local apUtils = require("AP.scripts.utils.apUtils")
local progressionCharacters = require("AP.scripts.client.progression.characters")
local progressionGoals = require("AP.scripts.client.progression.goals")
local progressionItems = require("AP.scripts.client.progression.items")
local progressionMeta = require("AP.scripts.client.progression.meta")
local progressionNetwork = require("AP.scripts.client.progression.network")
local progressionPlayer = require("AP.scripts.client.progression.player")
local progressionShops = require("AP.scripts.client.progression.shops")
local progressionZoneAccess = require("AP.scripts.client.progression.zoneAccess")

local SPECIAL_BOSSES = {
    [boss.Type.DEAD_RINGER]     = { name = "Dead Ringer",     abbreviation = "DR", zone = 4, characters = { Cadence = true } },
    [boss.Type.NECRODANCER]     = { name = "NecroDancer",     abbreviation = "ND", zone = 4, characters = { Cadence = true } },
    [boss.Type.NECRODANCER_2]   = { name = "NecroDancer",     abbreviation = "ND", zone = 4, characters = { Melody = true } },
    [boss.Type.GOLDEN_LUTE]     = { name = "Golden Lute",     abbreviation = "GL", zone = 1, characters = { Aria = true } },
    [boss.Type.FRANKENSTEINWAY] = { name = "Frankensteinway", abbreviation = "FW", zone = 5, characters = { Nocturna = true } },
    [boss.Type.CONDUCTOR]       = { name = "The Conductor",   abbreviation = "TC", zone = 5, characters = { Nocturna = true } },
}

local progression = {}
progression = script.persist(function()
    return progression
end)

-- After the persist swap: a table restored from an earlier load would not carry it.
progression.specialBosses = SPECIAL_BOSSES

function progression.getStoryBosses(character)
    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4
    local bosses = {}

    for bossType, entry in pairs(SPECIAL_BOSSES) do
        if entry.characters[character] and entry.zone <= lastZone then
            bosses[#bosses + 1] = {
                order = bossType,
                name = entry.name,
                abbreviation = entry.abbreviation,
            }
        end
    end

    table.sort(bosses, function(a, b) return a.order < b.order end)

    return bosses
end

progressionMeta.attach(progression)
progressionPlayer.attach(progression)
progressionItems.attach(progression)
progressionCharacters.attach(progression)
progressionShops.attach(progression)
progressionNetwork.attach(progression)
progressionGoals.attach(progression)
progressionZoneAccess.attach(progression)

function progression.rebuildCaches()
    progression.rebuildItemCache(apCharacters, apItems)
    progression.rebuildCharacterCache(apCharacters)
end

local function getItemBanTarget(entity)
    if entity.playableCharacter then
        return entity
    else
        return itemGeneration.randomPlayer(currentLevel.getNumber())
    end
end

local function grantNextRunItems(entity)
    local nextRunItems = progression.getNextRunItems()
    for itemType, _ in pairs(nextRunItems) do
        if not itemBan.isBanned(getItemBanTarget(entity), itemType, itemBan.Flag.PICKUP) then
            if currentLevel.isLobby() then
                inventory.replaceIfUncursed(itemType, entity)
            else
                itemPickup.noisyGrant(itemType, entity)
                progression.removeNextRunItem(itemType)
            end
        end
    end
end

-- Next run initial items granter
event.objectSpawn.add("apGrantInitialItems",
{ filter = "initialInventoryUnlockReceiver", order = "itemsUnlockable", sequence = 1 }, function(ev)
    if apUtils.isAPContext(ev.entity) and not currentLevel.getPlayerOptions().noItems then
        grantNextRunItems(ev.entity)
    end
end)

local function isPendingPlayerEntity(entity)
    return entity.playableCharacter and entity.playableCharacter.pendingPlayerID ~= 0
end

event.objectSpawn.override("giveInitialInventory", function(func, ev)
    if not ev.entity.playableCharacter then return func(ev) end
    local inConnectedLobby = currentLevel.isLobby() and apClient.isSessionConnected()
    if not apUtils.isAPContext(ev.entity) then return func(ev) end

    local allowLobbyInitialItems = inConnectedLobby

    if not ev.clone and ev.entity.initialInventory.pending and (allowLobbyInitialItems or not currentLevel.getPlayerOptions().noItems or not isPendingPlayerEntity(ev.entity)) then
        ev.entity.initialInventory.pending = false

        apInventory.grantAllowedInitialItems(ev.entity, progression)
        -- Character switches in the AP lobby may not include all unique starters in initialInventory.
        apInventory.applyStarterInventory(ev.entity, progression)
    end
end)

event.objectCharacterSwitchTo.add("apRemoveLockedInitialItems", {
    filter = { "initialInventory", "inventory" },
    order = "inventory",
    sequence = 1,
}, function(ev)
    if not ev.entity.playableCharacter or not apUtils.isAPContext(ev.entity) then return end
    if gameSession.getCurrentMode().id == "APEnsemble" then return end

    for _, item in ipairs(inventory.getItems(ev.entity)) do
        if item.itemInitial and item.itemInitial.active
            and not apInventory.isAllowedItem(ev.entity, item.name, progression) then
            object.delete(item)
        end
    end
end)

-- Outcome of the run's All Zones time limit, or nil when nothing was timed.
function progression.getSpeedrunResult()
    return progression.speedrunResult
end

event.gameStateReset.add("apClearSpeedrunResult", { order = "resetRunVariables" }, function()
    progression.speedrunResult = nil
end)

event.levelComplete.add("apLevelComplete", { order = "winScreen" }, function(ev)
    local mode = gameSession.getCurrentMode().id

    if instantReplay.isActive()
        or replayPlayer.isActive()
        or gameSession.getCurrentMode().id == "APHintMode"
        or not apUtils.isAPContext()
        or not apClient.isSessionConnected()
    then
        return
    end

    -- Track all players who completed the level
    local playerEntities = player.getPlayerEntities()
    if #playerEntities == 0 then return end

    local curZone = currentLevel.getZone()
    local curFloor = currentLevel.getFloor()
    local bossType = currentLevel.getBossType()

    local specialBoss = SPECIAL_BOSSES[bossType]

    local firstPhaseBosses = {
        [boss.Type.DEAD_RINGER] = true,
        [boss.Type.FRANKENSTEINWAY] = true
    }

    local processedCharacters = {}
    local collectedChecks = {}

    for _, playerEntity in ipairs(playerEntities) do
        -- Possession Check
        local characterEntity = playerEntity
        if playerEntity.Sync_possessable and playerEntity.Sync_possessable.possessor ~= 0 then
            local possessor = ecs.getEntityByID(playerEntity.Sync_possessable.possessor)
            if possessor then
                characterEntity = possessor
            end
        end
        local character = apCharacters.cotNDCharToAPLocation(characterEntity.name)

        if not processedCharacters[character] then
            processedCharacters[character] = true

            local zones = {}
            if specialBoss and specialBoss.characters[character] then
                table.insert(zones, { name = specialBoss.name, zone = specialBoss.name })
            end

            if (currentLevel.isBoss() and character ~= "Dove") or (character == "Dove" and curFloor == 3) then
                if not firstPhaseBosses[bossType] then
                    table.insert(zones, { name = "Zone " .. curZone, zone = "Zone " .. curZone })
                end
            end

            -- Floors are checks only where the client said they are.
            if bossType == 0 and progression.getZoneProgressFloors()[curFloor] then
                table.insert(zones, { name = "Zone " .. curZone .. " - Floor " .. curFloor, zone = nil })
            end

            local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4
            if mode == "APAllZones" and currentLevel.isFinal() and progression.allZonesUnlocked(lastZone) then
                local target = progression.getSpeedrunTime(character)
                local runTime = speedrunTimer.getDeterministicTime()

                local passed = target == 0 or runTime <= target * 60

                if passed then
                    table.insert(zones, { name = "All Zones", zone = "All Zones" })
                else
                    flyaway.create({
                        entity = playerEntity,
                        text = ("Too slow! %s / %d:00"):format(
                            speedrunTimer.formatTime(runTime), target),
                    })
                end

                if target > 0 then
                    local prior = progression.speedrunResult
                    progression.speedrunResult = {
                        passed = passed and (prior == nil or prior.passed),
                        time = runTime,
                        target = target * 60,
                    }
                end
            end

            if #zones > 0 then
                progression.addLevelCompleteChecks(zones, character, collectedChecks)
            end
        end
    end

    if #collectedChecks > 0 then
        progression.sendLocationChecks(collectedChecks)
        progression.calculateGoalCompletion(true)
    end

    if mode == "APAllZones" and currentLevel.isFinal() then
        local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4
        if progression.allZonesUnlocked(lastZone) then
            local completedModes = apStorage.saveData.characterLocations["ExtraModes"] or {}
            local checks = {}
            for key, name in pairs(progressionGoals.EXTRA_MODES) do
                if extraMode.isActive(key) and not completedModes[name] then
                    completedModes[name] = true
                    table.insert(checks, name .. " Mode")
                end
            end
            apStorage.saveData.characterLocations["ExtraModes"] = completedModes
            if #checks > 0 then
                progression.sendLocationChecks(checks)
            end
        end
    end

    if mode == "APEnsemble" and currentLevel.isFinal() then
        local ensembleData = (progression.getCharacterLocations("Ensemble") or {})
        if not ensembleData["Completed"] then
            apStorage.saveData.characterLocations["Ensemble"] = { Completed = true }
            progression.calculateGoalCompletion(true)
        end
    end

    if mode == "APBossRush" and currentLevel.isFinal() then
        local bossRushData = (progression.getCharacterLocations("BossRush") or {})
        if not bossRushData["Completed"] then
            apStorage.saveData.characterLocations["BossRush"] = { Completed = true }
            progression.calculateGoalCompletion(true)
        end
    end
end)

event.runComplete.add("apHintModeComplete", { order = "menu", sequence = -1 }, function(ev)
    if gameSession.getCurrentMode().id ~= "APHintMode" then return end
    if not ev.summary or not ev.summary.victory then return end
    apClient.sendPacket({ datatype = "Hint" })
end)

-- Cashes a winning run's gold out into diamonds at the slot's rate; 0 disables it.
event.runComplete.add("apConvertRunGold", { order = "menu", sequence = -1 }, function(ev)
    if not apUtils.isAPContext() then return end
    if not ev.summary or not ev.summary.victory then return end

    local goldPerDiamond = progression.getGoldToDiamondRate()
    if goldPerDiamond <= 0 then return end

    local gold = 0
    if currency.isShared(currency.Type.GOLD) then
        gold = currency.get(nil, currency.Type.GOLD)
    else
        for _, entity in ipairs(player.getPlayerEntities()) do
            gold = gold + currency.get(entity, currency.Type.GOLD)
        end
    end

    local diamonds = math.floor(gold / goldPerDiamond)
    if diamonds > 0 then
        progression.changeDiamonds(diamonds)
    end
end)

return progression
