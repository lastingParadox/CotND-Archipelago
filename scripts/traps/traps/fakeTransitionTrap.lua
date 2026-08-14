local color   = require "system.utils.Color"
local overlay = require "necro.render.Overlay"
local timer   = require "system.utils.Timer"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local FADE_TIME = timer.seconds(1.5)
local HOLD_TIME = timer.seconds(1)

TrapHandler.register("FakeTransitionTrap", makeSimpleTrap({
    flyawayText = "Fake Transition!",
    voice       = "voiceConfused",
    after       = function()
        overlay.add({
            color   = color.BLACK,
            fadeIn  = FADE_TIME,
            sustain = HOLD_TIME,
            fadeOut = FADE_TIME,
        })
    end,
}))
