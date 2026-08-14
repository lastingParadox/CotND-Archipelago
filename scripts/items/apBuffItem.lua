local gameState = require("necro.client.GameState")
local itemPickup = require "necro.game.item.ItemPickup"

local apCharacters = require("AP.scripts.utils.apCharacters")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local apItems = require("AP.scripts.utils.apItems")
local apLobby = require("AP.scripts.level.apLobby")
local progression = require("AP.scripts.client.progression")

local apBuffItem = {}

-- Ordered: entity type IDs are handed out in registration order, so every client
-- has to walk this the same way. The entity name is also the apworld's cotnd id.
local CHARACTERS = {
    "Cadence", "Melody", "Aria", "Dorian", "Eli", "Monk", "Dove", "Coda", "Bolt",
    "Bard", "Nocturna", "Diamond", "Mary", "Tempo", "Reaper", "Klarinetta",
    "Chaunter", "Suzu", "Hatsune Miku", "Shovel Knight",
}

apBuffItem.buffs = {}
apBuffItem.characterOf = {}

for _, character in ipairs(CHARACTERS) do
    local entity = "AP_" .. (character:gsub("%s", "")) .. "Buff"
    local sprite = apCharacters.apLocationToCotNDChar(character):lower()
    local key = "AP.item.buff." .. sprite

    apItemFactory.define({
        name = entity,
        texture = "items/buffs/buff_" .. sprite .. ".png",
        hint = L(character .. " Buff", key),
        flyaway = L(character .. " Buff Unlocked!", key .. ".flyaway"),
        components = {
            spriteSheet = { frameX = 1, frameY = 1 },
            AP_buffItem = { character = character },
        },
    })

    apBuffItem.buffs[#apBuffItem.buffs + 1] = { character = character, entity = entity }
    apBuffItem.characterOf[entity] = character
    -- Unlocks a lobby shrine rather than dropping into a run.
    apItems.apItemsList[entity] = true
end

event.objectTryCollectItem.add("pickupAPBuffItem", { order = "priceTag", sequence = 1 }, function(ev)
    if not (gameState.isInLobby() and apLobby.isInLobby(ev.entity)) then return end
    if ev.result ~= itemPickup.Result.SUCCESS then return end
    if not ev.item.AP_buffItem then return end

    progression.unlockBuffItem(ev.item.AP_buffItem.character)
end)

return apBuffItem
