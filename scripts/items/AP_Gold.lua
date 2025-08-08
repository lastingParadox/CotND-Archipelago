local components = require("necro.game.data.Components")
local currency = require "necro.game.item.Currency"
local customEntities = require("necro.game.data.CustomEntities")

components.register({
    AP_currency = {
        components.constant.string("currencyType", currency.Type.GOLD),
        components.field.float("value", 0),
    },
})

customEntities.extend({
    name = "AP_Gold",
    template = customEntities.template.item(),
    data = {
        flyaway = "Gold",
        slot = "misc",
    },
    components = {
        sprite = {
            texture = "mods/AP/gfx/Gold.png",
        },
        AP_itemHintLabel = {
            text = L("Earn Gold", "AP.item.gold"),
        },
        AP_currency = {
            currencyType = currency.Type.GOLD,
            value = 50,
        },
        itemDestructible = {},
    },
})

event.objectTryCollectItem.add("pickupAPGold", { order = "checkItem" }, function(ev)
    if (ev.item.name == "AP_Gold") then
        currency.add(ev.entity, currency.Type.GOLD, ev.item.AP_currency.value, nil)
    end
end)
