local screenShake = require("necro.render.ScreenShake")
local sound       = require("necro.audio.Sound")

local trapSystem = require("AP.scripts.traps.trapSystem")

local SHAKE_DURATION  = 0.5
local SHAKE_INTENSITY = 8
local SHAKE_RANGE     = 99999

local function shakeAt(entity)
    if not (entity and entity.position) then return end
    screenShake.createAtPosition(entity.position.x, entity.position.y, SHAKE_DURATION, SHAKE_INTENSITY, SHAKE_RANGE)
end

trapSystem.define({
    name     = "ShakeTrap",
    flyaway  = "Earthquake!",
    -- A camera effect pulsed off the first player for the rest of the floor.
    storage  = trapSystem.Storage.VOLATILE,
    stateful = true,
    start    = function(ctx)
        shakeAt(ctx.players[1].entity)
        return true
    end,
    apply    = function(ctx)
        sound.play("rockFall", ctx.entity.position.x, ctx.entity.position.y)
    end,
    tick     = function(ctx)
        shakeAt(ctx.players[1] and ctx.players[1].entity)
    end,
})
