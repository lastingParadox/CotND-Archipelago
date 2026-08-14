local collision    = require("necro.game.tile.Collision")
local currentLevel = require("necro.game.level.CurrentLevel")
local object       = require("necro.game.object.Object")
local rng          = require("necro.game.system.RNG")
local turn         = require("necro.cycles.Turn")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local MIN_BOMBS = 3
local MAX_BOMBS = 10
local MAX_DIST  = 3

TrapHandler.register("BombTrap", makeSimpleTrap({
    flyawayText = "Bomb Trap!",
    setup = function()
        return rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
    end,
    action = function(entity, channel)
        local tiles = collision.getVacantTiles(
            entity, 1, MAX_DIST, nil, false,
            collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        )
        if #tiles == 0 then return false end
        local count = math.min(#tiles, rng.range(MIN_BOMBS, MAX_BOMBS, channel))
        for i = 1, count do
            local t = tiles[i]
            object.spawn("BombLit", t[1], t[2], { beatDelay = { counter = 3 } })
        end
    end,
}))
