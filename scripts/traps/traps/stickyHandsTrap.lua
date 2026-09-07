local inventory = require "necro.game.item.Inventory"
local itemBan   = require "necro.game.item.ItemBan"

local trapSystem = require "AP.scripts.traps.trapSystem"

event.itemBanCheck.add("APStickyHandsTrap", {
    filter = "playableCharacter",
    order  = "slot",
}, function(ev)
    local state = trapSystem.stateOf("StickyHandsTrap", ev.holder)
    if not state then return end

    if ev.item.itemSlot and state.slots[ev.item.itemSlot.name] then
        ev.mask = itemBan.Type.LOCK
    end
end)

trapSystem.define({
    name      = "StickyHandsTrap",
    flyaway   = "Sticky Hands!",
    status    = "Sticky Hands!",
    sound     = "trapDice",
    perPlayer = true,
    apply     = function(ctx)
        local slots = {}
        for _, item in ipairs(inventory.getItems(ctx.entity)) do
            if item.itemSlot then
                slots[item.itemSlot.name] = true
            end
        end
        if not next(slots) then return false end

        ctx.state.slots = slots
    end,
})
