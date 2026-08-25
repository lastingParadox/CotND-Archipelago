local hasStorage, _ = pcall(require, "system.file.Storage")
local hasClient, _ = pcall(require, "system.network.Client")
local currentLevel = require "necro.game.level.CurrentLevel"
local lobbyGeneration = require "necro.game.data.level.LobbyGeneration"
local marker = require "necro.game.tile.Marker"
local object = require("necro.game.object.Object")
local objectMap = require "necro.game.object.Map"
local orderedSelector = require "system.events.OrderedSelector"
local persistence = require "necro.game.object.Persistence"
local tile = require("necro.game.tile.Tile")
local tileTypes = require("necro.game.tile.TileTypes")

local apStorage = require("AP.scripts.client.storage")
local progression = require("AP.scripts.client.progression")
local apBuffRoom = require("AP.scripts.level.lobby.apBuffRoom")
local apCharacterSelect = require("AP.scripts.level.lobby.apCharacterSelect")
local apGameModeSelect = require("AP.scripts.level.lobby.apGameModeSelect")
local apLobby = require("AP.scripts.level.apLobby")
local apItemRoom = require("AP.scripts.level.lobby.apItemRoom")
local lobbyUtils = require("AP.scripts.utils.lobbyUtils")
local modConflict = require("AP.scripts.utils.modConflict")

marker.Type.extend("AP_SPAWN")

local apLobbyGenerateSelector = orderedSelector.new(event.apLobbyGenerate, {
    "lobby",
    "traps",
    "collection",
    "characters",
    "modes",
    "hephaestus",
    "medic",
    "merlin",
    "janitor",
    "diamondDealer",
    "settingsmaster",
    "hintmaster",
    "codex",
    "buffmaster",
    "miscNpcs"
})

local itemRoomGenerated = false
local itemRoomSignature = ""

local victorySlotX = nil
local victorySlotY = nil

itemRoomGenerated, itemRoomSignature, victorySlotX, victorySlotY = script.persist(function()
    return itemRoomGenerated, itemRoomSignature, victorySlotX, victorySlotY
end)

