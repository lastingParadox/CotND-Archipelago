local ecs       = require "system.game.Entities"
local inventory = require "necro.game.item.Inventory"
local itemBan   = require "necro.game.item.ItemBan"

local apTrapStatus   = require "AP.scripts.ui.apTrapStatus"
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local savedState = {}
savedState = script.persist(function() return savedState end)

apTrapStatus.register("StickyHandsTrap", function(entity)
    return savedState[entity.id] and "Sticky Hands!" or nil
end)

event.itemBanCheck.add("APStickyHandsTrap", {
    filter = "playableCharacter",
    order  = "slot",
}, function(ev)
    local slots = savedState[ev.holder.id]
    if slots and ev.item.itemSlot and slots[ev.item.itemSlot.name] then
        ev.mask = itemBan.Type.LOCK
    end
end)

event.gameStateLevel.add("APStickyHandsTrapClearOnLevel", { order = "splitScreen" }, function()
    savedState = {}
end)

event.gameStateReset.add("APStickyHandsTrapClearOnReset", { order = "resetRunVariables" }, function()
    savedState = {}
end)

TrapHandler.register("StickyHandsTrap", makeSimpleTrap({
    flyawayText = "Sticky Hands!",
    guard = function(entity)
        return entity.playableCharacter and not savedState[entity.id]
    end,
    sound = "trapDice",
    action = function(entity)
        local slots = {}
        for _, item in ipairs(inventory.getItems(entity)) do
            if item.itemSlot then
                slots[item.itemSlot.name] = true
            end
        end
        if not next(slots) then return false end
        savedState[entity.id] = slots
    end,
}))
