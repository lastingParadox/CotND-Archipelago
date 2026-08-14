local action = require("necro.game.system.Action")
local clientActionBuffer = require("necro.client.ClientActionBuffer")
local collision = require("necro.game.tile.Collision")
local consumable = require "necro.game.item.Consumable"
local currency = require "necro.game.item.Currency"
local currentLevel = require "necro.game.level.CurrentLevel"
local cutscene = require "necro.client.Cutscene"
local ecs = require "system.game.Entities"
local gameSession = require "necro.client.GameSession"
local gameState = require "necro.client.GameState"
local instantReplay = require "necro.client.replay.InstantReplay"
local inventory = require "necro.game.item.Inventory"
local object = require("necro.game.object.Object")
local player = require "necro.game.character.Player"
local playerList = require "necro.client.PlayerList"
local replayPlayer = require "necro.client.replay.ReplayPlayer"
local sound = require("necro.audio.Sound")
local visualUpdate = require "necro.cycles.VisualUpdate"
local worldLabel = require "necro.game.system.WorldLabel"
local winScreen = require "necro.render.WinScreen"

local apBuffItem = require("AP.scripts.items.apBuffItem")
local apChatBadge = require("AP.scripts.ui.apChatBadge")
local apClient = require("AP.scripts.client.client")
local apCharacters = require("AP.scripts.utils.apCharacters")
local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apInventory = require("AP.scripts.utils.apInventory")
local apItems = require("AP.scripts.utils.apItems")
local apShrines = require("AP.scripts.entities.apShrines")
local apUtils = require("AP.scripts.utils.apUtils")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")
local progression = require("AP.scripts.client.progression")
local trapHandler = require("AP.scripts.traps.trapHandler")

defferredItems = {}

local AP_ITEM_ACTION = action.System.extend("AP_ITEM")

local function isLobbyUpgrade(itemId)
    local proto = itemId and ecs.getEntityPrototype(itemId)
    return proto ~= nil and proto.itemLobbyProgressionUnlock ~= nil
end

local function generateRadialOffsets(maxRadius)
    local offsets = {}

    -- center first
    table.insert(offsets, { 0, 0 })

    for r = 1, maxRadius do
        -- cardinals
        table.insert(offsets, { -r, 0 })
        table.insert(offsets, { r, 0 })
        table.insert(offsets, { 0, -r })
        table.insert(offsets, { 0, r })

        -- diagonals
        table.insert(offsets, { -r, -r })
        table.insert(offsets, { -r, r })
        table.insert(offsets, { r, -r })
        table.insert(offsets, { r, r })

        -- edges between
        for i = 1, r - 1 do
            table.insert(offsets, { -r, -i })
            table.insert(offsets, { -r, i })
            table.insert(offsets, { r, -i })
            table.insert(offsets, { r, i })

            table.insert(offsets, { -i, -r })
            table.insert(offsets, { i, -r })
            table.insert(offsets, { -i, r })
            table.insert(offsets, { i, r })
        end
    end

    return offsets
end

radialOffsets = generateRadialOffsets(20)

local function canProcessItems()
    -- Don't spawn items on winScreen
    if winScreen.isActive() then return false end
    -- Don't spawn items during cutscenes
    if cutscene.isActive() then return false end
    -- Don't spawn items during instantReplay
    if instantReplay.isActive() or replayPlayer.isActive() then return false end
    -- If the current level is loading, defer until finished.
    if currentLevel.isLoading() then return false end

    -- Check all local players
    for _, playerEntity in ipairs(player.getPlayerEntities()) do
        if playerEntity and not playerEntity.descent.active then
            return true
        end
    end

    return false
end

local getAcquireVerb = function(itemId)
    if apCharacters.isCharacter(itemId) or apCharacters.isNPC(itemId) then
        return L("found", "ap.found")
    end

    return L("acquired", "ap.acquired")
end

-- Location -1 is a server grant (!getitem, /send), -2 a starting inventory item.
local function getReceivedMessage(item)
    local locationCode = tonumber(item.location_code)
    if locationCode == -1 then
        return "The server sent you " .. item.item_name
    elseif locationCode == -2 then
        return "You started with " .. item.item_name
    elseif item.playername == apStorage.playerName then
        return "You found your " .. item.item_name
    end
    return item.playername .. " found your " .. item.item_name
end

local function grantGold(amount)
    -- A shared pool ignores the entity, so paying per player pays once per head.
    if currency.isShared(currency.Type.GOLD) then
        currency.add(nil, currency.Type.GOLD, amount)
        return
    end

    local entities = player.getPlayerEntities()
    if currentLevel.isLobby() then
        entities = { entities[1] }
    end

    for _, entity in ipairs(entities) do
        if entity then currency.add(entity, currency.Type.GOLD, amount) end
    end
