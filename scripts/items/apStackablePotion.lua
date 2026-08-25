local CustomEntities = require("necro.game.data.CustomEntities")

CustomEntities.extend({
    name = "AP_StackablePotion",
    template = CustomEntities.template.item("misc_potion"),
    components = {
        itemStack = {
            mergeKey = "AP_stackable_potion",
            quantity = 1,
        },
        itemStackMergeOnPickup = {},
        itemStackLimitQuantity = {
            limit = 3,
        },
        -- A lone potion reads as the vanilla one, so only a real stack is numbered.
        itemStackQuantityLabelHUD = {
            minimumQuantity = 2,
        },
        itemBlockDuplicatePickup = {},
    },
})
