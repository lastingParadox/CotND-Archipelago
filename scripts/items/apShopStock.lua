local apItemFactory = require("AP.scripts.items.apItemFactory")

apItemFactory.define({
    name = "AP_ShopStock",
    texture = "ShopStock.png",
    hint = L("Increase AP Shop Stock", "AP.item.shopStock"),
    data = { flyaway = "Shop Stock" },
    components = {
        AP_shopStock = {},
    },
})
