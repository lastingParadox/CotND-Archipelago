local action = require "necro.game.system.Action"
local currency = require "necro.game.item.Currency"
local currentLevel = require "necro.game.level.CurrentLevel"
local rng = require "necro.game.system.RNG"
local sound = require "necro.audio.Sound"

local apFlags = require("AP.scripts.utils.flags")
local apNpc = require("AP.scripts.entities.apNpc")
local progression = require("AP.scripts.client.progression")

local GOLD_COST = 50
local DIAMONDS = 1

-- monkeyHit is a group of three files the engine picks between, so listing it three
-- times against monkeyGrab gives the four-way choice.
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
    priceTagLabel = { offsetY = 16, offsetX = -12 },
    priceTagIgnoreMultiplier = {},
    priceTagDepthMultiplier = { active = false },
    priceTagUnaffordableFlyaway = {},
    priceTagSuccessFlyaway = { text = "+" .. DIAMONDS .. " Diamond" },
    soundPriceTagPurchaseFail = {},
    soundPriceTagPurchaseSuccess = {},
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

        currency.add(ev.interactor, apFlags.CURRENCY_AP_DIAMOND, DIAMONDS)
        progression.changeDiamonds(DIAMONDS)

        local channel = rng.makeChannel(currentLevel.getSeed(), ev.entity.id,
            progression.getDiamonds() or 0)

        -- Played here rather than through soundInteract, whose sound is a constant and
        -- so cannot vary, and which drowned this out when both fired.
        local monkey = MONKEY_SOUNDS[rng.int(#MONKEY_SOUNDS, channel) + 1]

        sound.playFromEntity(monkey, ev.entity, { deduplicationID = ev.interactor.id })

        ev.result = action.Result.INTERACT
    end)
