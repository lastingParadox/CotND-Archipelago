local currentLevel = require "necro.game.level.CurrentLevel"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apInventory = require("AP.scripts.utils.apInventory")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

-- The carrier for the coin multiplier tiers. The tiers themselves are the vanilla
-- CoinsX15 and CoinsX2 innates, which apInventory grants in order.
apItemFactory.define({
    name = "AP_ProgressiveCoinMultiplier",
    rawTexture = "ext/items/coins_x15.png",
    hint = L("Progressive Coin Multiplier", "AP.item.progressiveCoinMultiplier"),
    flyaway = L("Coin Multiplier Increased!", "AP.item.progressiveCoinMultiplier.flyaway"),
    -- The tier is counted from the received-items log, so re-equipping the innates is the
    -- whole grant.
    grant = {
        item = "APProgressiveCoinMultiplier",
        carrier = false,
        sound = "shrineActivate",
        apply = function(_, _, ctx)
            for _, playerEntity in ipairs(ctx.players) do
                apInventory.grantAPInnateItems(playerEntity, progression)
            end

            if currentLevel.isLobby() then visualUpdate.trigger() end
        end,
    },
})
