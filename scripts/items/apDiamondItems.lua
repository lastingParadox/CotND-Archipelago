local customEntities = require "necro.game.data.CustomEntities"
local progression = require "necro.game.system.Progression"

local apFlags = require("AP.scripts.utils.flags")

event.entitySchemaLoadEntity.add("addAPDiamondCounter", { order = "overrides" }, function(ev)
    if ev.entity.diamondCounter ~= nil then
        ev.entity.AP_diamondCounter = {}
    end
end)

-- Register AP_ResourceDiamond items (denominations 1-4)
for i = 1, 4 do
    customEntities.extend({
        name = "AP_ResourceDiamond" .. tostring(i),
        template = customEntities.template.item(),
        data = { slot = "misc" },
        components = {
            itemCurrency = {
                currencyType = apFlags.CURRENCY_AP_DIAMOND,
            },
            itemStack = {
                quantity = i,
                mergeKey = apFlags.CURRENCY_AP_DIAMOND,
            },
            itemStackMergeOnPickup = {},
            itemCurrencyConvertible = {},
            itemHintLabel = {
                text = i == 1 and "1 Diamond" or (tostring(i) .. " Diamonds"),
            },
            itemPickupSound = {
                sound = "pickupDiamond",
            },
            sprite = {
                texture = "ext/items/resource_diamond" .. (i == 1 and "" or tostring(i)) .. '.png',
                width = 24,
                height = 24,
            },
            diamondPickupAnimation = {},
            AP_flyaway = {
                text = i == 1 and "1 Diamond" or (tostring(i) .. " Diamonds"),
            },
            AP_editorCategory = {},
        },
    })
end

-- Register AP price tag entities for lobby shop items
local apLobbyPriceTag = {
    position = {},
    priceTag = {},
    priceTagCostCurrency = {
        currency = apFlags.CURRENCY_AP_DIAMOND,
    },
    priceTagIgnoreMultiplier = {},
    priceTagCloneable = {},
    priceTagLabel = {
        offsetX = -2,
    },
    priceTagLabelInlineImage = {
        texture = "ext/gui/TEMP_mini_diamond.png",
    },
    priceTagUnaffordableFlyaway = {},
    soundPriceTagPurchaseSuccess = {},
    soundPriceTagPurchaseFail = {},
    priceTagModifyFlyaway = {
        format = "%s unlocked!",
    },
    friendlyName = {
        name = "Purchase price (AP diamonds)",
    },
    sprite = {
		height = 24,
		texture = "ext/gui/diamond.png",
		width = 25
	},
    positionalSprite = {},
    editorHidden = {},
}

customEntities.register(apLobbyPriceTag, {
    name = "AP_PriceTagLobbyUnlock",
    priceTagIgnoreItemBans = {},
    priceTagUnlockItem = {
        unlockTypes = {
            [progression.UnlockType.ITEM_POOL] = true,
            [progression.UnlockType.ITEM_FORCE_SPAWN] = true,
        },
    },
    priceTagUnlockItemAutoDespawn = {},
    priceTagWarnOnLobbyLeave = {},
})

customEntities.register(apLobbyPriceTag, {
    name = "AP_PriceTagLobbyGrantOnce",
    priceTagUnlockItem = {
        unlockTypes = {
            [progression.UnlockType.ITEM_GRANT_ONCE] = true,
        },
    },
    priceTagModifyFlyaway = {
        format = "%s purchased!",
    },
})

customEntities.register(apLobbyPriceTag, {
    name = "AP_PriceTagLobbyRemoveFromPool",
    priceTagIgnoreItemBans = {},
    priceTagUnlockItem = {
        unlockTypes = {
            [progression.UnlockType.ITEM_POOL_EXCLUSION] = true,
            [progression.UnlockType.ITEM_FORCE_SPAWN] = false,
        },
    },
    priceTagUnlockItemAutoDespawn = {},
    priceTagModifyFlyaway = {
        format = "%s cleaned!",
    },
})