local function itemRoomFingerprint()
    local parts = {}

    for _, entry in ipairs(progression.getItemRoom()) do
        parts[#parts + 1] = entry.id .. ":" .. tostring(entry.category)
    end

    return table.concat(parts, ",")
end

local function buildItemRoom(x, y)
    itemRoomGenerated = apItemRoom.generateItemRoom(x, y)
    itemRoomSignature = itemRoomGenerated and itemRoomFingerprint() or ""
end

local function createMainAPTrapdoor(originX, originY)
    local sourceX, sourceY = 3, 0
    local lockedText = "Whitelist the Client and Storage modules\nin your config to connect!"
    local conflicted = modConflict.hasLegacyArchipelago()

    lobbyUtils.addLabel(sourceX, sourceY, "mod.AP.lobby.stair")

    if conflicted then
        tile.setType(sourceX, sourceY, "LobbyStairsDisabled")
        object.spawn("AP_TriggerAPTrap", sourceX, sourceY, {
            AP_trapUnlock = {
                lockType = "modConflict",
                lockedText = modConflict.WARNING,
            }
        })
    elseif hasStorage and hasClient then
        lobbyUtils.addDestination(sourceX, sourceY, originX, originY, nil, "TriggerOpenMenu")
    else
        tile.setType(sourceX, sourceY, "LobbyStairsDisabled")
        object.spawn("AP_TriggerAPTrap", sourceX, sourceY, {
            AP_trapUnlock = {
                lockType = "apModules",
                lockedText = lockedText,
            }
        })
    end
end

event.lobbyGenerate.add("generateAPLobbyLevel", { order = "modes", sequence = 1 }, function(_)
    if modConflict.hasLegacyArchipelago() then
        createMainAPTrapdoor(0, 0)
    elseif hasStorage and hasClient then
        itemRoomGenerated = false
        apLobbyGenerateSelector.fire({
            segmentID = nil,
            origin = { x = nil, y = nil },
            rect = { minX = nil, maxX = nil, minY = nil, maxY = nil },
            wall = tileTypes.lookUpTileID("UnbreakableWall", tileTypes.lookUpZoneID("Zone2")),
            floor = tileTypes.lookUpTileID("Floor", tileTypes.lookUpZoneID("Zone2"))
        })
    else
        createMainAPTrapdoor(0, 0)
    end
end)

event.apLobbyGenerate.add("generateLobby", "lobby", function(ev)
    local width = 13
    local height = 13

    local minX, maxX, minY, maxY, segmentID = lobbyUtils.addRoom(width, height, -3, "Zone2",
        { xOffset = -10, yOffset = -9, width = width + 25, height = height + 18 })

    ev.rect = { minX = minX, maxX = maxX, minY = minY, maxY = maxY }
    ev.segmentID = segmentID
    apLobby.setSegment(ev.segmentID)

    local centerX = math.floor((minX + maxX) / 2)
    ev.origin = { x = centerX, y = 0 }
    marker.setFirst(marker.Type.AP_SPAWN, centerX, 0)

    object.spawn("AP_LabelLobby", centerX, 0)
end)

local function spawnVictorySlot(x, y)
    victorySlotX = x
    victorySlotY = y
    local victoryTrigger = progression.getVictoryTrigger()
    if victoryTrigger == "Boss Rush" then
        lobbyUtils.addLabel(x, y, "mod.AP.lobby.stair.bossRush")
        object.spawn("AP_TriggerAPTrap", x, y, { trapStartRun = { mode = "AP_APBossRush" } })
    elseif victoryTrigger == "Expensive Purchase" then
        object.spawn("AP_ShopSlot", x, y, { AP_shopSlot = { npc = "VictoryItem" } })
    else
        lobbyUtils.addLabel(x, y, "label.lobby.stair.extraMode.ensemble")
        object.spawn("AP_TriggerAPTrap", x, y, { trapStartRun = { mode = "AP_APEnsemble" } })
    end
end

event.apConnect.add("rebuildVictorySlot", { order = "connected", sequence = 0 }, function(ev)
    if ev.status ~= "Connected" then return end
    if not victorySlotX then return end
    for _, entity in objectMap.entitiesWithComponent(victorySlotX, victorySlotY, "gameObject") do
        if not persistence.check(entity) then
            object.delete(entity)
        end
    end
    tile.set(victorySlotX, victorySlotY, tileTypes.lookUpTileID("Floor", tileTypes.lookUpZoneID("Zone2")))
    spawnVictorySlot(victorySlotX, victorySlotY)
end)

event.apLobbyGenerate.add("generateTraps", "traps", function(ev)
    local offsetX = ev.origin.x + 1
    local offsetY = ev.origin.y + 2

    -- First generate a trap in the main lobby to access the AP lobby.
    createMainAPTrapdoor(ev.origin.x, ev.origin.y)
    -- Second generate a trap in the AP lobby to head back to the main lobby
    lobbyUtils.addBackToLobby(ev.origin.x + 3, 0)

    -- AP Zones Mode Trap
    object.spawn("AP_ZonesStairLabel", offsetX, offsetY)
    object.spawn("AP_TriggerAPTrap", offsetX, offsetY)

    object.spawn("AP_Exchanger", offsetX - 5, offsetY - 4)

    offsetX = offsetX - 4
    offsetY = offsetY + 2

    for i = 1, 4 do
        lobbyUtils.addLabel(offsetX, offsetY, "label.lobby.stair.zone" .. i)
        object.spawn("AP_TriggerAPTrap", offsetX, offsetY, { trapStartRun = { mode = "AP_APSingleZone", zone = i } })
        offsetX = offsetX + 2
    end

    -- Bottom Row
    local list = { "wall", "Ensemble", "Zone_5", "wall" }
    offsetX = offsetX - 8
    offsetY = offsetY + 2

    for _, type in pairs(list) do
        if type == "wall" then
            tile.set(offsetX, offsetY, ev.wall)
            object.spawn("WallTorch", offsetX, offsetY, { lightSourceRadial = { outerRadius = 1344 } })
        elseif type == "Zone_5" then
            lobbyUtils.addLabel(offsetX, offsetY, "label.lobby.stair.zone5")
            object.spawn("AP_TriggerAPTrap", offsetX, offsetY, { trapStartRun = { mode = "AP_APSingleZone", zone = 5 } })
        elseif type == "Ensemble" then
            spawnVictorySlot(offsetX, offsetY)
        else
            object.spawn(type, offsetX, offsetY)
        end

        offsetX = offsetX + 2
    end
end)

event.apLobbyGenerate.add("generateItemCollection", "collection", function(ev)
    buildItemRoom(ev.origin.x - 3, ev.origin.y + 2)
end)

event.apConnect.add("delayedGenerateItemCollection", { order = "connected", sequence = 1 }, function(ev)
    if ev.status ~= "Connected" then return end

    if not itemRoomGenerated then
        local x, y = marker.lookUpFirst(marker.Type.AP_SPAWN)
        buildItemRoom(x - 3, y + 2)
    elseif itemRoomSignature ~= itemRoomFingerprint() and currentLevel.isLobby() then
        lobbyGeneration.generate()
    end
end)

event.apLobbyGenerate.add("generateCharacterRoom", "characters", function(ev)
    apCharacterSelect.createCharacterSelectionRoom(ev.origin.x - 1, ev.origin.y + 2)
end)

event.apLobbyGenerate.add("generateExtraModesRoom", "modes", function(ev)
    apGameModeSelect.generateExtraModesRoom(ev.origin.x + 3, ev.origin.y + 2)
end)

local function createShopkeeper(npc, x, y, offsetY, label, noShopFloor)
    local npcType = npc == "Dungeon Master" and "Medic" or npc
    local labelY = npc == "Dungeon Master" and y - 1 or y

    local shopFloor = tileTypes.lookUpTileID("ShopFloor", tileTypes.lookUpZoneID("Zone2"))

    if not noShopFloor then tile.set(x - 1, y, shopFloor) end
    object.spawn(npcType, x, y)
    if not noShopFloor then tile.set(x + 1, y, shopFloor) end

    -- AP shopkeepers get a label that tracks their stock; the others are static.
    if label then
        lobbyUtils.addLabel(x, labelY, label, offsetY or -26)
    else
        object.spawn("AP_ShopLabel", x, labelY, {
            AP_shopLabel = { npc = npc, offsetY = offsetY or -26 },
        })
    end

    local offsetX = x - 1
    local offsetY = y + 2

    local positions = { "Left", "Center", "Right" }

    for _, position in pairs(positions) do
        object.spawn("AP_ShopSlot", offsetX, offsetY, { AP_shopSlot = { npc = npc, position = position } })
        offsetX = offsetX + 1
    end
end

event.apLobbyGenerate.add("generateHephaestusRoom", "hephaestus", function(ev)
    local minX = ev.rect.minX - 3
    local minY = ev.rect.minY - 6

    lobbyUtils.addRect(minX, minY, 7, 7, ev.wall, ev.floor, true)
    local centerX = math.floor((minX + (minX + 6)) / 2)

    createShopkeeper("Hephaestus", centerX, minY + 2)

    local entranceX = ev.rect.minX + 3
    local entranceY = ev.rect.minY
    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY, { AP_progressionDoor = { npc = { "Hephaestus" } } })
    lobbyUtils.clearTile(entranceX, entranceY - 1, "Zone2")
end)

