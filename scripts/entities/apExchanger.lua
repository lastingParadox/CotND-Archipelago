local action = require "necro.game.system.Action"
local currency = require "necro.game.item.Currency"
local currentLevel = require "necro.game.level.CurrentLevel"
local flyaway = require "necro.game.system.Flyaway"
local rng = require "necro.game.system.RNG"
local sound = require "necro.audio.Sound"

local apFlags = require("AP.scripts.utils.flags")
local apNpc = require("AP.scripts.entities.apNpc")
local progression = require("AP.scripts.client.progression")

local GOLD_COST = 50

-- monkeyHit is a group of three files, so listing it three times gives a four-way choice.
local MONKEY_SOUNDS = { "monkeyGrab", "monkeyHit", "monkeyHit", "monkeyHit" }

apNpc.make("AP_Exchanger", {
    AP_exchanger = {},
    friendlyName = {
        name = "Exchanger"
    },
    sprite = {
        texture = "mods/AP/gfx/entities/exchanger.png",
        width = 49,
        height = 59,
    },
    positionalSprite = {
        offsetX = -24,
        offsetY = -22
    },
    rowOrder = {
        z = 20
    },
    multiTile = {
        offsets = { { -1, 0 } }
    },
    AP_hintLabel = {
        text = "Gold to Diamonds",
        offsetX = -12,
        offsetY = -50
    },

    interactable = {},
    sale = {},
    priceTag = { active = true },
    priceTagCostCurrency = { cost = GOLD_COST },
    priceTagIgnoreMultiplier = {},
    priceTagDepthMultiplier = { active = false },
    priceTagUnaffordableFlyaway = {},
    soundPriceTagPurchaseFail = {},
    soundPriceTagPurchaseSuccess = {},

    -- secretShopLabel rather than priceTagLabel, so the tag states the rate and survives 0 gold.
    secretShopLabel = {
        text = "%d:1",
        offsetY = 16,
        offsetX = -12
    },
})

event.objectSpawn.add("apExchangerPriceTag",
    { filter = { "AP_exchanger", "sale", "priceTag" }, order = "overrides" },
    function(ev)
        ev.entity.sale.priceTag = ev.entity.id
    end)

event.objectInteract.add("apExchangerTrade",
    { filter = "AP_exchanger", order = "activate" },
    function(ev)
        if ev.suppressed then return end

        -- The price tag already took the first 50, so the remaining balance converts too.
        local remaining = currency.get(ev.interactor, currency.Type.GOLD)
        local extra = math.floor(remaining / GOLD_COST)

        if extra > 0 then
            currency.subtract(ev.interactor, currency.Type.GOLD, extra * GOLD_COST)
        end

        local diamonds = 1 + extra

        currency.add(ev.interactor, apFlags.CURRENCY_AP_DIAMOND, diamonds)
        progression.changeDiamonds(diamonds)

        -- Announced here, since priceTagSuccessFlyaway's text is fixed at schema load.
        flyaway.create({
            entity = ev.interactor,
            text = "+" .. diamonds .. (diamonds == 1 and " Diamond" or " Diamonds"),
        })

        local channel = rng.makeChannel(currentLevel.getSeed(), ev.entity.id,
            progression.getDiamonds() or 0)

        -- Played here rather than through soundInteract, whose sound is a constant.
        local monkey = MONKEY_SOUNDS[rng.int(#MONKEY_SOUNDS, channel) + 1]

        sound.playFromEntity(monkey, ev.entity, { deduplicationID = ev.interactor.id })

        ev.result = action.Result.INTERACT
    end)
