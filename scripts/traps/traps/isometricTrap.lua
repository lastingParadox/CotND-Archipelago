local action = require "necro.game.system.Action"
local ecs    = require "system.game.Entities"
local facing = require "necro.game.character.Facing"
local gfx    = require "system.gfx.GFX"
local player = require "necro.game.character.Player"
local render = require "necro.render.Render"
local rng    = require "necro.game.system.RNG"
local freezeFrame = require "necro.render.FreezeFrame"
local gameState   = require "necro.client.GameState"

local makeCameraTrap = (require "AP.scripts.traps.factories.makeCameraTrap").makeCameraTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local ANGLE_LIST = { 45, 135, 225, 315 }

local trapTimestamp = 0
local isoEntityIDs  = {}
local cameraAngle   = 45
isoEntityIDs, trapTimestamp, cameraAngle = script.persist(function()
    return isoEntityIDs, trapTimestamp, cameraAngle
end)

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

-- The camera is rotated counter-clockwise by cameraAngle, so movement inputs
-- rotate clockwise by the same amount: a pressed direction then moves toward
-- that on-screen direction, which is a world diagonal (e.g. at 45°, Up → NE).
local INPUT_ROTATION = {
    [45]  = action.Rotation.CW_45,
    [135] = action.Rotation.CW_135,
    [225] = action.Rotation.CCW_135,
    [315] = action.Rotation.CCW_45,
}

-- Runs before facing/attack/dig/move so every downstream handler sees the
-- rotated direction. Movement reads ev.dx/ev.dy (not ev.action), so rotate the
-- delta with the engine's own action.rotate and keep the other fields in sync.
event.objectDirection.add("APIsometricRotateInput", { order = "storeAction", sequence = -10 }, function(ev)
    if trapTimestamp == 0 then return end
    if not (ev.entity.playableCharacter and isoEntityIDs[ev.entity.id]) then return end
    local rotation = INPUT_ROTATION[cameraAngle]
    if not rotation then return end

    if type(ev.direction) == "number" then
        -- Left/right sprite mirror must follow the pressed (on-screen) direction,
        -- not the rotated world direction (their horizontal signs disagree at
        -- 135°/225°). Stash it for the facing override below.
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

-- After the vanilla facing handler (which mirrors from the world direction),
-- re-point the visual facing at the on-screen direction so the character faces
-- the way it visibly moves. Gameplay direction stays world-space for aiming.
event.objectDirection.add("APIsometricFaceScreen", { order = "facingLate", sequence = 10 }, function(ev)
    local inputDir = ev.apIsometricInputDirection
    if not inputDir or ev.inhibitFacing then return end
    if ev.result == action.Result.INVALID or ev.result == action.Result.INHIBIT then return end
    facing.setVisualDirection(ev.entity, inputDir)
end)

event.renderEffects.add("APIsometricCharacterRotate", { order = "spriteCorrection", sequence = 1 }, function()
    if freezeFrame.isActive() or gameState.isPaused() or trapTimestamp == 0 then return end

    for entity in ecs.entitiesWithComponents({ "rotatedSprite", "playableCharacter" }) do
        if isoEntityIDs[entity.id] then
            -- Constant angle keeps the isometric tilt consistent regardless of
            -- facing. (Do NOT couple to mirrorX like slideSwayEffect does — that
            -- is a facing-dependent lean, which flips the tilt when facing left.)
            entity.rotatedSprite.angle = cameraAngle * math.pi / 180
        else
            entity.rotatedSprite.angle = 0
        end
    end
end)

TrapHandler.register("IsometricTrap", makeCameraTrap({
    name         = "IsometricTrap",
    duration     = 20,
    flyawayText  = "Isometric!",
    voice        = "voiceConfused",
    sequence     = 3,
    isActive     = function() return trapTimestamp ~= 0 end,
    getTimestamp = function() return trapTimestamp end,
    setTimestamp = function(v) trapTimestamp = v end,
    applyEffect  = function() rotateCamera(cameraAngle) end,
    onTrigger    = function(channel)
        cameraAngle = rng.choice(ANGLE_LIST, channel)
        for _, entity in ipairs(player.getPlayerEntities()) do
            if entity and entity.playableCharacter then
                isoEntityIDs[entity.id] = true
            end
        end
    end,
    onExpire     = function()
        for _, entity in ipairs(player.getPlayerEntities()) do
            if isoEntityIDs[entity.id] and entity.rotatedSprite then
                entity.rotatedSprite.angle = 0
            end
        end
        isoEntityIDs = {}
    end,
}))
