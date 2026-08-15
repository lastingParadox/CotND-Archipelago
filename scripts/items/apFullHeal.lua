local apItemFactory = require("AP.scripts.items.apItemFactory")

apItemFactory.define({
    name = "AP_FullHeal",
    texture = "items/full_heal.png",
    data = {
        flyaway = "Full Heal",
        hint = "Heal to Full",
    },
    components = {
        itemConsumeOnPickup = {},
        consumableHeal = { health = 100 },
    },
})
