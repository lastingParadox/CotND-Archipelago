local action = require("necro.game.system.Action")
local clientActionBuffer = require("necro.client.ClientActionBuffer")
local currentLevel = require "necro.game.level.CurrentLevel"
local cutscene = require "necro.client.Cutscene"
local gameSession = require "necro.client.GameSession"
local gameState = require "necro.client.GameState"
local instantReplay = require "necro.client.replay.InstantReplay"
local player = require "necro.game.character.Player"
local playerList = require "necro.client.PlayerList"
local replayPlayer = require "necro.client.replay.ReplayPlayer"
local sound = require("necro.audio.Sound")
local turn = require "necro.cycles.Turn"
local visualUpdate = require "necro.cycles.VisualUpdate"
local winScreen = require "necro.render.WinScreen"

local apGrants = require("AP.scripts.items.apGrants")
local apChatBadge = require("AP.scripts.ui.apChatBadge")
local apClient = require("AP.scripts.client.client")
local apCharacters = require("AP.scripts.utils.apCharacters")
local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apItems = require("AP.scripts.utils.apItems")
local apUtils = require("AP.scripts.utils.apUtils")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")
local progression = require("AP.scripts.client.progression")

defferredItems = {}

local AP_ITEM_ACTION = action.System.extend("AP_ITEM")

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

-- Anything with no rule of its own is a real CotND item, delivered onto the floor.
apGrants.defineFallback({
    apply = function(_, _, ctx)
        apGrants.drop(ctx.item.item, ctx)
    end,
})

-- `ev` is the turn event when one is delivering this, carrying the beat's action queue.
local function handleItemAcquisition(item, silent, ev)
    if not item then return end

    local itemId = item.item
    local displayName = item.item_name
    local playerEntities = player.getPlayerEntities()

    -- Notify in chat who found this item.
    if not silent then
        apChatBadge.addMessage(getReceivedMessage(item))
    end

    -- Raised locally, and skipped entirely for anything the player took in person.
    if not silent and not apItems.isOwnShopItem(item, apStorage.playerName)
        and not progression.isLocationCollected(item.location_code) then
        local text

        if not apItems.isTrapItem(itemId) then
            local verb = (item.playername ~= progression.getPlayerName()) and L("received", "ap.received") or
                getAcquireVerb(itemId)
            text = displayName .. " " .. verb
        elseif gameState.isInLobby() then
            text = "Something seems off..."
        end

        for _, playerEntity in ipairs(playerEntities) do
            if text and playerEntity then
                apFlyaways.addToFlyawayQueue({ entity = playerEntity, text = text })
            end
        end
    end

    -- The carrier applies itself when taken in person, and only our own finds are keyed here.
    if item.playername == apStorage.playerName
        and progression.isLocationConsumed(item.location_code) then
        apLog("Already applied on pickup, skipping: " .. itemId)
        return
    end

    local spec = apGrants.resolve(itemId)
    if not spec then return end

    -- Buying from our own shop pays out silently: the purchase was the announcement.
    local quiet = silent or apItems.isOwnShopItem(item, apStorage.playerName)
    local collector = playerEntities[1]

    apLog("Granting " .. itemId)
    if spec.sound and not quiet and collector then
        sound.playFromEntity(spec.sound, collector)
    end

    spec.apply(collector, nil, { item = item, silent = quiet, players = playerEntities, ev = ev })
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

    local firstTurnID = turn.getTargetTurnID() + 1
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
            -- A grant that throws must not strand the queue, or it reannounces every tick.
            local ok, err = pcall(handleItemAcquisition, entry.item, entry.silent)
            if not ok then
                apLog(("Failed to grant %s: %s")
                    :format(tostring(entry.item and entry.item.item), tostring(err)), "error")
            end
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
            local ok, err = pcall(handleItemAcquisition, entry.item, entry.silent, ev)
            if not ok then
                apLog("Failed to deliver AP item " .. tostring(entry.item and entry.item.item) .. ": " .. tostring(err))
            end
        end
    end

    visualUpdate.trigger()
end)

return {
    handleItems = processItems
}
