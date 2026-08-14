local gameState = require("necro.client.GameState")
local sound     = require("necro.audio.Sound")
local subtitles = require("necro.render.hud.Subtitles")
local timer     = require("system.utils.Timer")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

-- Durations approximate each clip's spoken length; LINE_GAP pads between
-- lines so clips never talk over each other.
local LINE_GAP = 0.75

local TUTORIAL_LINES = {
    { sound = "cadenceTutorial1", text = "If I'm gonna survive this, I'll have to remember what uncle Eli taught me.", duration = 5 },
    { sound = "cadenceTutorial2", text = "Every opponent has a predictable pattern, he said. Learn that pattern and you won't suffer so much as a scratch.", duration = 7 },
    { sound = "cadenceTutorial3", text = "That green guy didn't move at all, and this blue one just moves up and then down. So if I attack him from the side, I'll never get hurt.", duration = 8 },
    { sound = "cadenceTutorial4", text = "A broadsword! Not as sharp as I'm used to, but I bet it can still take out 3 enemies in one shot.", duration = 7 },
    { sound = "cadenceTutorial5", text = "Looks like those skeletons put their hands in the air when they're about to jump. If I'm in the way when they move, it's gonna hurt.", duration = 8 },
    { sound = "cadenceTutorial6", text = "That trap is mostly harmless, but Eli warned me of deadlier traps to come.", duration = 6 },
}

local tutorialQueue = {}
local nextLineTime  = 0
tutorialQueue, nextLineTime = script.persist(function()
    return tutorialQueue, nextLineTime
end)

-- Tick-driven so lines keep playing while the player stands still (the old
-- turn-driven scheduler stalled between player actions).
event.tick.add("APExpositionTrapPlayLines", { order = "lobby", sequence = 3 }, function()
    if #tutorialQueue == 0 then return end
    if gameState.isPaused() then return end
    if timer.getGlobalTime() < nextLineTime then return end
    local line = table.remove(tutorialQueue, 1)
    sound.playUI(line.sound)
    subtitles.say(line.text)
    nextLineTime = timer.getGlobalTime() + line.duration + LINE_GAP
end)

event.gameStateReset.add("APExpositionTrapReset", { order = "resetRunVariables" }, function()
    tutorialQueue = {}
    nextLineTime  = 0
end)

TrapHandler.register("ExpositionTrap", makeSimpleTrap({
    flyawayText = "Exposition!",
    setup = function()
        if #tutorialQueue > 0 then return false end
    end,
    after = function()
        for _, line in ipairs(TUTORIAL_LINES) do
            tutorialQueue[#tutorialQueue + 1] = line
        end
        nextLineTime = 0
    end,
}))
