local collision = require "necro.game.tile.Collision"
local object    = require "necro.game.object.Object"
local rng       = require "necro.game.system.RNG"
local sound     = require "necro.audio.Sound"

local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name    = "DeadRingerTrap",
    flyaway = "Dead Ringer!",
    apply   = function(ctx)
        local entity = ctx.entity
        if entity.confusable and entity.confusable.remainingTurns > 0 then return false end

        local tiles = collision.getVacantTiles(
            entity, 2, 4, 6, false,
            collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        )
        if #tiles == 0 then return false end

        local tile = rng.choice(tiles, ctx.channel)
        object.spawn("DeadRinger", tile[1], tile[2])
    end,
    finish  = function() sound.playUI("announceDeadRinger", { channel = 0 }) end,
})
