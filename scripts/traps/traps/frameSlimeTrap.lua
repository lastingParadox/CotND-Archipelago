local gfx    = require "system.gfx.GFX"
local render = require "necro.render.Render"
local timer  = require "system.utils.Timer"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local SLIME_TYPES = {
    { texture = "ext/entities/slime_green.png",  numFrames = 4, frameW = 26, frameH = 26, yOff = 0 },
    { texture = "ext/entities/slime_blue.png",   numFrames = 8, frameW = 26, frameH = 25, yOff = 1 },
    { texture = "ext/entities/slime_orange.png", numFrames = 4, frameW = 26, frameH = 26, yOff = 0 },
    { texture = "ext/entities/slime_ice.png",    numFrames = 4, frameW = 26, frameH = 26, yOff = 0 },
    { texture = "ext/entities/slime_fire.png",   numFrames = 4, frameW = 26, frameH = 26, yOff = 0 },
    { texture = "ext/entities/slime_purple.png", numFrames = 4, frameW = 26, frameH = 26, yOff = 0 },
    { texture = "ext/entities/slime_black.png",  numFrames = 4, frameW = 26, frameH = 26, yOff = 0 },
    { texture = "ext/entities/slime_white.png",  numFrames = 4, frameW = 26, frameH = 26, yOff = 0 },
}
local SLIME_RENDER_SIZE = 48
local ANIM_FPS = 8
local MIN_DIST = 56

local slimes = {}
slimes = script.persist(function() return slimes end)

local function addSlime()
    local typeIndex = (#slimes % #SLIME_TYPES) + 1
    local animOffset = math.random() * 10
    local bestNx = math.random() * 0.88 + 0.06
    local bestNy = math.random() * 0.88 + 0.06
    local bestMinDist = -1
    for _ = 1, 30 do
        local nx = math.random() * 0.88 + 0.06
        local ny = math.random() * 0.88 + 0.06
        local w = gfx.getWidth()
        local h = gfx.getHeight()
        local cx = nx * w
        local cy = ny * h
        local nearestDist = math.huge
        for _, s in ipairs(slimes) do
            local dx = cx - s.nx * w
            local dy = cy - s.ny * h
            local d = math.sqrt(dx * dx + dy * dy)
            if d < nearestDist then nearestDist = d end
        end
        if nearestDist >= MIN_DIST then
            bestNx, bestNy = nx, ny
            break
        elseif nearestDist > bestMinDist then
            bestMinDist = nearestDist
            bestNx, bestNy = nx, ny
        end
    end
    slimes[#slimes + 1] = { nx = bestNx, ny = bestNy, typeIndex = typeIndex, animOffset = animOffset }
end

event.renderGlobalHUD.add("APFrameSlimeTrapRender", { order = "textOverlay" }, function()
    if #slimes == 0 then return end
    local buf = render.getBuffer(render.Buffer.UI_HUD)
    local t = timer.getGlobalTime()
    local w = gfx.getWidth()
    local h = gfx.getHeight()
    for _, slime in ipairs(slimes) do
        local st = SLIME_TYPES[slime.typeIndex]
        local frame = math.floor((t + slime.animOffset) * ANIM_FPS) % st.numFrames
        local px = math.floor(slime.nx * w - SLIME_RENDER_SIZE * 0.5)
        local py = math.floor(slime.ny * h - SLIME_RENDER_SIZE * 0.5)
        buf.draw({
            texture = st.texture,
            rect    = { px, py, SLIME_RENDER_SIZE, SLIME_RENDER_SIZE },
            texRect = { frame * st.frameW, st.yOff, st.frameW, st.frameH },
            z       = 10,
        })
    end
end)

event.gameStateReset.add("APFrameSlimeTrapReset", { order = "resetRunVariables" }, function()
    slimes = {}
end)

TrapHandler.register("FrameSlimeTrap", makeSimpleTrap({
    flyawayText = "Slimed!",
    after = function()
        for _ = 1, 5 do addSlime() end
    end,
}))
