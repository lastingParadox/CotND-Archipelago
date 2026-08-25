local gfx          = require "system.gfx.GFX"
local render       = require "necro.render.Render"
local rng          = require "necro.game.system.RNG"
local currentLevel = require "necro.game.level.CurrentLevel"
local turn         = require "necro.cycles.Turn"

local makeCameraTrap = (require "AP.scripts.traps.factories.makeCameraTrap").makeCameraTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local timestamps = { Rotate = 0, FlipHorizontal = 0, FlipVertical = 0, ZoomIn = 0, ZoomOut = 0 }
local rotateAngle = 0
timestamps, rotateAngle = script.persist(function()
    return timestamps, rotateAngle
end)

---Applies scale, then the matching translation mirror/scale, then rotation,
---all around the screen center.
local function transformCamera(scaleX, scaleY, angleDeg)
    local options = render.getCameraOptions(render.Transform.CAMERA).transform
    local angle   = angleDeg * math.pi / 180
    local centerX = gfx.getWidth() / 2
    local centerY = (gfx.getHeight() + 48) / 2

    options.scale(scaleX, scaleY)

    local offsetX = (options[7] - centerX) * scaleX
    local offsetY = (options[8] - centerY) * scaleY
    options[7] = centerX + offsetX * math.cos(-angle) - offsetY * math.sin(-angle)
    options[8] = centerY + offsetX * math.sin(-angle) + offsetY * math.cos(-angle)

    options.rotate(angle)
    render.setCameraOptions(render.Transform.CAMERA, { transform = options })
end

---Each variant runs on its own timer/render listener; TrapLink can force one
---via args.variant, otherwise the trap picks a variant at random.
local VARIANTS = {
    Rotate = {
        flyawayText = "Rotate!",
        voice       = "voiceConfused",
        sequence    = 2,
        applyEffect = function() transformCamera(1, 1, rotateAngle) end,
        onTrigger   = function(channel) rotateAngle = rng.range(0, 360, channel) or 180 end,
        onExpire    = function() rotateAngle = 0 end,
    },
    FlipHorizontal = {
        flyawayText = "Flip!",
        sequence    = 3,
        applyEffect = function() transformCamera(1, -1, 0) end,
    },
    FlipVertical = {
        flyawayText = "Flip!",
        sequence    = 2,
        applyEffect = function() transformCamera(-1, 1, 0) end,
    },
    ZoomIn = {
        flyawayText = "Zoomed In!",
        voice       = "voiceConfused",
        sequence    = 2,
        applyEffect = function() transformCamera(2.5, 2.5, 0) end,
    },
    ZoomOut = {
        flyawayText = "Zoomed Out!",
        voice       = "voiceConfused",
        sequence    = 2,
        applyEffect = function() transformCamera(0.25, 0.25, 0) end,
    },
}

-- Sorted iteration keeps the variant list identical on every client.
local variantNames = {}
for name in pairs(VARIANTS) do
    table.insert(variantNames, name)
end
table.sort(variantNames)

local trapFns = {}
for _, name in ipairs(variantNames) do
    local cfg = VARIANTS[name]
    trapFns[name] = makeCameraTrap({
        name         = name .. "CameraTrap",
        duration     = 20,
        flyawayText  = cfg.flyawayText,
        voice        = cfg.voice,
        sequence     = cfg.sequence,
        isActive     = function() return timestamps[name] ~= 0 end,
        getTimestamp = function() return timestamps[name] end,
        setTimestamp = function(v) timestamps[name] = v end,
        applyEffect  = cfg.applyEffect,
        onTrigger    = cfg.onTrigger,
        onExpire     = cfg.onExpire,
    })
end

TrapHandler.register("CameraTrap", function(ev, args, ticket)
    local variant = args and args.variant
    if not (variant and trapFns[variant]) then
        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        variant = rng.choice(variantNames, channel)
    end
    return trapFns[variant](ev, args, ticket)
end)
