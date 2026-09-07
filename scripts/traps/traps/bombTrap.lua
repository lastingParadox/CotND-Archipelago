local collision = require("necro.game.tile.Collision")
local object    = require("necro.game.object.Object")
local rng       = require("necro.game.system.RNG")

local trapSystem = require("AP.scripts.traps.trapSystem")

local MIN_BOMBS = 3
local MAX_BOMBS = 10
local MAX_DIST  = 3

trapSystem.define({
    name    = "BombTrap",
    flyaway = "Bomb Trap!",
    apply   = function(ctx)
        local tiles = collision.getVacantTiles(
            ctx.entity, 1, MAX_DIST, nil, false,
            collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        )
        if #tiles == 0 then return false end

        local count = math.min(#tiles, rng.range(MIN_BOMBS, MAX_BOMBS, ctx.channel))
        for i = 1, count do
            local t = tiles[i]
            object.spawn("BombLit", t[1], t[2], { beatDelay = { counter = 3 } })
        end
    end,
})