end

local function handleAPItem(itemName, playerEntity, silent)
    local map = {
        APInstantGold     = { sound = "pickupGold", handler = function() grantGold(50) end },
        APInstantGold2    = { sound = "pickupGold", handler = function() grantGold(200) end },
        -- changeDiamonds mirrors the new balance onto every player entity.
        APDiamond1        = { sound = "pickupDiamond", handler = function() progression.changeDiamonds(1) end },
        APDiamond2        = { sound = "pickupDiamond", handler = function() progression.changeDiamonds(2) end },
        APDiamond3        = { sound = "pickupDiamond", handler = function() progression.changeDiamonds(3) end },
        APDiamond4        = { sound = "pickupDiamond", handler = function() progression.changeDiamonds(4) end },
        APFullHeal        = {
            sound = nil,
            handler = function()
                local obj = object.spawn("AP_FullHeal")
                inventory.add(obj, playerEntity)
                consumable.consume(obj, 1, playerEntity)
            end
        },

        APNoReturnMode    = { sound = "shrineActivate", handler = function() progression.enableExtraMode("No Return") end },
        APHardMode        = { sound = "shrineActivate", handler = function() progression.enableExtraMode("Hard") end },
        APPhasingMode     = { sound = "shrineActivate", handler = function() progression.enableExtraMode("Phasing") end },
        APRandomizerMode  = { sound = "shrineActivate", handler = function() progression.enableExtraMode("Randomizer") end },
        APMysteryMode     = { sound = "shrineActivate", handler = function() progression.enableExtraMode("Mystery") end },
        APNoBeatMode      = { sound = "shrineActivate", handler = function() progression.enableExtraMode("No Beat") end },
        APDoubleTempoMode = { sound = "shrineActivate", handler = function() progression.enableExtraMode("Double Tempo") end },
        APLowPercentMode  = { sound = "shrineActivate", handler = function() progression.enableExtraMode("Low Percent") end },

        APShopStock       = {
            sound = "pickupGeneral",
            handler = function()
                progression.addShopStock(1)
            end
        },

        APZone1Access         = { sound = "shrineActivate", handler = function() progression.addZoneAccess(1) if currentLevel.isLobby() then visualUpdate.trigger() end end },
        APZone2Access         = { sound = "shrineActivate", handler = function() progression.addZoneAccess(2) if currentLevel.isLobby() then visualUpdate.trigger() end end },
        APZone3Access         = { sound = "shrineActivate", handler = function() progression.addZoneAccess(3) if currentLevel.isLobby() then visualUpdate.trigger() end end },
        APZone4Access         = { sound = "shrineActivate", handler = function() progression.addZoneAccess(4) if currentLevel.isLobby() then visualUpdate.trigger() end end },
        APZone5Access         = { sound = "shrineActivate", handler = function() progression.addZoneAccess(5) if currentLevel.isLobby() then visualUpdate.trigger() end end },
        APProgressiveZoneAccess = { sound = "shrineActivate", handler = function() progression.addProgressiveZoneAccess() if currentLevel.isLobby() then visualUpdate.trigger() end end },
        -- Tier count is read from the item log; this only refreshes the selector.
        APProgressivePotions      = { sound = "shrineActivate", handler = function() if currentLevel.isLobby() then visualUpdate.trigger() worldLabel.updateAll() end end },
        APCharRoomKey         = { sound = "shrineActivate", handler = function() progression.unlockCharacterRoom() if currentLevel.isLobby() then visualUpdate.trigger() end end },
        APGoldenLuteShard     = {
            sound = "pickupGeneral",
            handler = function()
                apStorage.saveData.goldenLuteShards = (apStorage.saveData.goldenLuteShards or 0) + 1
                progression.calculateGoalCompletion(true)
                if currentLevel.isLobby() then visualUpdate.trigger() end
            end
        },
    }

    for _, buff in ipairs(apBuffItem.buffs) do
        map[buff.entity] = {
            sound = "shrineActivate",
            handler = function()
                progression.unlockBuffItem(buff.character)
            end
        }
    end

    if map[itemName] then
        local obj = map[itemName]
        if obj.sound and not silent then sound.playFromEntity(obj.sound, playerEntity) end
        map[itemName].handler()
    end
end

