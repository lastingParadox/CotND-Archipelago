local customEntities = require "necro.game.data.CustomEntities"
local flyaway = require "necro.game.system.Flyaway"
local itemPickup = require "necro.game.item.ItemPickup"
local sound = require "necro.audio.Sound"

local apFlags = require("AP.scripts.utils.flags")
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

event.objectTryCollectItem.add("apVictoryItemGoalGate", { order = "priceTag", sequence = -100 }, function(ev)
    if not (ev.item and ev.item.AP_victoryItem) then return end
    local completed, goalMet = progression.calculateGoalCompletion(false)
    if not goalMet then
        local required = progression.getGoalRequired() or 0
        local remaining = math.max(0, required - completed)
        local goalType = progression.getGoal()
        local text
        if goalType == "Zones" then
            text = "Beat " .. remaining .. " more zone" .. (remaining == 1 and "" or "s") .. "\nto unlock!"
        elseif goalType == "Golden Lute Shards" then
            text = "Collect " .. remaining .. " more shard" .. (remaining == 1 and "" or "s") .. "\nto unlock!"
        else
            text = "Beat " .. remaining .. " more all zones\nrun" .. (remaining == 1 and "" or "s") .. " to unlock!"
        end
        flyaway.create({ entity = ev.item, text = text })
        sound.playFromEntity("error", ev.item)
        ev.result = itemPickup.Result.FAILURE
    end
end)
