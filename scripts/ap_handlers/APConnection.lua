local currency = require "necro.game.item.Currency"
local object = require("necro.game.object.Object")
local winScreen = require "necro.render.WinScreen"
local gameSession = require "necro.client.GameSession"
local playerList = require "necro.client.PlayerList"
local player = require "necro.game.character.Player"
local flyaway = require "necro.game.system.Flyaway"
local inventory = require "necro.game.item.Inventory"
local json = require("system.utils.serial.JSON")
local timer = require("system.utils.Timer")
local event = require("necro.event.Event")
local hasStorage, storage = pcall(require, "system.file.Storage")
local ecs = require("system.game.Entities")
local damage = require("necro.game.system.Damage")
local chat = require("necro.client.Chat")
local sound = require("necro.audio.Sound")
local apUtils = require("AP.scripts.ap_handlers.APUtils")

local apItems = require("AP.scripts.ap_handlers.APItems")
local apGeneration = require("AP.scripts.ap_handlers.APGeneration")

-- Constants
local MessageTypes = {
    STATE = "State",
    ITEMS = "Items",
    LOCATIONS = "Locations",
    DEATH = "Death",
    SETDEATHLINK = "SetDeathLink",
    DISCONNECTED = "Disconnected",
    LOCATION_INFO = "LocationInfo",
    BOUNCE = "Bounce",
}

-- APConnection Module
local APConnection = {
    saveData = {},
    outputData = {},
    connected = false,
    connection = { status = "Disconnected", timestamp = 0 },
    handlers = {},
    updateSave = false,
    storage = {}
}

-- Config
local infile = "in.log"
local outfile = "out.log"
local bounce_sent = false
local saveStorage = ""
local last_mod_update = 0
local latest_client_timestamp = 0
local last_message_received = 0
local disconnect_timeout = 10
local seed = ""
local slot_name = ""
local deathlinkPending = false
local deathlinkMessage = ""

function APConnection.connect()
    if not APConnection.connected then
        APConnection.outputData = { ModStart = true }
        APConnection.writeData()
        APConnection.connection.timestamp = timer.unixTimestamp()
        apGeneration.setShopsPopulated(false)
        APConnection.connection.status = "Connecting"
    else
        APConnection.connection.status = "Connected"
        return true
    end
end

-- Handlers
APConnection.handlers[MessageTypes.STATE] = function(entry)
    if not APConnection.saveData.seedName then
        APConnection.saveData = {
            seedName = seed,
            slotName = slot_name,
            goal = entry.goal,
            deathlink = entry.deathlink or false,
            -- Set from { "No Return", "Hard", ... } to { ["No Return"] = false, ["Hard"] = false, ... }
            extraModes = (function()
                local t = {}
                for _, mode in ipairs(entry.extra_modes or {}) do
                    t[mode] = false
                end
                return t
            end)(),
            diamonds = 0,
            health = 6,
            items = {},
            checkCodeCache = {},
            characters = {},
            characterLocations = {},
            pricing = {
                type = entry.pricing.type or apUtils.PriceRandomizationType.VANILLA,
                general = entry.pricing.general_price_range,
                filler = entry.pricing.filler_price_range,
                useful = entry.pricing.useful_price_range,
                progression = entry.pricing.progression_price_range,
            },
            shopLocations = {
                Hephaestus = {
                    Left = { Slots = {} },
                    Center = { Slots = {} },
                    Right = { Slots = {} },
                },
                Merlin = {
                    Left = { Slots = {} },
                    Center = { Slots = {} },
                    Right = { Slots = {} },
                },
                ["Dungeon Master"] = {
                    Left = { Slots = {} },
                    Center = { Slots = {} },
                    Right = { Slots = {} },
                },
            },
            scoutedLocations = false,
        }
        APConnection.updateSave = true
    else
        local changed = false
        if APConnection.saveData.deathlink ~= (entry.deathlink or false) then
            APConnection.saveData.deathlink = entry.deathlink or false
            changed = true
        end

        if changed then
            APConnection.updateSave = true
        end
    end
    APConnection.connected = true
end

APConnection.handleItemAcquisition = function(item)
    local playerID = playerList.getLocalPlayerID()
    local playerEntity = player.getPlayerEntity(playerID)
    local itemId = item.item
    local displayName = item.item_name

    -- Only show the flyaway message if the item is not from the current player
    if not (apItems.isOwnShopItem(item, APConnection.saveData.slotName)) then
        flyaway.create({
            text = displayName .. " " .. L("received", "ap.received"),
            entity = playerEntity,
        })
    end

    if apItems.apItemsList[itemId] then
        APConnection.handleAPItem(itemId, playerEntity)
        return
    end

    local mode = gameSession.getCurrentMode().id
    if (mode == "APAllZones" or mode == "APSingleZone") and not winScreen.isActive() then
        object.spawn(itemId, playerEntity.position.x, playerEntity.position.y + 1)
        sound.play("secretFound", playerEntity.position.x, playerEntity.position.y + 1)
    end
