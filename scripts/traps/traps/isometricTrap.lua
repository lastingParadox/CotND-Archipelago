local action = require "necro.game.system.Action"
local ecs    = require "system.game.Entities"
local facing = require "necro.game.character.Facing"
local gfx    = require "system.gfx.GFX"
local player = require "necro.game.character.Player"
local render = require "necro.render.Render"
local rng    = require "necro.game.system.RNG"
local freezeFrame = require "necro.render.FreezeFrame"
local gameState   = require "necro.client.GameState"

local trapSystem = require "AP.scripts.traps.trapSystem"

local ANGLE_LIST = { 45, 135, 225, 315 }

local function rotateCamera(angleDeg)
    local options = render.getCameraOptions(render.Transform.CAMERA).transform
    local rad     = angleDeg * math.pi / 180
    local centerX = gfx.getWidth() / 2
    local centerY = (gfx.getHeight() + 48) / 2

    options.scale(1, 1)

    local offsetX = options[7] - centerX
    local offsetY = options[8] - centerY
    local rotatedOffsetX = offsetX * math.cos(-rad) - offsetY * math.sin(-rad)
    local rotatedOffsetY = offsetX * math.sin(-rad) + offsetY * math.cos(-rad)
    options[7] = centerX + rotatedOffsetX
    options[8] = centerY + rotatedOffsetY

    options.rotate(rad)
    render.setCameraOptions(render.Transform.CAMERA, { transform = options })
end

-- The camera rotates counter-clockwise by cameraAngle, so inputs rotate clockwise to match.
local INPUT_ROTATION = {
    [45]  = action.Rotation.CW_45,
    [135] = action.Rotation.CW_135,
    [225] = action.Rotation.CCW_135,
    [315] = action.Rotation.CCW_45,
}

-- Rotates ev.dx/ev.dy before facing/attack/dig/move, keeping the other fields in sync.
event.objectDirection.add("APIsometricRotateInput", { order = "storeAction", sequence = -10 }, function(ev)
    local state = trapSystem.stateOf("IsometricTrap")
    if not state then return end
    -- Keyed on the player, not the body, which a bat form or possession swaps out.
    if not player.isPlayerEntity(ev.entity) then return end
    if not state.players[ev.entity.controllable.playerID] then return end

    local rotation = INPUT_ROTATION[state.angle]
    if not rotation then return end

    if type(ev.direction) == "number" then
        -- Stashes the pressed direction, which the sprite mirror follows instead of the world one.
        ev.apIsometricInputDirection = ev.direction
        ev.direction = action.rotateDirection(ev.direction, rotation)
    end
    if type(ev.action) == "number" then
        ev.action = action.rotateDirection(ev.action, rotation)
    end
    if type(ev.dx) == "number" and type(ev.dy) == "number" then
        ev.dx, ev.dy = action.rotate(ev.dx, ev.dy, rotation)
        ev.x = ev.entity.position.x + ev.dx
        ev.y = ev.entity.position.y + ev.dy
    end
end)

-- Re-points visual facing at the on-screen direction after the vanilla facing handler.
event.objectDirection.add("APIsometricFaceScreen", { order = "facingLate", sequence = 10 }, function(ev)
    local inputDir = ev.apIsometricInputDirection
    if not inputDir or ev.inhibitFacing then return end
    if ev.result == action.Result.INVALID or ev.result == action.Result.INHIBIT then return end
    facing.setVisualDirection(ev.entity, inputDir)
end)

event.renderEffects.add("APIsometricCharacterRotate", { order = "spriteCorrection", sequence = 1 }, function()
    if freezeFrame.isActive() or gameState.isPaused() then return end

    local state = trapSystem.stateOf("IsometricTrap")
    if not state then return end

    for entity in ecs.entitiesWithComponents({ "rotatedSprite", "controllable" }) do
        if state.players[entity.controllable.playerID] then
            -- Constant angle, never coupled to mirrorX, so the tilt does not flip with facing.
            entity.rotatedSprite.angle = state.angle * math.pi / 180
            -- Remembered so expiry can straighten a body the player has since left.
            state.tilted[entity.id] = true
        else
            entity.rotatedSprite.angle = 0
            state.tilted[entity.id] = nil
        end
    end
end)

trapSystem.define({
    name           = "IsometricTrap",
    flyaway        = "Isometric!",
    voice          = "voiceConfused",
    duration       = 20,
    clock          = trapSystem.Clock.REAL,
    -- Camera and sprite angles only.
    storage        = trapSystem.Storage.VOLATILE,
    renderSequence = 3,
    start          = function(ctx)
        ctx.state.angle   = rng.choice(ANGLE_LIST, ctx.channel)
        ctx.state.players = {}
        ctx.state.tilted  = {}
    end,
    apply          = function(ctx)
        if not player.isPlayerEntity(ctx.entity) then return false end
        ctx.state.players[ctx.entity.controllable.playerID] = true
    end,
    render         = function(ctx) rotateCamera(ctx.state.angle) end,
    expire         = function(ctx)
        for id in pairs(ctx.state.tilted or {}) do
            local entity = ecs.getEntityByID(id)
            if entity and entity.rotatedSprite then
                entity.rotatedSprite.angle = 0
            end
        end
    end,
})
