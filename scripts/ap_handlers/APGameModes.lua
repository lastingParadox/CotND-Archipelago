local currency = require "necro.game.item.Currency"
local Event = require("necro.event.Event")
local CurrentLevel = require("necro.game.level.CurrentLevel")
local Enum = require("system.utils.Enum")
local LevelLoader = require "necro.game.level.LevelLoader"
local GameSession = require "necro.client.GameSession"
local gameState = require("necro.client.GameState")
local TileTypes = require "necro.game.tile.TileTypes"
local Random = require "system.utils.Random"
local Player = require("necro.game.character.Player")
local PlayerList = require("necro.client.PlayerList")
local APConnection = require("AP.scripts.ap_handlers.APConnection")
local ItemGen = require "necro.game.item.ItemGeneration"
local extraMode = require "necro.game.data.modifier.ExtraMode"

local apConnection = require("AP.scripts.ap_handlers.APConnection")
local apItems = require("AP.scripts.ap_handlers.APItems")
local apShops = require("AP.scripts.rooms.AP_Shops")
local apUtils = require("AP.scripts.ap_handlers.APUtils")

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

GameSession.Mode.extend(
    "APAllZones",
    Enum.data({
        id = "APAllZones",
        name = "AP All Zones",
        visible = false,
        bossFlawless = true,
        cutscenes = false,
        diamondCounter = true,
        extraEnemiesPerFloor = 3,
        generatorOptions = {
            type = "Necro",
        },
        introText = true,
        multiCharEnabled = true,
        progressionUnlockCharacters = false,
        resetDiamonds = false,
        resetTimeScale = true,
        statisticsEnabled = true,
        statisticsTrackHardcoreClears = true,
        timerHUD = true,
        timerName = "Speedrun",
    })
)

GameSession.Mode.extend(
    "APSingleZone",
    Enum.data({
        id = "APSingleZone",
        name = "AP Single Zone",
        cutscenes = true,
        depthPriceMultiplier = false,
        diamondCounter = true,
        diamondHoards = true,
        generatorOptions = {
            type = "Necro",
            procedural = {
                singleZone = true,
            },
        },
        multiCharEnabled = true,
        progressionClearGrants = false,
        progressionEnabled = true,
        progressionUnlockCharacters = false,
        resetDiamonds = false,
        seedHUD = false,
        statisticsEnabled = true,
        statisticsIgnoreLeaderboardConditions = true,
        visible = false,
    })
)

-- Generation
Event.levelLoad.add("addDiamondTiles", { order = "tileMap" }, function(ev)
    local mode = GameSession.getCurrentMode().id

    local dirtWallIndex
    local diamondWallIndex

    if mode == "APAllZones" or mode == "APSingleZone" then
        for i, name in ipairs(ev.tileMapping.tileNames) do
            if name == "DirtWall" then
                dirtWallIndex = i
            elseif name == "DirtWallWithGold" then
                diamondWallIndex = i
                ev.tileMapping.tileNames[i] = "DirtWallWithDiamonds"
                break -- optional: only replace the first match
            end
        end
        -- Increase the amount of diamond walls in the AP levels
        math.randomseed(CurrentLevel.getSeed())
        for i, value in ipairs(ev.segments[1].tiles) do
            if value == dirtWallIndex then
                if math.random(1, 100) <= 1 then ev.segments[1].tiles[i] = diamondWallIndex end
            end
        end
    end
end)

-- Banlist
Event.levelLoad.add("updateSeenCounts", { order = "currentLevel" }, function(ev)
    local mode = GameSession.getCurrentMode().id
    if not ((mode == "APAllZones" or mode == "APSingleZone") and APConnection.connected and next(APConnection.saveData.items) ~= nil) then return end
    for name, value in pairs(apItems.allItemsList) do
        if APConnection.saveData.items[name] == true then
            if ItemGen.getSeenCount(name) >= 99 then
                ItemGen.markSeen(name, -ItemGen.getSeenCount(name))
            end
        else
            if ItemGen.getSeenCount(name) < 99 then
                ItemGen.markSeen(name, 99)
            end
        end
    end
end)

Event.levelComplete.add("apLevelComplete", { order = "winScreen" }, function(ev)
    local mode = GameSession.getCurrentMode().id

    if not ((mode == "APAllZones" or mode == "APSingleZone") and APConnection.connected) then return end

    local playerID = PlayerList.getLocalPlayerID()
    local character = Player.getPlayerEntity(playerID).name

    if not (CurrentLevel.isBoss() or (character == "Dove" and CurrentLevel.getFloor() == 3)) then return end

    local zones = { "Zone " .. CurrentLevel.getZone() }

    if mode == "APAllZones" and CurrentLevel.isRunFinal() then
        table.insert(zones, "All Zones")

        for key, name in pairs(supportedModes) do
            print("Checking mode:", key, name, extraMode.isActive(key))
            if extraMode.isActive(key) then
                table.insert(zones, name .. " Mode")
            end
        end
    end

    local charLocs = APConnection.saveData.characterLocations or {}
    local charData = charLocs[character] or {}

    for _, level in ipairs(zones) do
        if charData[level] == false then
            if APConnection.outputData["Location"] == nil then
                APConnection.outputData["Location"] = {}
            end
            table.insert(APConnection.outputData["Location"], character .. " - " .. level)
            charData[level] = true
        end
    end
end)

event.objectTryCollectItem.add("pickupAPCurrency", { order = "checkItem" }, function(ev)
    local mode = GameSession.getCurrentMode().id

    if (gameState.isInLobby() and not apUtils.isInLobby(ev.entity)) then
        return
    elseif not gameState.isInLobby() and not ((mode == "APAllZones" or mode == "APSingleZone") and APConnection.connected) then
        return
    end

    if ev.item.itemCurrency and ev.item.itemCurrency.currencyType == currency.Type.DIAMOND then
        apConnection.changeDiamonds(ev.item.itemStack.quantity)
    end
end)
