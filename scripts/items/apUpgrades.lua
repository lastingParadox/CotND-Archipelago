local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apGrants = require("AP.scripts.items.apGrants")
local apInventory = require("AP.scripts.utils.apInventory")
local progression = require("AP.scripts.client.progression")

-- The upgrades have no carrier of their own: they raise a permanent total rather than
-- becoming an item, so they are only ever granted.

apGrants.define({
    item = "PermHeart2",
    apply = function(_, _, ctx)
        for _, playerEntity in ipairs(ctx.players) do
            -- A one-heart character stays on one heart; the total still banks.
            if playerEntity and playerEntity.healthLimit.limit ~= 1 then
                playerEntity.health.health = playerEntity.health.health + 2
                playerEntity.health.maxHealth = playerEntity.health.maxHealth + 2
            end
        end

        progression.addHealth(2)
    end,
})

-- The chest upgrades are read at level load and the coin multipliers are equipped with the
-- starting inventory, so neither drops as a floor item; re-equipping is the whole grant.
apGrants.defineFamily({
    order = 5,
    match = function(itemId)
        local proto = ecs.getEntityPrototype(itemId)
        return proto ~= nil and proto.itemLobbyProgressionUnlock ~= nil
    end,
    apply = function(_, _, ctx)
        for _, playerEntity in ipairs(ctx.players) do
            apInventory.grantAPInnateItems(playerEntity, progression)
        end

        if currentLevel.isLobby() then visualUpdate.trigger() end
    end,
})
