local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local flyaway = require "necro.game.system.Flyaway"
local map = require "necro.game.object.Map"
local marker = require "necro.game.tile.Marker"
local stringUtils = require "system.utils.StringUtilities"
local swipe = require "necro.game.system.Swipe"
local tile = require("necro.game.tile.Tile")
local tileTypes = require "necro.game.tile.TileTypes"

local apCharacters = require('AP.scripts.utils.apCharacters')
local apClient = require('AP.scripts.client.client')
local apStorage = require('AP.scripts.client.storage')
local lobbyUtils = require("AP.scripts.utils.lobbyUtils")
local progression = require("AP.scripts.client.progression")

customEntities.register({
    name = "AP_LobbyDoor",
    gameObject = {},
    position = {},
    AP_progressionDoor = {
        npc = {},
        orientation = "horizontal"
    }
})

-- The name shown when the player stands near the door, reusing vanilla's own strings.
local NPC_LABELS = {
    Hephaestus    = "label.lobby.npc.hephaestus.name",
    Medic         = "label.lobby.npc.dungeonMaster.name",
    Merlin        = "label.lobby.npc.merlin.name",
    Janitor       = "label.lobby.npc.janitor.name",
    Diamonddealer = "label.lobby.npc.diamondDealer.name",
    Weaponmaster  = "label.lobby.npc.weaponmaster.name",
    AP_Hintmaster = "mod.AP.lobby.npc.hintmaster",
    Trainer       = "mod.AP.lobby.npc.codex",
    Buffmaster    = "mod.AP.lobby.npc.buffmaster",
}

local DOOR_LABEL_OFFSET_Y = -5

-- An explicit label wins, so a door gating nothing can still name where it leads.
local function doorLabelKey(entity)
    local override = entity.AP_progressionDoor.label

    if override ~= "" then return override end

    for _, npc in ipairs(entity.AP_progressionDoor.npc) do
        if NPC_LABELS[npc] then return NPC_LABELS[npc] end
    end
end

-- Steps the label one tile off the door towards the lobby spawn.
local function labelPosition(entity, x, y)
    local lobbyX, lobbyY = marker.lookUpFirst(marker.Type.AP_SPAWN)
    if not lobbyX then return x, y end

    if entity.AP_progressionDoor.orientation:lower() == "vertical" then
        return x + (lobbyX < x and -1 or 1), y
    end

    return x, y + (lobbyY < y and -1 or 1)
end

event.objectSpawn.add("apLabelDoorNPC", { filter = "AP_progressionDoor", order = "label" }, function(ev)
    local key = doorLabelKey(ev.entity)
    if not key then return end

    local x, y = labelPosition(ev.entity, ev.x, ev.y)

    lobbyUtils.addFadingLabel(x, y, key, 0, DOOR_LABEL_OFFSET_Y)
end)

local function isUnlocked(entity)
    local unlockedNPCs = progression.getUnlockedNPCs()
    local items = progression.getItems()
    if not (unlockedNPCs and items) then return false end

    local unlocked = true

    for _, npc in ipairs(entity.AP_progressionDoor.npc) do
        local npcData = unlockedNPCs[apCharacters.cotNDNPCToAPLocation(npc)]
        local npcItem = items[npc]

        -- Nil NPCData: Not in the locations list, so door's going to be unlocked.
        if (npcData ~= nil and not npcItem) then
            unlocked = false
            break
        end
    end

    return unlocked
end

-- Spawn event
event.objectSpawn.add("apCheckDoorUnlock", { filter = "AP_progressionDoor", order = "unlock" }, function(ev)
    local unlocked = isUnlocked(ev.entity)
    local orientation = stringUtils.capitalizeFirst(ev.entity.AP_progressionDoor.orientation)

    local tileType = "Door" .. orientation
    if not unlocked then tileType = "Locked" .. tileType end

    tile.setType(ev.x, ev.y, tileType)
end)

-- Visual update event
event.updateVisuals.add("apLobbyDoorVisuals", { order = "trapVisuals" }, function(ev)
    for entity in ecs.entitiesWithComponents({ "AP_progressionDoor" }) do
        local unlocked = isUnlocked(entity)
        local orientation = stringUtils.capitalizeFirst(entity.AP_progressionDoor.orientation)

        local desiredTile = "Door" .. orientation
        if not unlocked then
            desiredTile = "Locked" .. desiredTile
        end

        local currentTile = tileTypes.getTileInfo(tile.get(entity.position.x, entity.position.y)).name

        -- Player's already opened the door no need to update it any longer.
        if (currentTile == "Floor" or string.find(currentTile, "Grass")) then
            goto continue
        end

        -- Player's acquired the respective NPC item to unlock their door
        if currentTile ~= desiredTile then
            tile.setType(entity.position.x, entity.position.y, desiredTile)
        end

        ::continue::
    end
end)

