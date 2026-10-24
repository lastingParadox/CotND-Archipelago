local currentLevel = require("necro.game.level.CurrentLevel")
local ecs = require("system.game.Entities")
local inventory = require("necro.game.item.Inventory")
local object = require("necro.game.object.Object")
local rng = require("necro.game.system.RNG")

local apCharacters = require("AP.scripts.utils.apCharacters")

local cadence = {}

local grantedByBuff = {}
local lobbyRolls = {}
lobbyRolls = script.persist(function() return lobbyRolls end)

local ITEM_COUNT = 3
local BUFF_RNG_SEED = 8831

function cadence.revoke(entity)
    if not entity or not entity.id then return end
    local ids = grantedByBuff[entity.id]
    if not ids then return end
    for _, id in ipairs(ids) do
        local item = ecs.getEntityByID(id)
        if item then
            object.delete(item)
        end
    end
    grantedByBuff[entity.id] = nil
end

local function rollItems(progression)
    local slotPool = {}
    for _, name in ecs.typesWithComponents({ "item", "itemSlot" }) do
        if progression.getItems(name)
            and not progression.getBannedItems(name)
            and not apCharacters.isCharacter(name)
            and name:sub(1, 3) ~= "AP_"
            and name ~= "Bomb"
            and name ~= "Bomb3"
            and name ~= "BombInfinity"
            and name:sub(1, 15) ~= "Coldsteel_Spell"
        then
            local proto = ecs.getEntityPrototype(name)
            if proto and proto.itemSlot then
                local slot = proto.itemSlot.name
                slotPool[slot] = slotPool[slot] or {}
                slotPool[slot][#slotPool[slot] + 1] = name
            end
        end
    end

    local slots = {}
    for slot in pairs(slotPool) do
        slots[#slots + 1] = slot
    end
    table.sort(slots)

    local channel = rng.makeChannel(currentLevel.getSeed(), 0, BUFF_RNG_SEED)
    local names = {}

    for i = 1, math.min(ITEM_COUNT, #slots) do
        local remaining = #slots - (i - 1)
        local slotIdx = rng.int(remaining, channel) + 1
        local chosenSlot = slots[slotIdx]
        slots[slotIdx] = slots[remaining]
        slots[remaining] = chosenSlot

        local items = slotPool[chosenSlot]
        names[#names + 1] = items[rng.int(#items, channel) + 1]
    end

    return names
end

-- The run started from the lobby takes the lobby's roll; any later run rolls its own.
function cadence.apply(entity, progression)
    if not entity then return end

    local playerID = entity.controllable and entity.controllable.playerID or 0
    -- A body being spawned for a run is not controlled yet, so it carries its player as pending.
    if playerID == 0 and entity.playableCharacter then
        playerID = entity.playableCharacter.pendingPlayerID
    end

    local names

    if currentLevel.isLobby() then
        names = rollItems(progression)
        lobbyRolls[playerID] = names
    else
        names = lobbyRolls[playerID] or rollItems(progression)
        lobbyRolls[playerID] = nil
    end

    local grantedItems = {}

    for _, itemName in ipairs(names) do
        local granted = inventory.replace(itemName, entity)
        if granted and granted.id then
            grantedItems[#grantedItems + 1] = granted.id
        end
    end

    grantedByBuff[entity.id] = grantedItems
end

return cadence
