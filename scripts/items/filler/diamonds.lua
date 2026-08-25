local apFlags = require("AP.scripts.utils.flags")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

for denomination = 1, 4 do
    local label = denomination == 1 and "1 Diamond" or (denomination .. " Diamonds")

    apItemFactory.define({
        name = "AP_ResourceDiamond" .. denomination,
        rawTexture = "ext/items/resource_diamond"
            .. (denomination == 1 and "" or denomination) .. ".png",
        hint = label,
        flyaway = label,
        destructible = false,
        components = {
            itemCurrency = { currencyType = apFlags.CURRENCY_AP_DIAMOND },
            itemStack = { quantity = denomination, mergeKey = apFlags.CURRENCY_AP_DIAMOND },
            itemStackMergeOnPickup = {},
            itemCurrencyConvertible = {},
            itemPickupSound = { sound = "pickupDiamond" },
            diamondPickupAnimation = {},
        },
        -- currency.create picks these same entities for the piles dug out of walls, so the
        -- carrier banks whatever quantity it happens to hold rather than its denomination.
        grant = {
            item = "APDiamond" .. denomination,
            sound = "pickupDiamond",
            apply = function(_, item)
                progression.changeDiamonds(item and item.itemStack.quantity or denomination)
            end,
        },
    })
end
