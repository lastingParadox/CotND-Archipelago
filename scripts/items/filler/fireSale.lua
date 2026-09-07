local ecs = require "system.game.Entities"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local trapHandler = require("AP.scripts.traps.trapHandler")
local trapSystem = require("AP.scripts.traps.trapSystem")

---Halves every price on the floor, leaving AP shop slots alone.
local function halvePrices()
    local discounted = 0

    for item in ecs.entitiesWithComponents({ "sale" }) do
        if item.AP_locationItem and item.AP_locationItem.slot ~= 0 then
            goto continue
        end

        if item.position and item.sale.priceTag ~= 0 then
            local priceTag = ecs.getEntityByID(item.sale.priceTag)

            if priceTag and priceTag.priceTagCostCurrency and priceTag.priceTagCostCurrency.cost > 1 then
                priceTag.priceTagCostCurrency.cost =
                    math.max(1, math.floor(priceTag.priceTagCostCurrency.cost / 2))
                discounted = discounted + 1
            end
        end

        ::continue::
    end

    return discounted > 0
end

trapSystem.define({
    name  = "APFireSale",
    sound = "spellGold",
    start = function()
        if not halvePrices() then return false end
        return true
    end,
})

apItemFactory.define({
    name = "AP_FireSale",
    texture = "items/fire_sale.png",
    hint = "Fire Sale",
    flyaway = "Fire Sale!",
    grant = {
        item = "APFireSale",
        carrier = false,
        apply = function() trapHandler.deliver("APFireSale") end,
    },
})
