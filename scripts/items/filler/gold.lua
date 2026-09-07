local currency = require "necro.game.item.Currency"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

apItemFactory.define({
    name = "AP_Gold",
    texture = "items/gold.png",
    hint = L("Earn Gold", "AP.item.gold"),
    flyaway = "Gold",
    components = {
        AP_currency = {
            currencyType = currency.Type.GOLD,
            value = 50,
        },
    },
    grant = {
        -- Both denominations share one carrier, so the amount is read off the entity.
        {
            apply = function(_, item) progression.grantGold(item.AP_currency.value) end,
        },
        {
            item = "APInstantGold",
            carrier = false,
            sound = "pickupGold",
            apply = function() progression.grantGold(50) end,
        },
        {
            item = "APInstantGold2",
            carrier = false,
            sound = "pickupGold",
            apply = function() progression.grantGold(200) end,
        },
    },
})
