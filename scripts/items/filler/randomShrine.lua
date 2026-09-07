local collision = require "necro.game.tile.Collision"
local object = require "necro.game.object.Object"
local rng = require "necro.game.system.RNG"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local apShrines = require("AP.scripts.entities.apShrines")
local trapHandler = require("AP.scripts.traps.trapHandler")
local trapSystem = require("AP.scripts.traps.trapSystem")

trapSystem.define({
    name  = "APRandomShrine",
    sound = "spellGeneral",
    -- Only shrines already unlocked, so nothing here is out of the floor's own reach.
    start = function(ctx)
        local unlocked = apShrines.unlockedShrines()
        if #unlocked == 0 then return false end

        ctx.state.unlocked = unlocked
    end,
    apply = function(ctx)
        local tiles = collision.getVacantTiles(
            ctx.entity, 2, 4, 6, false,
            collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        )
        if #tiles == 0 then return false end

        local name = rng.choice(ctx.state.unlocked, ctx.channel)

        if not object.spawn(name, tiles[1][1], tiles[1][2]) then return false end
    end,
})

apItemFactory.define({
    name = "AP_RandomShrine",
    rawTexture = "ext/level/shrine_chance.png",
    -- CommonShrine's own sheet geometry, since a shrine frame is not a 24x24 item icon.
    width = 35,
    height = 52,
    components = {
        spriteSheet = {},
        positionalSprite = { offsetX = -6, offsetY = -19 },
    },
    hint = "Random Shrine",
    flyaway = "Random Shrine!",
    grant = {
        item = "APRandomShrine",
        carrier = false,
        apply = function() trapHandler.deliver("APRandomShrine") end,
    },
})
