local color   = require "system.utils.Color"
local overlay = require "necro.render.Overlay"
local timer   = require "system.utils.Timer"

local trapSystem = require "AP.scripts.traps.trapSystem"

local FADE_TIME = timer.seconds(1.5)
local HOLD_TIME = timer.seconds(1)

trapSystem.define({
    name    = "FakeTransitionTrap",
    flyaway = "Fake Transition!",
    voice   = "voiceConfused",
    finish  = function()
        overlay.add({
            color   = color.BLACK,
            fadeIn  = FADE_TIME,
            sustain = HOLD_TIME,
            fadeOut = FADE_TIME,
        })
    end,
})
