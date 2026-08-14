local player      = require("necro.game.character.Player")
local screenShake = require("necro.render.ScreenShake")
local sound       = require("necro.audio.Sound")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local SHAKE_DURATION  = 0.5
local SHAKE_INTENSITY = 8
local SHAKE_RANGE     = 99999

local shakeActive = false
shakeActive = script.persist(function()
    return shakeActive
end)

event.turn.add("APShakeTrapPulse", { order = "frame1" }, function()
    if not shakeActive then return end
    local players = player.getPlayerEntities()
    local anchor = players and players[1]
    if anchor and anchor.position then
        screenShake.createAtPosition(anchor.position.x, anchor.position.y, SHAKE_DURATION, SHAKE_INTENSITY, SHAKE_RANGE)
    end
end)

event.gameStateLevel.add("APShakeTrapClearOnLevel", { order = "splitScreen" }, function()
    shakeActive = false
end)

event.gameStateReset.add("APShakeTrapClearOnReset", { order = "resetRunVariables" }, function()
    shakeActive = false
end)

TrapHandler.register("ShakeTrap", makeSimpleTrap({
    flyawayText   = "Earthquake!",
    alwaysSucceed = true,
    setup = function()
        if shakeActive then return false end
        shakeActive = true
        -- Fire the first shake immediately using the first player as anchor.
        local players = player.getPlayerEntities()
        local anchor = players and players[1]
        if anchor and anchor.position then
            screenShake.createAtPosition(anchor.position.x, anchor.position.y, SHAKE_DURATION, SHAKE_INTENSITY, SHAKE_RANGE)
        end
    end,
    action = function(entity)
        sound.play("rockFall", entity.position.x, entity.position.y)
    end,
}))
