local Event = require("necro.event.Event")
local Collision = require("necro.game.tile.Collision")
local ItemPickup = require "necro.game.item.ItemPickup"
local Components = require("necro.game.data.Components")
local APUtils = require("AP.scripts.ap_handlers.APUtils")
local textPool = require("necro.config.i18n.TextPool")

textPool.register("Archipelago", "mod.AP.lobby.stair")
textPool.register("Back to\nArchipelago", "mod.AP.lobby.stairBack")

Components.register({
    AP_Character = {},
    AP_interactable = {
        Components.field.bool("ap", false),
        Components.field.bool("active", false)
    },
})

-- Purchasable diamonds, huh.
Event.entitySchemaLoadNamedEntity.add("changeDiamonds", { key = "ResourceDiamond" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

Event.entitySchemaLoadNamedEntity.add("changeDiamonds2", { key = "ResourceDiamond2" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

Event.entitySchemaLoadNamedEntity.add("changeDiamonds3", { key = "ResourceDiamond3" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

Event.entitySchemaLoadNamedEntity.add("changeDiamonds4", { key = "ResourceDiamond4" }, function(ev)
    ev.entity.sale = { ["priceTag"] = {} }
end)

Event.entitySchemaLoadNamedEntity.add("shrineOfConfigurationAP", { key = "ShrineOfConfiguration" }, function(ev)
    ev.entity.AP_interactable = { ["ap"] = false, ["active"] = false }
end)

-- Add item pricing and collection schemas for playableCharacters
Event.entitySchemaLoadEntity.add("playerAPItem", { order = "overrides", sequence = 1 }, function(ev)
    local e = ev.entity

    if (e.playableCharacter) then
        e.sale = { ["priceTag"] = {} }

        e.item = {}
        e.itemSpawnFlyawayOnPickup = { text = e.name }
        e.itemPickupAnimation = {}
        e.itemPickupSound = {}
        e.itemHintLabel = { text = e.friendlyName.name }
        e.itemSlot = { name = "misc" }

        e.collision = {
            mask = Collision.Type.mask(e.collision and e.collision.mask or Collision.Type.PLAYER,
                Collision.Type.ITEM)
        }
    end
end)

-- Don't allow AP_Character entities to collect themselves
Event.objectTryCollectItem.override("checkItem",
    function(func, ev)
        if (ev.item.playableCharacter and ev.entity.playableCharacter) then
            local itemId = ev.item.controllable.playerID
            local entityId = ev.entity.controllable.playerID

            if (itemId == entityId or itemId > 0 or (not APUtils.isInLobby(ev.entity))) then
                ev.result = ItemPickup.Result.NONE
                ev.silent = true
            end
        end
        func(ev)
    end)
