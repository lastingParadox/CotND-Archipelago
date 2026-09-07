local collision = require("necro.game.tile.Collision")
local inventory = require("necro.game.item.Inventory")
local itemBan   = require("necro.game.item.ItemBan")

local trapSystem = require("AP.scripts.traps.trapSystem")

local SCATTER_OFFSETS = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
    { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
    { -2, -1 }, { 2, -1 }, { -2, 1 }, { 2, 1 },
    { -1, -2 }, { 1, -2 }, { -1, 2 }, { 1, 2 },
    { -3, 0 }, { 3, 0 }, { 0, -3 }, { 0, 3 },
}

trapSystem.define({
    name    = "DisarmTrap",
    flyaway = "Disarmed!",
    voice   = "voiceConfused",
    apply   = function(ctx)
        if not ctx.entity.inventory then return false end

        inventory.scatter(
            ctx.entity,
            SCATTER_OFFSETS,
            collision.mask(collision.Group.SOLID, collision.Type.ITEM),
            itemBan.Flag.LOSS_SCATTER
        )
    end,
})
