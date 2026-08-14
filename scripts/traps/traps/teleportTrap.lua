local collision    = require("necro.game.tile.Collision")
local currentLevel = require("necro.game.level.CurrentLevel")
local move         = require("necro.game.system.Move")
local rng          = require("necro.game.system.RNG")
local sound        = require("necro.audio.Sound")
local turn         = require("necro.cycles.Turn")
local voice        = require("necro.audio.Voice")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

TrapHandler.register("TeleportTrap", makeSimpleTrap({
    flyawayText = "Teleport!",
    setup = function()
        return rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
    end,
    action = function(entity, channel)
        local tiles = collision.getVacantTiles(
            entity, 3, 40, 6, false,
            collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        )
        if #tiles == 0 then return false end
        local tile = rng.choice(tiles, channel)
        move.absolute(entity, tile[1], tile[2])
        voice.tryPlay(entity, "voiceTeleport")
        sound.play("teleport", entity.position.x, entity.position.y)
    end,
}))