event.apLobbyGenerate.add("generateMedicRoom", "medic", function(ev)
    local minX = ev.origin.x - 3
    local minY = ev.rect.minY - 9

    lobbyUtils.addRect(minX, minY, 7, 8, ev.wall, ev.floor, true)
    local centerX = math.floor((minX + (minX + 6)) / 2)

    createShopkeeper("Dungeon Master", centerX, minY + 3)

    local entranceX = ev.origin.x
    local entranceY = ev.rect.minY

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY, { AP_progressionDoor = { npc = { "Medic" } } })
    lobbyUtils.clearTile(entranceX, entranceY - 1, "Zone2")
    lobbyUtils.clearTile(entranceX, entranceY - 2, "Zone2")
    tile.set(entranceX - 2, entranceY - 1, ev.wall)
    tile.set(entranceX - 1, entranceY - 1, ev.wall)
    tile.set(entranceX + 1, entranceY - 1, ev.wall)
    tile.set(entranceX + 2, entranceY - 1, ev.wall)
end)

event.apLobbyGenerate.add("generateMerlinRoom", "merlin", function(ev)
    local minX = ev.rect.maxX - 3
    local minY = ev.rect.minY - 6

    lobbyUtils.addRect(minX, minY, 7, 7, ev.wall, ev.floor, true)
    local centerX = math.floor((minX + (minX + 6)) / 2)

    createShopkeeper("Merlin", centerX, minY + 2)

    local entranceX = ev.rect.maxX - 3
    local entranceY = ev.rect.minY

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY, { AP_progressionDoor = { npc = { "Merlin" } } })
    lobbyUtils.clearTile(entranceX, entranceY - 1, "Zone2")
