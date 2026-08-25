local customEntities = require "necro.game.data.CustomEntities"

local apFlags = require("AP.scripts.utils.flags")
local apGrants = require("AP.scripts.items.apGrants")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

-- Price tag that displays cost and checks affordability without any item-unlock side effects.
customEntities.register({
    name = "AP_PriceTagVictory",
    position = {},
    priceTag = {},
    priceTagCostCurrency = {
        currency = apFlags.CURRENCY_AP_DIAMOND,
    },
    priceTagIgnoreMultiplier = {},
    priceTagCloneable = {},
    priceTagLabel = { offsetX = -2 },
    priceTagLabelInlineImage = { texture = "ext/gui/TEMP_mini_diamond.png" },
    priceTagUnaffordableFlyaway = {},
    soundPriceTagPurchaseFail = {},
    friendlyName = { name = "Victory Purchase Price" },
    sprite = { height = 24, texture = "ext/gui/diamond.png", width = 25 },
    positionalSprite = {},
    editorHidden = {},
})

apItemFactory.define({
    name = "AP_VictoryItem",
    texture = "items/ap_item/ap_item_victory.png",
    hint = "Victory",
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
        AP_victoryItem = {},
    },
})

-- Buying it is the victory trigger, so the goal has to be met before the diamonds are.
-- The purchase itself is handled by the shop slot, which owns the price tag.
apGrants.define({
    carrier = "AP_VictoryItem",
    gate = function() return progression.getGoalUnlockText() end,
})
