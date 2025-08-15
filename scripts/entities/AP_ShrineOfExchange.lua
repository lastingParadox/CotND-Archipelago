local currency = require "necro.game.item.Currency"
local components = require("necro.game.data.Components")
local commonShrine = require "necro.game.data.object.CommonShrine"
local resurrection = {}
local action = require "necro.game.system.Action"
local affectorItem = require "necro.game.item.AffectorItem"
local animationTimer = require "necro.render.AnimationTimer"
local audioChannel = require("necro.audio.AudioChannel")
local character = require "necro.game.character.Character"
local collision = require "necro.game.tile.Collision"
local commonShrine = require "necro.game.data.object.CommonShrine"
local commonSpell = require("necro.game.data.spell.CommonSpell")
local currentLevel = require("necro.game.level.CurrentLevel")
local ecs = require "system.game.Entities"
local flyaway = require("necro.game.system.Flyaway")
local follower = require "necro.game.character.Follower"
local gameMod = require "necro.game.data.resource.GameMod"
local health = require "necro.game.character.Health"
local inventory = require "necro.game.item.Inventory"
local move = require "necro.game.system.Move"
local objectEvents = require("necro.game.object.ObjectEvents")
local particle = require "necro.game.system.Particle"
local player = require "necro.game.character.Player"
local playerList = require "necro.client.PlayerList"
local respawn = require "necro.game.character.Respawn"
local rng = require "necro.game.system.RNG"
local settings = require "necro.config.Settings"
local settingsStorage = require "necro.config.SettingsStorage"
local snapshot = require "necro.game.system.Snapshot"
local soulLink = require "necro.game.character.SoulLink"
local sound = require "necro.audio.Sound"
local soundGroups = require "necro.audio.SoundGroups"
local trap = require("necro.game.trap.Trap")
local utils = require "system.utils.Utilities"

components.register({
    AP_exchangeShrine = {},
})

commonShrine.registerShrine("exchange", {
    name = "AP_ShrineOfExchange",
    AP_exchangeShrine = {},
    friendlyName = {
        name = "Shrine of Exchange"
    },
    shrineHintLabel = {
        text = "Convert Gold to Diamonds"
    },
    shrine = {
        activeDrop = {
            "ResourceCoin10"
        },
        inactiveDrop = {
            "ResourceCoin10"
        },
        name = "exchange"
    },
    sprite = {
        height = 52,
        texture = "mods/AP/gfx/shrine_exchange.png",
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
    priceTagDepthMultiplier = { active = false },
    priceTagIgnoreMultiplier = {},
    priceTagShopliftable = false,
    priceTagShopkeeperProximity = false,
    shrinePoolExcludeFromShriner = {}
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
    currency.add(ev.interactor, currency.Type.DIAMOND, 1)
    ev.entity.shrine.active = false
end)

event.objectInteract.add("apExchangeShrineInteract",
    { order = "priceTag", filter = { "AP_exchangeShrine" }, sequence = -1 },
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
