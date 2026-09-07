local apBonusPotion = require("AP.scripts.buffs.apBonusPotion")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local trapHandler = require("AP.scripts.traps.trapHandler")
local trapSystem = require("AP.scripts.traps.trapSystem")

-- Added to the stack rather than dropped, since an AP run refuses every potion pickup.
trapSystem.define({
    name  = "APSparePotion",
    sound = "pickupGeneral",
    apply = function(ctx) apBonusPotion.addPotion(ctx.entity) end,
})

apItemFactory.define({
    name = "AP_SparePotion",
    rawTexture = "ext/items/misc_potion.png",
    hint = "Spare Potion",
    flyaway = "Spare Potion!",
    grant = {
        item = "APSparePotion",
        carrier = false,
        apply = function() trapHandler.deliver("APSparePotion") end,
    },
})
