local currency = require "necro.game.item.Currency"

local apItemFactory = require("AP.scripts.items.apItemFactory")

apItemFactory.define({
    name = "AP_Gold",
    texture = "items/gold.png",
    hint = L("Earn Gold", "AP.item.gold"),
    data = { flyaway = "Gold" },
    components = {
        AP_currency = {
            currencyType = currency.Type.GOLD,
            value = 50,
        },
    },
})
