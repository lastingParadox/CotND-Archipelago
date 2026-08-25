local apBonusPotion = require("AP.scripts.buffs.apBonusPotion")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local trapHandler = require("AP.scripts.traps.trapHandler")

-- Added to the stack rather than dropped: apBlockExtraPotions refuses every potion pickup
-- in an AP run, so one left on the floor could never be taken.
trapHandler.register("APSparePotion", makeSimpleTrap({
    sound = "pickupGeneral",
    action = function(entity) apBonusPotion.addPotion(entity) end,
}))

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
