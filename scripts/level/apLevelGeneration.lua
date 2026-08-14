local currentLevel = require("necro.game.level.CurrentLevel")
local gameSession = require "necro.client.GameSession"
local instantReplay = require "necro.client.replay.InstantReplay"
local menu = require("necro.menu.Menu")
local player = require("necro.game.character.Player")
local proceduralRun = require("necro.game.data.level.ProceduralRun")
local replayPlayer = require "necro.client.replay.ReplayPlayer"
local rng = require "necro.game.system.RNG"
local stateControl = require("necro.client.StateControl")

local apCharacters = require("AP.scripts.utils.apCharacters")
local apClient = require("AP.scripts.client.client")
local apFlags = require("AP.scripts.utils.flags")
local apReplay = require("AP.scripts.utils.apReplay")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

event.levelSequenceUpdate.add("apRemoveZone5", { order = "initAllZones", sequence = 0 }, function(ev)
    if (ev.mode.id ~= "APAllZones" and ev.mode.id ~= "APEnsemble" and ev.mode.id ~= "APBossRush") or progression.isDLCEnabled("Amplified") then
        return
    end

    local newZones = {}
    for _, z in ipairs(ev.zones) do
        if z ~= 5 then
            table.insert(newZones, z)
        end
    end
    ev.zones = newZones

    local newSeq = {}
    for _, s in ipairs(ev.sequence) do
        if s.zone ~= 5 then
            table.insert(newSeq, s)
        end
    end
    ev.sequence = newSeq
end)

