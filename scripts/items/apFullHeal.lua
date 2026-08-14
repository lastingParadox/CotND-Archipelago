local apItemFactory = require("AP.scripts.items.apItemFactory")

apItemFactory.define({
    name = "AP_FullHeal",
    texture = "FullHeal.png",
    data = {
        flyaway = "Full Heal",
        hint = "Heal to Full",
    },
    components = {
        itemConsumeOnPickup = {},
        consumableHeal = { health = 100 },
    },
})