end)

event.apLobbyGenerate.add("generateJanitorRoom", "janitor", function(ev)
    local minX = ev.rect.minX
    local minY = ev.rect.maxY

    lobbyUtils.addRect(minX, minY, 7, 9, ev.wall, ev.floor, true)
    local centerX = math.floor((minX + (minX + 6)) / 2)

    createShopkeeper("Janitor", centerX, minY + 2, -21, "mod.AP.lobby.janitorHint", true)

    object.spawn("AP_TriggerJanitorNext", centerX - 1, minY + 6)
    object.spawn("AP_TriggerJanitorReset", centerX + 1, minY + 6)

    local entranceX = centerX
    local entranceY = minY

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY, { AP_progressionDoor = { npc = { "Janitor" } } })
end)

event.apLobbyGenerate.add("generateDiamondDealerRoom", "diamondDealer", function(ev)
    local minX = ev.origin.x
    local minY = ev.rect.maxY

    lobbyUtils.addRect(minX, minY, 7, 7, ev.wall, ev.floor, true)
    local centerX = math.floor((minX + (minX + 6)) / 2)

    createShopkeeper("Diamonddealer", centerX, minY + 2, -22, "mod.AP.lobby.dealerHint", true)

    local entranceX = centerX
    local entranceY = minY

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY, { AP_progressionDoor = { npc = { "Diamonddealer" } } })
end)

event.apLobbyGenerate.add("generateSettingsMasterRoom", "settingsmaster", function(ev)
    local roomWidth = 11
    local roomHeight = 7

    local minX = ev.rect.minX - (roomWidth - 1)
    local minY = ev.rect.minY

    lobbyUtils.addRect(minX, minY, roomWidth, roomHeight, ev.wall, ev.floor, true)

    local centerX = minX + math.floor(roomWidth / 2)

    object.spawn("Weaponmaster", centerX, minY + 2)
    lobbyUtils.addLabel(centerX, minY + 2, "mod.AP.lobby.settingsmasterHint", -26)

    local deathlinkActive = apStorage.saveData and apStorage.saveData.deathlink == true
    object.spawn("AP_ShrineDeathLink", centerX - 2, minY + 4, { shrine = { active = deathlinkActive } })

    local traplinkActive = apStorage.saveData and apStorage.saveData.traplink == true
    object.spawn("AP_ShrineTrapLink", centerX + 2, minY + 4, { shrine = { active = traplinkActive } })

    local entranceX = ev.rect.minX
    local entranceY = minY + 3

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY, {
        AP_progressionDoor = {
            npc = {},
            orientation = "vertical",
            label = "mod.AP.lobby.npc.settingsmaster",
        }
    })