local function handleItemAcquisition(item, silent)
    if not item then return end

    local itemId = item.item
    local displayName = item.item_name
    local playerEntities = player.getPlayerEntities()

    -- Notify in chat who found this item.
    if not silent then
        apChatBadge.addMessage(getReceivedMessage(item))
    end

    -- Show flyaway to all players
    if not silent and not apItems.isOwnShopItem(item, apStorage.playerName) then
        if not apItems.isTrapItem(itemId) then
            local verb = (item.playername ~= progression.getPlayerName()) and L("received", "ap.received") or
                getAcquireVerb(itemId)

            for _, playerEntity in ipairs(playerEntities) do
                if playerEntity then
                    apFlyaways.addToFlyawayQueue({
                        entity = playerEntity,
                        text = displayName .. " " .. verb,
                    })
                end
            end
        else
            if gameState.isInLobby() or apItems.isOwnShopItem(item, apStorage.playerName) then
                for _, playerEntity in ipairs(playerEntities) do
                    if playerEntity then
                        apFlyaways.addToFlyawayQueue({
                            entity = playerEntity,
                            text = "Something seems off..."
                        })
                    end
                end
            end
        end
    end

    -- Handle permanent hearts for all players
    if itemId == "PermHeart2" then
        apLog("Acquiring permanent heart")
        for _, playerEntity in ipairs(playerEntities) do
            if playerEntity and playerEntity.healthLimit.limit ~= 1 then
                playerEntity.health.health = playerEntity.health.health + 2
                playerEntity.health.maxHealth = playerEntity.health.maxHealth + 2
            end
        end
        progression.addHealth(2)
        return
    end

    -- Lobby upgrades: the chest ones are read at level load, the coin multipliers
    -- are equipped with the starting inventory. Neither drops as a floor item.
    if isLobbyUpgrade(itemId) then
        apLog("Acquiring lobby upgrade: " .. itemId)
        for _, playerEntity in ipairs(playerEntities) do
            apInventory.grantAPInnateItems(playerEntity, progression)
        end
        if currentLevel.isLobby() then visualUpdate.trigger() end
        return
    end

    if apItems.isTrapItem(itemId) then
        apLog("Queuing trap: " .. itemId)
        trapHandler.queueTrap(itemId)
        return
    end

    -- Handle AP special items (progression-wide)
    if apItems.apItemsList[itemId] then
        apLog("Handling AP special item: " .. itemId)
        -- Use first player for handlers that need a player entity
        -- Own shop-purchased items are silent: the physical pickup already played the sound.
        local isOwnShop = apItems.isOwnShopItem(item, apStorage.playerName)
        if #playerEntities > 0 then
            handleAPItem(itemId, playerEntities[1], silent or isOwnShop)
        end
        return
    end

    -- We don't want to spawn a physical character or NPC, but we can play a sound.
    if apCharacters.isCharacter(itemId) and not silent then
        local soundName = string.lower(itemId) .. "Hi"
        if (string.sub(itemId, 1, 5) == "Sync_") then
            soundName = string.sub(soundName, 6)
        elseif (string.sub(itemId, 1, 10) == "Coldsteel_") then
            soundName = "Coldsteel_MikuHi"
        elseif (string.sub(itemId, 1, 8) == "Goldman_") then
            soundName = "Goldman_GoldmanHi"
        end
        for _, playerEntity in ipairs(playerEntities) do
            if playerEntity then
                sound.playFromEntity(soundName, playerEntity)
            end
        end
        if currentLevel.isLobby() then visualUpdate.trigger() worldLabel.updateAll() end
        return
    elseif apCharacters.isNPC(itemId) then
        if not silent then
            for _, playerEntity in ipairs(playerEntities) do
                if playerEntity then
                    local playSound = (playerEntity.voiceGreeting and playerEntity.voiceGreeting.sound) or nil
                    if (not playSound) then playSound = "doorOpen" end
                    sound.playFromEntity(playSound, playerEntity)
                end
            end
        end
        if currentLevel.isLobby() then visualUpdate.trigger() worldLabel.updateAll() end
        return
    end

    -- Spawning the entity would drop an activatable shrine at the player's feet.
    if apShrines.SHRINE_LOCATIONS[itemId] then
        if currentLevel.isLobby() then visualUpdate.trigger() end
        return
    end

    -- Spawn physical item in AP modes (not during win screen) for all players
    if apUtils.isAPContext() and not winScreen.isActive() then
        -- Whoever opened the chest already walked off with this; only the others
        -- still need a copy.
        local consumed = apStorage.saveData.chestConsumedLocations or {}
        local collector = consumed[tostring(item.location_code)]
        local spawned = false

        for _, playerEntity in ipairs(playerEntities) do
            if playerEntity and playerEntity.id ~= collector then
                object.moveToNearbyVacantTile(object.spawn(itemId, playerEntity.position.x, playerEntity.position.y + 1),
                    collision.Group.ITEM_PLACEMENT, 0, radialOffsets)
                spawned = true
            end
        end

        if spawned then
            sound.play("secretFound", playerEntities[1].position.x, playerEntities[1].position.y + 1)
            visualUpdate.trigger()
        end
    end
end

