local CustomEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local components = require("necro.game.data.Components")
local flyaway = require "necro.game.system.Flyaway"

components.register({
    AP_item = {},
    AP_flyaway = {
        components.field.string("text", "AP Item Obtained"),
    },
    AP_itemHintLabel = {
        components.field.string("text", ""),
        components.field.float("offsetY", -26),
    },
    AP_player = {
        components.field.string("name", ""),
    },
    AP_itemClass = {
        components.field.int("classification", 0), -- 0 = filler, 1 = progression, 2 = useful, 3 = trap
    }
})

CustomEntities.extend({
    name = "AP_Item",
    template = CustomEntities.template.item(),
    data = {
        slot = "misc",
    },
    components = {
        sprite = {
            texture = "mods/AP/gfx/APItem.png",
            width = 24,
            height = 24
        },
        spriteSheet = {
            frameX = 1,
            frameY = 1
        },
        itemDestructible = {},
        AP_item = {},
        AP_itemHintLabel = {
            text = L("AP Item", "AP.item.hint"),
        },
        AP_flyaway = {
            text = L("AP Item Obtained", "AP.item.flyaway"),
        },
    },
})

event.pickupEffects.override("flyaway", {
    sequence = 1 }, function(func, ev)
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

event.render.add("APItemSprite", { order = "objects" }, function(ev)
    for entity in ecs.entitiesWithComponents({
        "AP_item",
    }) do
        if (entity.AP_itemClass and entity.AP_itemClass.classification) then
            entity.spriteSheet.frameX = entity.AP_itemClass.classification + 1
        end
    end
end)