end

function APConnection.handleAPItem(itemName, playerEntity)
    local map = {
        APInstantGold = function() currency.add(playerEntity, currency.Type.GOLD, 50) end,
        APInstantGold2 = function() currency.add(playerEntity, currency.Type.GOLD, 200) end,
        APDiamond1 = function()
            currency.add(playerEntity, currency.Type.DIAMOND, 1, nil)
            APConnection.changeDiamonds(1)
        end,
        APDiamond2 = function()
            currency.add(playerEntity, currency.Type.DIAMOND, 2, nil)
            APConnection.changeDiamonds(2)
        end,
        APDiamond3 = function()
            currency.add(playerEntity, currency.Type.DIAMOND, 3, nil)
            APConnection.changeDiamonds(3)
        end,
        APDiamond4 = function()
            currency.add(playerEntity, currency.Type.DIAMOND, 4, nil)
            APConnection.changeDiamonds(4)
        end,
        APFullHeal = function()
            inventory.add(
                object.spawn("AP_FullHeal"), playerEntity)
        end,
        APNoReturnMode = function() APConnection.enableExtraMode("No Return") end,
        APHardMode = function() APConnection.enableExtraMode("Hard") end,
        APPhasingMode = function() APConnection.enableExtraMode("Phasing") end,
        APRandomizerMode = function() APConnection.enableExtraMode("Randomizer") end,
        APMysteryMode = function() APConnection.enableExtraMode("Mystery") end,
        APNoBeatMode = function() APConnection.enableExtraMode("No Beat") end,
        APDoubleTempoMode = function() APConnection.enableExtraMode("Double Tempo") end,
        APLowPercentMode = function() APConnection.enableExtraMode("Low Percent") end,
    }

    return map[itemName] and map[itemName]() or nil
end

APConnection.handlers[MessageTypes.ITEMS] = function(entry)
    for _, item in ipairs(entry.items) do
        local itemId = item.item

        -- Skip if the item is already collected
        if APConnection.saveData.checkCodeCache[item.location_code] and tonumber(item.location_code) > 0 then
            goto continue
        elseif tonumber(item.location_code) > 0 then
            APConnection.addCheckToCollectedCache(item.location_code)
        end

        if apUtils.isCharacter(itemId) then
            APConnection.saveData.characters[itemId] = true
        else
            if not apItems.apItemsList[itemId] then
                APConnection.saveData.items[itemId] = true
            end

            APConnection.handleItemAcquisition(item)
        end

        ::continue::
    end
    APConnection.updateSave = true
end

APConnection.handlers[MessageTypes.LOCATIONS] = function(entry)
    if entry.missing_locations then
        apUtils.parseMissingLocations(APConnection.saveData, entry.missing_locations)
    end

    if entry.checked_locations then
        apUtils.updateLocations(APConnection.saveData, entry.checked_locations)
    end
end

APConnection.handlers[MessageTypes.DEATH] = function(entry)
    deathlinkPending = true
    deathlinkMessage = entry.source or entry.msg or "Archipelago"
end

APConnection.handlers[MessageTypes.DISCONNECTED] = function(entry)
    APConnection.connected = false
    APConnection.connection.status = "Disconnected"
    bounce_sent = false
    APConnection.initFiles()
end

APConnection.handlers[MessageTypes.SETDEATHLINK] = function(entry)
    APConnection.saveData.deathlink = entry.deathlink or false
    APConnection.updateSave = true
end

APConnection.handlers[MessageTypes.BOUNCE] = function(entry)
    if entry.bounceType == "Chat" then
        chat.queueChat(entry.name .. ": " .. entry.message)
    elseif entry.bounceType == "SoundEffect" then
        sound.playSound(entry.sound)
    end
end

-- IO Helpers
function APConnection.loadSave()
    local data = APConnection.storage.readFile(saveStorage)
    if data and data ~= "" then
        return json.decode(data)
    end
    return {}
end

function APConnection.saveToFile()
    if APConnection.updateSave then
        APConnection.storage.writeFile(saveStorage, json.encode(APConnection.saveData))
        APConnection.updateSave = false
    end
end

function APConnection.writeData()
    local timestamp = timer.unixTimestamp()
    APConnection.outputData.timestamp = timestamp

    APConnection.storage.writeFile(outfile, json.encode(APConnection.outputData))
    APConnection.outputData = {}
end

function APConnection.enableExtraMode(mode)
    APConnection.saveData.extraModes[mode] = true
    APConnection.updateSave = true
end

function APConnection.changeDiamonds(amount)
    APConnection.saveData.diamonds = (APConnection.saveData.diamonds or 0) + amount
    APConnection.updateSave = true
end

function APConnection.sendDeathlink(message)
    APConnection.outputData["Death"] = { msg = message }
end

