local collision = require("necro.game.tile.Collision")
local move      = require("necro.game.system.Move")
local rng       = require("necro.game.system.RNG")
local sound     = require("necro.audio.Sound")
local voice     = require("necro.audio.Voice")

local trapSystem = require("AP.scripts.traps.trapSystem")

trapSystem.define({
    name    = "TeleportTrap",
    flyaway = "Teleport!",
    apply   = function(ctx)
        local entity = ctx.entity
        local tiles  = collision.getVacantTiles(
            entity, 3, 40, 6, false,
            collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        )
        if #tiles == 0 then return false end

        local tile = rng.choice(tiles, ctx.channel)
        move.absolute(entity, tile[1], tile[2])
        voice.tryPlay(entity, "voiceTeleport")
        sound.play("teleport", entity.position.x, entity.position.y)
    end,
})
