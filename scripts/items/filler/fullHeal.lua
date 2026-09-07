local health = require "necro.game.character.Health"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local trapHandler = require("AP.scripts.traps.trapHandler")
local trapSystem = require("AP.scripts.traps.trapSystem")

-- Heals outright rather than through a consumable, since the carrier is deleted at "priceTag".
trapSystem.define({
    name  = "APFullHeal",
    sound = "pickupGeneral",
    -- Nobody hurt leaves it queued rather than spending it.
    apply = function(ctx)
        local entity = ctx.entity
        if not (entity.health and entity.health.health < entity.health.maxHealth) then
            return false
        end

        health.heal({ target = entity, healer = entity, health = entity.health.maxHealth })
    end,
})

apItemFactory.define({
    name = "AP_FullHeal",
    texture = "items/full_heal.png",
    hint = "Heal to Full",
    flyaway = "Full Heal",
    grant = {
        item = "APFullHeal",
        carrier = false,
        apply = function() trapHandler.deliver("APFullHeal") end,
    },
})
