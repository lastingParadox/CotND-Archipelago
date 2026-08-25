local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

apItemFactory.define({
    name = "AP_ShopStock",
    texture = "items/shop_stock.png",
    hint = L("Increase AP Shop Stock", "AP.item.shopStock"),
    data = { flyaway = "Shop Stock" },
    components = {
        AP_shopStock = {},
    },
    grant = {
        item = "APShopStock",
        sound = "pickupGeneral",
        apply = function() progression.addShopStock(1) end,
    },
})