event.levelSequenceUpdate.add("apFilterAccessibleZones", { order = "initAllZones", sequence = 1 }, function(ev)
    if ev.mode.id ~= "APAllZones" then return end
    local zoneAccessMode = progression.getZoneAccessKeys()
    if zoneAccessMode == 0 then return end

    local startingZone = progression.getStartingZone()
    local accessible = {}

    if zoneAccessMode == 2 then
        local unlocked = startingZone + progression.getProgressiveZoneAccessCount()
        for i = 1, math.min(unlocked, #ev.zones) do
            accessible[ev.zones[i]] = true
        end
    else
        for _, zone in ipairs(ev.zones) do
            if zone == startingZone or progression.hasZoneAccess(zone) then
                accessible[zone] = true
            end
        end
    end

    local storyZoneUnlocked = false
    for _, proto in ipairs(ev.characterPrototypes or {}) do
        if proto.traitStoryBosses and accessible[proto.traitStoryBosses.zone] then
            storyZoneUnlocked = true
            break
        end
    end
    if not storyZoneUnlocked then
        ev.storyBossMode = proceduralRun.StoryBossMode.NO_STORY_BOSSES
    end

    local newZones = {}
    for _, z in ipairs(ev.zones) do
        if accessible[z] then
            table.insert(newZones, z)
        end
    end
    ev.zones = newZones

    local newSeq = {}
    for _, s in ipairs(ev.sequence) do
        if accessible[s.zone] then
            table.insert(newSeq, s)
        end
    end
    ev.sequence = newSeq
end)

event.levelLoad.add("apAssignCharacterHealth", { order = "characterOverrides", sequence = 1 }, function()
    if not apUtils.isAPContext() then return end

    if currentLevel.getSequentialNumber() == 1 then
        for _, entity in ipairs(player.getPlayerEntities()) do
            apCharacters.setAPHealth(entity)
        end
    end
end)

-- Adding more diamond tiles to the level
event.levelLoad.add("addDiamondTiles", { order = "tileMap" }, function(ev)
    if not apUtils.isAPContext() or ev.boss ~= 0 then return end

    local dirtIndices = {}
    local diamondIndices = {}
    local goldVariants = {}

    -- Scan through all tile names and track by tileset
    for i, name in ipairs(ev.tileMapping.tileNames) do
        local tileset = ev.tileMapping.tilesets[i]
        if name == "DirtWall" then
            table.insert(dirtIndices, { index = i, tileset = tileset })
        elseif name == "DirtWallWithGold" then
            -- Replace with Diamonds in-place
            ev.tileMapping.tileNames[i] = "DirtWallWithAPDiamonds"
            diamondIndices[tileset] = i
        end
    end

    -- For each tileset where no "DirtWallWithGold" was found, insert Diamonds manually
    for _, dirt in ipairs(dirtIndices) do
        if not diamondIndices[dirt.tileset] then
            table.insert(ev.tileMapping.tileNames, "DirtWallWithAPDiamonds")
            table.insert(ev.tileMapping.tilesets, dirt.tileset)
            diamondIndices[dirt.tileset] = #ev.tileMapping.tileNames
        end
    end

    -- Use primary/first player's character for seed modifier
    local playerEntities = player.getPlayerEntities()
    if #playerEntities == 0 then return end
    local character = apCharacters.cotNDCharToAPLocation(playerEntities[1].name)

    local channel = rng.makeChannel(ev.seed or 0,
        (ev.depth or 0) * 4344 + (ev.floor or 0) * 4340 + (ev.zone or 0), 9996)

    local modifier = character == "Monk" and 2 or 1

    -- Now process every tile in every segment
    for _, segment in ipairs(ev.segments) do
        for i, value in ipairs(segment.tiles) do
            -- Check against all dirt variants
            for _, dirt in ipairs(dirtIndices) do
                if value == dirt.index then
                    local random = rng.range(1, 100, channel)
                    if random <= modifier then
                        segment.tiles[i] = diamondIndices[dirt.tileset]
                    end
                    break
                end
            end
        end
    end
end)

event.objectTryCollectItem.add("pickupAPCurrency", { order = "checkItem" }, function(ev)
    if not apUtils.isAPContext(ev.entity) then return end
    if ev.item.AP_shopItem and ev.item.AP_shopItem.slot ~= 0 then return end
    if ev.item.itemCurrency and ev.item.itemCurrency.currencyType == apFlags.CURRENCY_AP_DIAMOND then
        -- saveData sits outside the snapshot, so a replayed pickup banks twice.
        if apReplay.firstThisTurn("diamond:" .. ev.item.id) then
            progression.changeDiamonds(ev.item.itemStack.quantity)
        end
    end
end)

event.objectDeath.add("apDeathlinkTrigger", { order = "kill", sequence = 1, filter = "controllable" },
    function(ev)
        if ev.entity.controllable.playerID == 0 or instantReplay.isActive() or replayPlayer.isActive() or gameSession.hasPendingTransition() then return end
        if not apCharacters.isCharacter(ev.entity.name) then return end
        if (apClient.isConnected() and progression.getDeathlink() and ev.damageType ~= apFlags.DAMAGE_DEATH_LINK and (ev.killerName or (ev.attacker and ev.attacker.friendlyName.name))) then
            if progression.getDeathlinkTrigger() == "Game Over" and player.getLiveCount() > 1 then
                return
            end
            local killerName = ev.killerName or ev.attacker.friendlyName.name
            apClient.sendDeathlink(progression.getPlayerName() .. " was killed by " .. killerName .. ".")
        end
    end)

event.getIntroText.add("apText", { order = "modsEnabled", sequence = 1 }, function(ev)
    if not apUtils.isAPContext() then return end

    ev.text = "AP Mode!\nComplete zones to make\nprogress for your multiworld!"
end)

event.tick.add("apConnectionLostMidrun", "periodicCheck", function()
    if not apUtils.isAPContext() then return end
    -- Session-wide: a non-host never holds the socket, so isConnected() alone
    -- would pause them permanently.
    if apClient.isSessionConnected() then return end
    if menu.getName() == "Archipelago_MidRun_Connect" then return end

    stateControl.pause()
    menu.open("Archipelago_MidRun_Connect")
end)
