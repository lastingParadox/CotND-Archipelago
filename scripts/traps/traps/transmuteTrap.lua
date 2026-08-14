local inventory       = require "necro.game.item.Inventory"
local itemGeneration  = require "necro.game.item.ItemGeneration"
local object          = require "necro.game.object.Object"
local spellTransmute  = require "necro.game.spell.SpellTransmute"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

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

TrapHandler.register("TransmuteTrap", makeSimpleTrap({
    flyawayText = "Transmuted!",
    guard = function(entity)
        for _, item in ipairs(inventory.getItems(entity)) do
            if canTransmute(item) then return true end
        end
        return false
    end,
    action = function(entity)
        -- Snapshot before mutating, since the list can change mid-loop.
        local transmutableItems = {}
        for _, item in ipairs(inventory.getItems(entity)) do
            if canTransmute(item) then
                transmutableItems[#transmutableItems + 1] = item
            end
        end
        for _, item in ipairs(transmutableItems) do
            local slot = item.itemSlot and item.itemSlot.name
            -- Pre-check: only transmute if a same-slot item actually exists.
            -- If itemGeneration.choice returns nil, spellTransmute would delete the item instead.
            local target = itemGeneration.choice({
                levelBonus   = 1,
                player       = entity,
                itemPool     = itemGeneration.Pool.CHEST,
                transmutedItem = item,
                slot         = slot,
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
    after = function()
        object.processPendingConversions()
    end,
}))
