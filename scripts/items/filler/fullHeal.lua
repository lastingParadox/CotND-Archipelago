local health = require "necro.game.character.Health"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local trapHandler = require("AP.scripts.traps.trapHandler")

-- Healed outright rather than through a consumable the player picks up: apLocationItem
-- deletes the carrier at "priceTag", well before "add" puts it in a hand for
-- itemConsumeOnPickup to find.
trapHandler.register("APFullHeal", makeSimpleTrap({
    sound = "pickupGeneral",
    -- Nobody hurt means nothing to heal, and returning false leaves it queued rather than
    -- spending it. A heal bought in the lobby then waits out the healthy start of the run.
    guard = function(entity)
        return entity.health and entity.health.health < entity.health.maxHealth
    end,
    action = function(entity)
        health.heal({ target = entity, healer = entity, health = entity.health.maxHealth })
    end,
}))

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
