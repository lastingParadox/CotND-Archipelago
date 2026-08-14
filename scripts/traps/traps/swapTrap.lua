local currentLevel = require("necro.game.level.CurrentLevel")
local ecs          = require("system.game.Entities")
local move         = require("necro.game.system.Move")
local rng          = require("necro.game.system.RNG")
local sound        = require("necro.audio.Sound")
local turn         = require("necro.cycles.Turn")
local voice        = require("necro.audio.Voice")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

TrapHandler.register("SwapTrap", makeSimpleTrap({
    flyawayText = "Swap Trap!",
    setup = function()
        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        local candidates = {}
        for entity in ecs.entitiesWithComponents({ "position", "character" }) do
            if not entity.playableCharacter then
                candidates[#candidates + 1] = entity
            end
        end
        if #candidates == 0 then return false end
        return { channel = channel, candidates = candidates }
    end,
    action = function(entity, ctx)
        local target = rng.choice(ctx.candidates, ctx.channel)
        if not target then return false end
        local px, py = entity.position.x, entity.position.y
        local tx, ty = target.position.x, target.position.y
        move.absolute(target, px, py)
        move.absolute(entity, tx, ty)
        voice.tryPlay(entity, "voiceTeleport")
        sound.play("teleport", entity.position.x, entity.position.y)
    end,
}))
