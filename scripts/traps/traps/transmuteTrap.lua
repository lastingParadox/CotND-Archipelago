local inventory       = require "necro.game.item.Inventory"
local itemGeneration  = require "necro.game.item.ItemGeneration"
local object          = require "necro.game.object.Object"
local rng             = require "necro.game.system.RNG"
local spellTransmute  = require "necro.game.spell.SpellTransmute"
local turn            = require "necro.cycles.Turn"

local trapSystem = require "AP.scripts.traps.trapSystem"

-- Items that are character-defining and should never be transmuted.
local PROTECTED_ITEMS = {
    WeaponLantern         = true,   -- Chaunter\'s Lantern
    SpellTransform        = true,   -- Nocturna\'s Transform Spell
    Sync_WeaponLance      = true,   -- Aria\'s Lance (Synchrony)
    Coldsteel_ArmorVirtual = true,
    Coldsteel_WeaponLeek  = true,
}

local function canTransmute(item)
    if not item.itemTransmutable then return false end
    if item.itemExcludeFromTransmute then return false end
    if PROTECTED_ITEMS[item.name] then return false end
    if item.itemSlot and item.itemSlot.name == "bomb" then return false end
    return true
end

trapSystem.define({
    name    = "TransmuteTrap",
    flyaway = "Transmuted!",
    apply   = function(ctx)
        local entity = ctx.entity

        -- Snapshot before mutating, since the list can change mid-loop.
        local transmutableItems = {}
        for _, item in ipairs(inventory.getItems(entity)) do
            if canTransmute(item) then
                transmutableItems[#transmutableItems + 1] = item
            end
        end
        if #transmutableItems == 0 then return false end

        for _, item in ipairs(transmutableItems) do
            local slot = item.itemSlot and item.itemSlot.name
            -- Only transmutes when a same-slot item exists; otherwise spellTransmute deletes it.
            local target = itemGeneration.choice({
                levelBonus     = 1,
                player         = entity,
                itemPool       = itemGeneration.Pool.CHEST,
                transmutedItem = item,
                slot           = slot,
                seed           = rng.getDungeonSeed() + turn.getCurrentTurnID() + item.id,
                seenCounts     = {},
            })
            if target then
                spellTransmute.transmuteItem({
                    item   = item,
                    caster = entity,
                    target = target,
                })
            end
        end
    end,
    finish  = function() object.processPendingConversions() end,
})
