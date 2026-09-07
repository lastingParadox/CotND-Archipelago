local gfx    = require "system.gfx.GFX"
local render = require "necro.render.Render"
local rng    = require "necro.game.system.RNG"

local trapSystem = require "AP.scripts.traps.trapSystem"

---Applies scale, then the matching translation mirror/scale, then rotation, around center.
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

---Five ways to make the screen unhelpful.
trapSystem.define({
    name           = "CameraTrap",
    duration       = 20,
    clock          = trapSystem.Clock.REAL,
    -- A camera transform, and nothing the simulation reads.
    storage        = trapSystem.Storage.VOLATILE,
    renderSequence = 2,
    variants = {
        Rotate         = { flyaway = "Rotate!",     voice = "voiceConfused" },
        FlipHorizontal = { flyaway = "Flip!" },
        FlipVertical   = { flyaway = "Flip!" },
        ZoomIn         = { flyaway = "Zoomed In!",  voice = "voiceConfused" },
        ZoomOut        = { flyaway = "Zoomed Out!", voice = "voiceConfused" },
    },
    start = function(ctx)
        ctx.state.variant = ctx.variantName
        if ctx.variantName == "Rotate" then
            ctx.state.angle = rng.range(0, 360, ctx.channel) or 180
        end
    end,
    render = function(ctx)
        local variant = ctx.state.variant

        if variant == "Rotate" then
            transformCamera(1, 1, ctx.state.angle)
        elseif variant == "FlipHorizontal" then
            transformCamera(1, -1, 0)
        elseif variant == "FlipVertical" then
            transformCamera(-1, 1, 0)
        elseif variant == "ZoomIn" then
            transformCamera(2.5, 2.5, 0)
        elseif variant == "ZoomOut" then
            transformCamera(0.25, 0.25, 0)
        end
    end,
})
