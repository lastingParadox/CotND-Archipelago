local ecs = require "system.game.Entities"
local inventory = require "necro.game.item.Inventory"
local itemGeneration = require "necro.game.item.ItemGeneration"
local object = require "necro.game.object.Object"

local apGrants = require("AP.scripts.items.apGrants")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")
local trapHandler = require("AP.scripts.traps.trapHandler")

---One chest roll, ignoring what AP has handed over so far. Never unlocks the item.
local function rollItem(channel)
    local choice = itemGeneration.choice({
        chanceType = "chest",
        channel = channel,
        AP_ignoreOwnership = true,
        ignoreProgression = true,
    })

    return choice ~= "" and choice or nil
end

-- A carrier standing on a location wears the item it will hand over, so the roll has to
-- come out the same on every client and again after a rollback. The shop copy has no
-- location and keeps its own sprite.
event.objectSpawn.add("APRandomItemSprite", { order = "overrides", filter = "AP_randomItem" },
    function(ev)
        local entity = ev.entity
        local tag = entity.AP_locationItem
        if not (tag and tag.locationCode ~= "") then return end

        local rolled = rollItem(apUtils.hashChannel(
            progression.getSeedName() or "0",
            tostring(tag.locationCode)
        ))
        if not rolled then return end

        local label = apItemFactory.disguise(entity, ecs.getEntityPrototype(rolled))
        if not label then return end

        entity.AP_randomItem.itemType = rolled
        entity.AP_hintLabel = { text = label }
        entity.AP_flyaway = { text = label .. "!" }
    end)

trapHandler.register("APRandomItem", function()
    local rolled = rollItem()

    return rolled ~= nil and apGrants.drop(itemGeneration.maybeMarkSeen(rolled))
end)

apItemFactory.define({
    name = "AP_RandomItem",
    texture = "items/ap_item/ap_item_filler.png",
    hint = "Random Item",
    flyaway = "Random Item!",
    components = {
        AP_randomItem = {},
    },
    -- Taken in person it already is the item it looks like. Without a roll -- the shop
    -- copy -- the pickup declines and the grant coming back from AP delivers it instead.
    grant = {
        item = "APRandomItem",
        apply = function(collector, carrier, ctx)
            local rolled = carrier and carrier.AP_randomItem.itemType

            if not (collector and rolled and rolled ~= "") then
                if ctx then return trapHandler.deliver("APRandomItem") end
                return false
            end

            inventory.add(object.spawn(itemGeneration.maybeMarkSeen(rolled)), collector)
        end,
    },
})
