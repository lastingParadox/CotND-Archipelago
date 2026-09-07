local ecs   = require("system.game.Entities")
local move  = require("necro.game.system.Move")
local rng   = require("necro.game.system.RNG")
local sound = require("necro.audio.Sound")
local voice = require("necro.audio.Voice")

local trapSystem = require("AP.scripts.traps.trapSystem")

trapSystem.define({
    name    = "SwapTrap",
    flyaway = "Swap Trap!",
    start   = function(ctx)
        local candidates = {}
        for entity in ecs.entitiesWithComponents({ "position", "character" }) do
            if not entity.playableCharacter then
                candidates[#candidates + 1] = entity
            end
        end
        if #candidates == 0 then return false end

        ctx.state.candidates = candidates
    end,
    apply   = function(ctx)
        local entity = ctx.entity
        local target = rng.choice(ctx.state.candidates, ctx.channel)
        if not target then return false end

        local px, py = entity.position.x, entity.position.y
        local tx, ty = target.position.x, target.position.y
        move.absolute(target, px, py)
        move.absolute(entity, tx, ty)

        voice.tryPlay(entity, "voiceTeleport")
        sound.play("teleport", entity.position.x, entity.position.y)
    end,
})
