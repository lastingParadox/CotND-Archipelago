local animationTimer = require("necro.render.AnimationTimer")
local collision = require("necro.game.tile.Collision")
local currentLevel = require("necro.game.level.CurrentLevel")
local ecs = require("system.game.Entities")
local flyaway = require("necro.game.system.Flyaway")
local key = require("necro.game.data.item.Key")
local move = require("necro.game.system.Move")
local object = require("necro.game.object.Object")
local objectMap = require("necro.game.object.Map")
local overlay = require("necro.render.Overlay")
local placementUtils = require("necro.game.level.PlacementUtils")
local proceduralLevel = require "necro.game.data.level.ProceduralLevel"
local rng = require "necro.game.system.RNG"
local screenShake = require("necro.render.ScreenShake")
local sound = require("necro.audio.Sound")
local voice = require("necro.audio.Voice")

local apCharacters = require("AP.scripts.utils.apCharacters")
local apExtrasRoom = require("AP.scripts.level.apExtrasRoom")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local flyawayTimer = nil
local flyawayCounter = 1
flyawayTimer, flyawayCounter = script.persist(function()
    return flyawayTimer, flyawayCounter
end)

-- A Dig NPC's golden key lands on its own floor, a Glass NPC's glass key one floor ahead.
local function keysForFloor(zone, floor)
    local owed = {}

    for npcName, npcData in pairs(progression.getCagedNPCs() or {}) do
        if not npcData.freed and npcData.zone == zone then
            if npcData.unlockType == "Dig" and npcData.level == floor then
                owed[#owed + 1] = { npc = npcName, keyType = "MiscGoldenKey" }
            elseif npcData.unlockType == "Glass" and npcData.level == floor + 1 then
                owed[#owed + 1] = { npc = npcName, keyType = "MiscGlassKey" }
            end
        end
    end

    -- pairs order is not guaranteed, and it decides which room each key claims.
    table.sort(owed, function(a, b) return a.npc < b.npc end)

    return owed
end

-- Not levelGen.placeObject, whose fallback deletes whatever already stands on the tile.
local function placeInStandardRoom(entityType, attributes, channel)
    local tiles = {}

    for _, room in ipairs(placementUtils.getRoomsOfType(proceduralLevel.RoomType.STANDARD)) do
        for _, coord in ipairs(placementUtils.getTilesInRoom(room, collision.Group.PLAYER_PLACEMENT)) do
            tiles[#tiles + 1] = coord
        end
    end

    if #tiles == 0 then return nil end

    local coord = tiles[rng.int(#tiles, channel) + 1]
    return object.spawn(entityType, coord[1], coord[2], attributes)
end

-- The generator reserves no NPC_KEY spot in an AP run, so there is nothing to inherit.
local function queueKey(keyType, channel)
    apExtrasRoom.add(keyType, {}, {
        secret = true,
        fallback = function() placeInStandardRoom(keyType, {}, channel) end,
    })
end

event.levelLoad.add("apGenerateLobbyNpcs", "progression", function(ev)
    local cagedNPCs = progression.getCagedNPCs()
    if not cagedNPCs or not apUtils.isAPContext() or not currentLevel.isRegularFloor() then return end

    local curZone  = currentLevel.getZone()
    local curFloor = currentLevel.getFloor()

    local channel  = rng.makeChannel(
        ev.seed or 0,
        (ev.depth or 0) * 4344 + (ev.floor or 0) * 4340 + (ev.zone or 0),
        9996
    )

    local function getUnlockData(unlockType)
        if unlockType == "Glass" then
            return key.Type.GLASS, "Did you bring the glass key?"
        elseif unlockType == "Dig" then
            return key.Type.GOLDEN_1, "Dig for the golden key!"
        else
            return key.Type.GOLDEN_1, "Buy the golden key!"
        end
    end

    for npc_name, npc_data in pairs(cagedNPCs) do
        local correctZone = npc_data.zone == curZone
        local correctFloor = npc_data.level == curFloor

        -- Place NPC + cage
        if not npc_data.freed and correctZone and correctFloor then
            local name = apCharacters.apLocationToCotNDNPC(npc_name)
            local localKey, flyaway2 = getUnlockData(npc_data.unlockType)

            local npc = placeInStandardRoom(name, {
                AP_npcUnlockable = {
                    keyType = localKey,
                    cagedFlyaway2 = flyaway2
                }
            }, channel)

            if npc then
                object.spawn("NPCCage", npc.position.x, npc.position.y, {
                    interactableConsumeKey = {
                        type = localKey
                    },
                    sprite = localKey == key.Type.GLASS and {
                        texture = "ext/level/cage_glass_front.png"
                    } or nil
                })

                npc.AP_npcUnlockable.caged = true
            end
        end
    end

    for _, owed in ipairs(keysForFloor(curZone, curFloor)) do
        queueKey(owed.keyType, channel)
    end
end)

-- NPC Shop key generation
event.generateShopItems.add("generateAPShop", { filter = "generateShopNormal", order = "all", sequence = 1 },
    function(ev)
        local cagedNPCs = progression.getCagedNPCs()
        if not cagedNPCs or not apUtils.isAPContext() then return end

        local curZone  = currentLevel.getZone()
        local curFloor = currentLevel.getFloor()

        for _, npc_data in pairs(cagedNPCs) do
            if npc_data.freed then goto continue end
            local correctZone = npc_data.zone == curZone
            local correctFloor = npc_data.level == curFloor

            if correctZone and correctFloor and npc_data.unlockType == "Shop" then
                if #ev.items > 0 then
                    -- Make deterministic RNG channel
                    local channel = rng.makeChannel(
                        ev.seed or 0,
                        (ev.depth or 0) * 4344 + (ev.floor or 0) * 4340 + (ev.zone or 0),
                        12345 -- unique salt for shop replacement
                    )

                    local index = rng.range(1, #ev.items, channel)
                    ev.items[index] = "MiscGoldenKey"
                end
            end

            ::continue::
        end
    end)

event.objectReveal.add("apNPCFlyaways", {
    filter = "AP_npcUnlockable",
    order = "animation"
}, function(ev)
    if apUtils.isAPContext() and not flyawayTimer then
        flyawayTimer = animationTimer.getTime()
    end
end)

event.objectMove.add("apCageFollowsNPC", {
    filter = "AP_npcUnlockable",
    order = "followers"
}, function(ev)
    for _, cage in objectMap.entitiesWithComponent(ev.prevX, ev.prevY, "interactableUnlockNPC") do
        move.absolute(cage, ev.x, ev.y, ev.moveType)
    end
end)

event.objectInteract.override("unlockNPC", {
    sequence = 1
}, function(func, ev)
    if not apUtils.isAPContext() then
        return func(ev)
    end

    if not ev.suppressed then
        local npc = objectMap.firstWithComponent(ev.entity.position.x, ev.entity.position.y, "AP_npcUnlockable")

        if npc then
            local npcName = apCharacters.cotNDNPCToAPLocation(npc.name)
            progression.addFreedNpcCheck(npcName)

            if flyawayCounter > 1 then
                flyawayTimer = animationTimer.getTime() - 1.5
                flyawayCounter = 1
            end

            npc.AP_npcUnlockable.freed = true

            overlay.screenFlash(overlay.WHITE, 83, ev.interactor)
            screenShake.createOnEntity(ev.interactor)
            sound.playFromEntity("unlock", npc)
            voice.tryPlay(ev.interactor, "voiceStairsUnlock")
        end
    end
end)

event.render.add("apNpcFlyaways", "swipes", function(ev)
    if not flyawayTimer then
        return
    end

    local odd = flyawayCounter % 2 == 1

    if animationTimer.getTime() < flyawayTimer + 1.75 * flyawayCounter + (odd and 0.25 or 0) then
        return
    end

    flyawayCounter = flyawayCounter + 1

    for entity in ecs.entitiesWithComponents({
        "AP_npcUnlockable",
        "visibility"
    }) do
        if not entity.AP_npcUnlockable.keyType or not entity.AP_npcUnlockable.caged then goto continue end
        flyaway.create({
            offsetY = -7,

            entity = entity,
            text = entity.AP_npcUnlockable
                [entity.AP_npcUnlockable.freed and (odd and "freedFlyaway1" or "freedFlyaway2") or odd and "cagedFlyaway1" or "cagedFlyaway2"]
        })

        ::continue::
    end
end)

event.gameStateLevel.add("apResetNPCFlyaways", "resetLevelVariables", function(ev)
    flyawayTimer = nil
    flyawayCounter = 1
end)
