local collision = require("necro.game.tile.Collision")
local inventory = require("necro.game.item.Inventory")
local itemBan   = require("necro.game.item.ItemBan")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local SCATTER_OFFSETS = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
    { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
    { -2, -1 }, { 2, -1 }, { -2, 1 }, { 2, 1 },
    { -1, -2 }, { 1, -2 }, { -1, 2 }, { 1, 2 },
    { -3, 0 }, { 3, 0 }, { 0, -3 }, { 0, 3 },
}

TrapHandler.register("DisarmTrap", makeSimpleTrap({
    flyawayText = "Disarmed!",
    guard  = function(entity) return entity.inventory end,
    voice  = "voiceConfused",
    action = function(entity)
        inventory.scatter(
            entity,
            SCATTER_OFFSETS,
            collision.mask(collision.Group.SOLID, collision.Type.ITEM),
            itemBan.Flag.LOSS_SCATTER
        )
    end,
}))