local function handleItem(item, silent)
    local itemId = item.item
    local locationCode = tonumber(item.location_code)
    local apIndex = item.ap_index

    apStorage.ensureSaveDataTables()

    -- Universal dedup: every item has a unique ap_index
    if apIndex ~= nil then
        local indexKey = tostring(apIndex)
        if apStorage.saveData.receivedItems[indexKey] then
            apLog("Skipping already processed item at ap_index " .. indexKey .. ": " .. tostring(itemId))
            goto continue
        end
    else
        -- No ap_index means we can't deduplicate safely; skip
        apLog("Skipping item with no ap_index: " .. itemId)
        goto continue
    end

    -- Startup progressive zone access items are not counted; startingZone already accounts for them.
    if locationCode == -2 and itemId == "APProgressiveZoneAccess" then goto continue end

    -- Store the item as a rich object keyed by ap_index
    local entry = {
        item = itemId,
        locationCode = item.location_code,
        playername = item.playername,
    }

    if apCharacters.isCharacter(itemId) then
        entry.itemType = "character"
        entry.charId = apCharacters.cotNDCharToAPLocation(itemId)
        progression.markCharacterUnlocked(entry.charId)
        apLog("Character unlocked: " .. itemId)

        if not progression.getStartingCharacter() then
            progression.setStartingCharacter(entry.charId)
        end
    elseif not apItems.apItemsList[itemId] then
        entry.itemType = "item"
        progression.markItemReceived(itemId)
    else
        entry.itemType = "ap_special"
    end

    progression.markReceivedCount(itemId)
    apStorage.saveData.receivedItems[tostring(apIndex)] = entry

    apLog("Acquiring item: " .. itemId)

    -- Add item to queue for acquisition
    table.insert(defferredItems, { item = item, silent = silent })

    ::continue::
end

local function processItems(items, silent)
    for i = 1, #items do
        handleItem(items[i], silent)
    end
end

local lastQueued = { bufferID = nil, turnID = nil }

local function nextQueueableTurnID(playerID)
    local bufferID = clientActionBuffer.getCurrentBufferID()
    if lastQueued.bufferID ~= bufferID then
        lastQueued.bufferID = bufferID
        lastQueued.turnID = nil
    end

    local firstTurnID = clientActionBuffer.getTargetTurnID() + 1
    if lastQueued.turnID and lastQueued.turnID >= firstTurnID then
        firstTurnID = lastQueued.turnID + 1
    end

    local turnID = clientActionBuffer.findAvailableTurnID(playerID, firstTurnID)
    lastQueued.turnID = turnID
    return turnID
end

handlers.register("Items", function(message)
    local items = message.items
    processItems(items)

    if message.location_hint_amounts then
        apStorage.saveData.locationHints = message.location_hint_amounts
    end
end)

event.tick.add("apProcessQueuedItems", { order = "lobby", sequence = 3 }, function()
    -- Only the host has the socket, so the item rides a system action to reach
    -- every client on the same turn.
    if apUtils.isNetworked() then
        if #defferredItems > 0 and apClient.isHost() and canProcessItems() then
            -- One action for the batch: the buffer rejects a second on the same turn.
            local items = {}
            for _, entry in ipairs(defferredItems) do
                items[#items + 1] = { item = entry.item, silent = entry.silent }
            end

            local playerID = playerList.getLocalPlayerID()
            local turnID = nextQueueableTurnID(playerID)
            if turnID then
                clientActionBuffer.addAction(playerID, turnID, AP_ITEM_ACTION, 0, { items = items })
                defferredItems = {}
            end
        end
        return
    end

    if #defferredItems == 0 then return end
    if not apClient.isConnected() and currentLevel.isLobby() then
        defferredItems = {}
        return
    end

    if canProcessItems() then
        apLog("Handling item acquisition for " .. #defferredItems .. " items")
        for _, entry in ipairs(defferredItems) do
            handleItemAcquisition(entry.item, entry.silent)
        end
        defferredItems = {}
        visualUpdate.trigger()
    end
end)

-- Payload travels in the action so no client acts on data it has not received.
event.turn.add("apDeliverItemActions", "customActions", function(ev)
    local actions = ev.actionMap[AP_ITEM_ACTION]
    if not actions then return end

    for _, actionData in ipairs(actions) do
        local args = actionData.args
        for _, entry in ipairs(args and args.items or {}) do
            -- event.turn swallows errors, which would drop the rest of the batch.
            local ok, err = pcall(handleItemAcquisition, entry.item, entry.silent)
            if not ok then
                log.error("Failed to deliver AP item %s: %s",
                    tostring(entry.item and entry.item.item), tostring(err))
            end
        end
    end

    visualUpdate.trigger()
end)

return {
    handleItems = processItems
}