event.objectDig.override("tryBreakTile",
    function(func, ev)
        if not (ev.tileInfo.isLocked and map.firstWithComponent(ev.x, ev.y, "AP_progressionDoor")) then return func(ev) end
        ev.success = false
    end)

-- What the door tells the player and which key it draws
local function lockedDoorState(entity, announce)
    local errorString = ""
    local swipeType = ""

    for _, npc in ipairs(entity.AP_progressionDoor.npc) do
        local npcData = progression.getUnlockedNPCs(apCharacters.cotNDNPCToAPLocation(npc))
        local npcItem = progression.getItems(npc)
        if not npcItem then
            -- Check for scouted hint location data first.
            local hintData = apStorage.saveData.npcHintLocations
                and apStorage.saveData.npcHintLocations[npc]
            if hintData and hintData.LocationCode then
                -- Tells the AP server which NPC we are looking for.
                if announce then
                    apClient.sendPacket({
                        datatype = "HintNpc",
                        location_code = hintData.LocationCode,
                        player_slot = hintData.PlayerSlot,
                    })
                end

                local locationName = hintData.LocationName
                local playerName = hintData.PlayerName

                if string.find(locationName, "^Caged") and apStorage.playerName == playerName then
                    -- NPC is in our own world; show zone-level as before.
                    errorString = "Free me in " ..
                        tostring(npcData.zone) .. "-" .. tostring(npcData.level) .. "!"
                    swipeType = npcData.unlockType == "Glass" and "glassKey" or "goldKey"
                else
                    -- NPC is either in player's world or somewhere else in our world show player + location.
                    errorString = "Free me in " .. (playerName == apStorage.playerName and "" or playerName .. "'s ") .. hintData.LocationName .. "!"
                    swipeType = "apItem"
                end
            else
                -- No hint data yet; fall back to original messages.
                if not npcData.unlocked then
                    errorString = "Free me in " ..
                        tostring(npcData.zone) .. "-" .. tostring(npcData.level) .. "!"
                    swipeType = npcData.unlockType == "Glass" and "glassKey" or "goldKey"
                else
                    errorString = "I'm in another world!"
                    swipeType = "apItem"
                end
            end
        end
    end

    return errorString, swipeType
end

event.objectDig.add("apErrorDigFlyaway", {
    order = "flyaway", sequence = 1
}, function(ev)
    if not (ev.success == false and ev.tileInfo.isLocked) then return end

    local entity = map.firstWithComponent(ev.x, ev.y, "AP_progressionDoor")
    if not entity then return end

    local errorString, swipeType = lockedDoorState(entity, true)

    swipe.create({ type = swipeType, x = ev.x, y = ev.y })

    flyaway.create({
        distance = 18,
        duration = 1.5,
        entity = ev.entity,
        text = errorString
    })
end)

local SWIPE_TEXTURES = {
    goldKey  = "ext/items/misc_key_golden.png",
    glassKey = "ext/items/misc_key_glass.png",
    apItem   = "mods/AP/gfx/items/ap_item/ap_item_useful.png",
}

local function drawKeySwipe(instance, swipeType)
    if not SWIPE_TEXTURES[swipeType] then return end

    instance.texture = SWIPE_TEXTURES[swipeType]
    instance.duration = 1.5
    instance.offsetY = -12
    instance.fading = true
end

event.swipe.add("goldKey", "goldKey", function(ev) drawKeySwipe(ev.swipe, "goldKey") end)
event.swipe.add("glassKey", "glassKey", function(ev) drawKeySwipe(ev.swipe, "glassKey") end)
event.swipe.add("apItem", "apItem", function(ev) drawKeySwipe(ev.swipe, "apItem") end)

event.swipe.add("apLobbyDoorKey", { key = "key", sequence = 1 }, function(ev)
    local entity = map.firstWithComponent(ev.x, ev.y, "AP_progressionDoor")
    if not entity then return end

    local _, swipeType = lockedDoorState(entity, false)

    drawKeySwipe(ev.swipe, swipeType)
end)