end)

event.apLobbyGenerate.add("generateHintmasterRoom", "hintmaster", function(ev)
    local minX = ev.rect.maxX
    local minY = ev.rect.minY

    lobbyUtils.addRect(minX, minY, 7, 7, ev.wall, ev.floor, true)
    local centerX = math.floor((minX + (minX + 6)) / 2)

    object.spawn("AP_Hintmaster", centerX, minY + 2)
    lobbyUtils.addLabel(centerX, minY + 2, "mod.AP.lobby.hintmasterHint", -26)

    object.spawn("AP_TriggerHintTrap", centerX, minY + 4)
    tile.setType(centerX, minY + 4, "Stairs")
    lobbyUtils.addLabel(centerX, minY + 4, "mod.AP.lobby.hintRun")

    local entranceX = minX
    local entranceY = minY + 3

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY,
        { AP_progressionDoor = { npc = { "AP_Hintmaster" }, orientation = "vertical" } })
end)

event.apLobbyGenerate.add("generateCodexRoom", "codex", function(ev)
    local minX = ev.rect.maxX
    local minY = ev.rect.minY + 6

    lobbyUtils.addRect(minX, minY, 11, 7, ev.wall, ev.floor, true)
    local centerX = math.floor((minX + (minX + 10)) / 2)

    object.spawn("Trainer", centerX, minY + 2)
    lobbyUtils.addLabel(centerX, minY + 2, "label.lobby.codex.hint", -26)

    local trapsX = centerX - 3
    local trapsY = minY + 4

    for _, codexType in pairs({ "DragonLore", "TrapLore", "BombLore", "Murder" }) do
        object.spawn("TriggerStartRun", trapsX, trapsY,
            { trapStartRun = {
                mode = "CustomDungeon",
                fileName = "mods/AP/scripts/dungeons/AP_" .. codexType .. ".xml",
                options = { characterOverride = "Bard" },
            } })
        tile.setType(trapsX, trapsY, "Stairs")

        local labelText = ""
        if codexType == "DragonLore" then
            labelText = "label.lobby.stair.codex.dragonLore"
        elseif codexType == "TrapLore" then
            labelText = "label.lobby.stair.codex.trapLore"
        elseif codexType == "BombLore" then
            labelText = "label.lobby.stair.codex.bombLore"
        else
            labelText = "label.lobby.stair.codex.shopkeeperKill"
        end

        lobbyUtils.addLabel(trapsX, trapsY, labelText)

        trapsX = trapsX + 2
    end

    local entranceX = minX
    local entranceY = minY + 3

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")
    object.spawn("AP_LobbyDoor", entranceX, entranceY,
        { AP_progressionDoor = { npc = { "Trainer" }, orientation = "vertical" } })
end)

event.apLobbyGenerate.add("generateBuffmasterRoom", "buffmaster", function(ev)
    local minX = ev.rect.minX - 6
    local minY = ev.rect.minY + 6

    lobbyUtils.addRect(minX, minY, 7, 7, ev.wall, ev.floor, true)
    local centerX = minX + 3  -- = ev.rect.maxX + 10

    -- Buffmaster NPC with hint label above.
    object.spawn("AP_Buffmaster", centerX, minY + 2)
    lobbyUtils.addLabel(centerX, minY + 2, "mod.AP.lobby.buffmasterHint", -26)

    -- Staircase to the dedicated Buff Room (addDestination sets tile + label).
    apBuffRoom.generateBuffRoom(centerX, minY + 4)

    local entranceX = ev.rect.minX
    local entranceY = minY + 3

    lobbyUtils.clearTile(entranceX, entranceY, "Zone2")  -- buffmaster left wall
    object.spawn("AP_LobbyDoor", entranceX, entranceY,
        { AP_progressionDoor = { npc = { "Buffmaster" }, orientation = "vertical" } })
end)
