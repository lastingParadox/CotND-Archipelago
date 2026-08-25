local flyaway = require "necro.game.system.Flyaway"

local apGrants = require("AP.scripts.items.apGrants")
local apItemFactory = require("AP.scripts.items.apItemFactory")

-- Someone else's item, drawn by how their world classified it. Ordered, because
-- registration order decides entity type IDs and every client must agree on them.
local PLACEHOLDERS = {
    { name = "AP_ItemFiller",      sprite = "filler" },
    { name = "AP_ItemProgression", sprite = "progression" },
    { name = "AP_ItemUseful",      sprite = "useful" },
    { name = "AP_ItemTrap",        sprite = "trap" },
}

for _, placeholder in ipairs(PLACEHOLDERS) do
    apItemFactory.define({
        name = placeholder.name,
        texture = "items/ap_item/ap_item_" .. placeholder.sprite .. ".png",
        hint = L("AP Item", "AP.item.hint"),
        flyaway = L("AP Item Obtained", "AP.item.flyaway"),
        components = {
            spriteSheet = { frameX = 1, frameY = 1 },
            AP_item = {},
        },
    })
end

event.pickupEffects.override("flyaway", { sequence = 1 }, function(func, ev)
    if ev.item.AP_flyaway then
        flyaway.create({
            entity = ev.holder,
            text = ev.item.AP_flyaway.text,
            delay = ev.delay
        })
    else
        func(ev)
    end
end)

-- Someone else's item: the flyaway is the whole of it, and that is raised for every
-- grant. Registered so it claims its id rather than falling through to a spawn.
apGrants.define({
    item = "APItem",
    apply = function() end,
})
