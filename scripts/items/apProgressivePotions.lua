local apItemFactory = require("AP.scripts.items.apItemFactory")

-- The carrier for the potion-capacity tiers. AP_StackablePotion is the potion the
-- tiers grant, which is a different entity with a different lifetime.
apItemFactory.define({
    name = "AP_ProgressivePotions",
    texture = "items/progressive_potion.png",
    hint = L("Progressive Potions", "AP.item.progressivePotions"),
    flyaway = L("Progressive Potions Obtained!", "AP.item.progressivePotions.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})