function APConnection.addLevelCompleteChecks(checksList, character)
    local charData = APConnection.saveData.characterLocations[character] or {}

    for _, level in ipairs(checksList) do
        if charData[level] == false then
            if APConnection.outputData["Location"] == nil then
                APConnection.outputData["Location"] = {}
            end
            table.insert(APConnection.outputData["Location"], character .. " - " .. level)
            charData[level] = true
        end
    end

    -- In the case this check causes the goal condition to be met
    APConnection.calculateGoalCompletion()

    APConnection.updateSave = true
end

function APConnection.calculateGoalCompletion()
    local goalAmount = APConnection.saveData.goal
    local characterLocations = APConnection.saveData.characterLocations
    local completedSum = 0

    for _, characterLocation in pairs(characterLocations) do
        if (characterLocation["All Zones"] == true) then completedSum = completedSum + 1 end
    end

    if completedSum >= goalAmount then
        APConnection.outputData["Victory"] = {}
    end
end

function APConnection.addCheckToCollectedCache(locCode)
    if locCode == nil or locCode == "" then
        return
    end

    if not APConnection.saveData.checkCodeCache[locCode] then
        APConnection.saveData.checkCodeCache[locCode] = true
        APConnection.updateSave = true
    end
end

function APConnection.applyDeathLink()
    for entity in ecs.entitiesWithComponents({ "playableCharacter" }) do
        damage.inflict({
            victim = entity,
            damage = 100,
            type = damage.Flag.AP_DEATH_LINK,
            killerName = deathlinkMessage,
        })
    end
    deathlinkPending = false
    deathlinkMessage = ""
end

function APConnection.initFiles()
    APConnection.storage.writeFile(infile, "")
    APConnection.storage.writeFile(outfile, "")
end

-- Core Logic
function APConnection.retrieveData()
    local msg = APConnection.storage.readFile(infile)
    if not msg or msg == "" then return end

    local decoded = json.decode(msg)
    if not decoded then return end

    seed = decoded.seed_name
    slot_name = decoded.slot_name
    latest_client_timestamp = decoded.timestamp

    if saveStorage == "" then
        saveStorage = seed .. "_" .. slot_name .. ".txt"
        APConnection.saveData = APConnection.loadSave()
    end

    for _, entry in ipairs(decoded.data or {}) do
        if entry.timestamp and entry.timestamp <= last_message_received then goto continue end
        last_message_received = entry.timestamp

        local handler = APConnection.handlers[entry.datatype]
        if handler then handler(entry) end

        ::continue::
    end

    if not APConnection.saveData.scoutedLocations then
        for _, entry in ipairs(decoded.data_lowpriority or {}) do
            if entry.datatype == MessageTypes.LOCATION_INFO then
                apUtils.scoutShopLocations(APConnection.saveData, entry.location_info)
                APConnection.updateSave = true
            end
        end
        APConnection.saveData.scoutedLocations = true
    end

    APConnection.saveToFile()
end

-- Periodic Event
event.tick.add("apUpdate", { order = "lobby", sequence = 1 }, function()
    if not APConnection.connected then return end

    -- We only want to update the client if enough time has passed since the last update
    if #APConnection.outputData == 0 and (timer.unixTimestamp() - last_mod_update < 1) then return end
    last_mod_update = timer.unixTimestamp()

    APConnection.writeData()
    APConnection.retrieveData()

    if deathlinkPending then
        APConnection.applyDeathLink()
    end

    if (last_mod_update - latest_client_timestamp >= 3 and last_mod_update - latest_client_timestamp < 5) then
        if not bounce_sent then
            APConnection.outputData["Bounce"] = {}
            bounce_sent = true
        end
    elseif last_mod_update - latest_client_timestamp >= 5 then
        APConnection.handlers[MessageTypes.DISCONNECTED]()
    else
        bounce_sent = false
    end
end)

event.tick.add("APConnectionCheck", { order = "lobby", sequence = 2 }, function()
    if APConnection.connection.status == "Connecting" then
        APConnection.retrieveData()
        if APConnection.connected then
            APConnection.connection.status = "Connected"
        elseif timer.unixTimestamp() - APConnection.connection.timestamp > 3 then
            APConnection.connection.status = "Disconnected"
        end
    end
end)


if hasStorage and not APConnection.connected then
    APConnection.storage = storage.new("archipelago")

    local clearLogs = false
    local infileContents = APConnection.storage.readFile(infile)

    if infileContents == nil or infileContents == "" then
        clearLogs = true
    else
        local parsed = json.decode(infileContents)
        if parsed and parsed.data then
            local allOlder = true
            local time = timer.unixTimestamp()
            for _, entry in ipairs(parsed.data) do
                if entry.timestamp >= (time - 180) then
                    allOlder = false
                    break
                end
            end
            clearLogs = allOlder
        else
            -- If parse failed or structure unexpected, assume it's not usable
            clearLogs = true
        end
    end

    if clearLogs then
        APConnection.initFiles()
    else
        APConnection.retrieveData()
    end

    APConnection.modInit = true
end

return APConnection
