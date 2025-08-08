local CustomEntities = require("necro.game.data.CustomEntities")

CustomEntities.extend({
    name = "AP_FullHeal",
    template = CustomEntities.template.item(),
    data = {
        flyaway = "Full Heal",
        hint = "Heal to Full",
        slot = "misc",
    },
    components = {
        sprite = {
            texture = "mods/AP/gfx/FullHeal.png",
        },
        itemConsumeOnPickup = {},
        consumableHeal = {
            health = 100
        },
        itemDestructible = {},
    },
})
