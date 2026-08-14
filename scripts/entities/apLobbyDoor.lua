local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local flyaway = require "necro.game.system.Flyaway"
local map = require "necro.game.object.Map"
local stringUtils = require "system.utils.StringUtilities"
local swipe = require "necro.game.system.Swipe"
local tile = require("necro.game.tile.Tile")
local tileTypes = require "necro.game.tile.TileTypes"

local apCharacters = require('AP.scripts.utils.apCharacters')
local apClient = require('AP.scripts.client.client')
local apStorage = require('AP.scripts.client.storage')
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

event.objectDig.add("apErrorDigFlyaway", {
    order = "flyaway", sequence = 1
}, function(ev)
    if not (ev.success == false and ev.tileInfo.isLocked) then return end

    local entity = map.firstWithComponent(ev.x, ev.y, "AP_progressionDoor")
    local errorString = ""
    local swipeType = ""
    if entity then
        for _, npc in ipairs(entity.AP_progressionDoor.npc) do
            local npcData = progression.getUnlockedNPCs(apCharacters.cotNDNPCToAPLocation(npc))
            local npcItem = progression.getItems(npc)
            if not npcItem then
                -- Check for scouted hint location data first.
                local hintData = apStorage.saveData.npcHintLocations
                    and apStorage.saveData.npcHintLocations[npc]
                if hintData and hintData.LocationCode then
                    -- Send a hint request so the AP server (and other players) know we
                    -- are looking for this NPC.
                    apClient.sendPacket({
                        datatype = "HintNpc",
                        location_code = hintData.LocationCode,
                        player_slot = hintData.PlayerSlot,
                    })

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
        errorString = errorString or "Free me somewhere in the Crypt!"
    end

    if errorString then
        swipe.create({ type = swipeType, x = ev.x, y = ev.y })

        flyaway.create({
            distance = 18,
            duration = 1.5,
            entity = ev.entity,
            text = errorString
        })
    end
end)

event.swipe.add("goldKey", "goldKey", function(ev)
    ev.swipe.texture = "ext/items/misc_key_golden.png"
    ev.swipe.duration = 1.5
    ev.swipe.offsetY = -12
    ev.swipe.fading = true
end)

event.swipe.add("glassKey", "glassKey", function(ev)
    ev.swipe.texture = "ext/items/misc_key_glass.png"
    ev.swipe.duration = 1.5
    ev.swipe.offsetY = -12
    ev.swipe.fading = true
end)

event.swipe.add("apItem", "apItem", function(ev)
    ev.swipe.texture = "mods/AP/gfx/APItem.png"
    ev.swipe.firstFrame = 3
    ev.swipe.duration = 1.5
    ev.swipe.offsetY = -12
    ev.swipe.fading = true
end)
