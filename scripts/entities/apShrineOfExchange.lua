local action = require "necro.game.system.Action"
local commonShrine = require "necro.game.data.object.CommonShrine"
local currency = require "necro.game.item.Currency"
local flyaway = require("necro.game.system.Flyaway")
local sound = require "necro.audio.Sound"

local apFlags = require("AP.scripts.utils.flags")
local progression = require("AP.scripts.client.progression")

commonShrine.registerShrine("exchange", {
    name = "AP_ShrineOfExchange",
    AP_exchangeShrine = {},
    friendlyName = {
        name = "Shrine of Exchange"
    },
    shrineHintLabel = {
        text = "Gold to Diamonds"
    },
    shrine = {
        name = "exchange"
    },
    sprite = {
        height = 52,
        texture = "mods/AP/gfx/shrines/shrine_exchange.png",
        width = 35
    },
    positionalSprite = {
        offsetX = -6,
        offsetY = -21
    },
    priceTag = {
        active = true
    },
    priceTagCostCurrency = {
        cost = 50
    },
    lobbyImmunity = {},
    priceTagDepthMultiplier = { active = false },
    priceTagIgnoreMultiplier = {},
    priceTagShopliftable = false,
    priceTagShopkeeperProximity = false,
    shrinePoolExcludeFromShriner = {},
    AP_editorCategory = {},
})

local function createFlyaway(params, ev)
    ev.textOffsetY = ev.textOffsetY and (ev.textOffsetY + (params.offsetY or -7)) or (params.offsetY or 0)
    flyaway.create({
        entity = params.entity,
        text = params.text,
        offsetY = ev.textOffsetY
    })
    ev.textOffsetY = math.min(ev.textOffsetY, -7)
end

event.shrine.add("exchange", "exchange", function(ev)
    currency.add(ev.interactor, apFlags.CURRENCY_AP_DIAMOND, 1)
    progression.changeDiamonds(1)
    ev.entity.shrine.active = false
end)


event.objectInteract.add("apExchangeShrineInteract",
    { order = "priceTag", filter = "AP_exchangeShrine", sequence = -1 },
    function(ev)
        if (currency.get(ev.interactor, currency.Type.GOLD) < ev.entity.priceTagCostCurrency.cost) then
            ev.suppressed = true
            ev.result = action.Result.FAILURE
            createFlyaway({
                entity = ev.entity,
                text = L("Can't afford!")
            }, ev)
            sound.playFromEntity("error", ev.entity, {
                deduplicationID = ev.interactor.id
            })
        end
    end)
