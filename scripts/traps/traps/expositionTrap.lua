local gameState = require("necro.client.GameState")
local sound     = require("necro.audio.Sound")
local subtitles = require("necro.render.hud.Subtitles")
local timer     = require("system.utils.Timer")

local trapSystem = require("AP.scripts.traps.trapSystem")

-- Durations approximate each clip's spoken length, with LINE_GAP padding between lines.
local LINE_GAP = 0.75

local TUTORIAL_LINES = {
    { sound = "cadenceTutorial1", text = "If I'm gonna survive this, I'll have to remember what uncle Eli taught me.", duration = 5 },
    { sound = "cadenceTutorial2", text = "Every opponent has a predictable pattern, he said. Learn that pattern and you won't suffer so much as a scratch.", duration = 7 },
    { sound = "cadenceTutorial3", text = "That green guy didn't move at all, and this blue one just moves up and then down. So if I attack him from the side, I'll never get hurt.", duration = 8 },
    { sound = "cadenceTutorial4", text = "A broadsword! Not as sharp as I'm used to, but I bet it can still take out 3 enemies in one shot.", duration = 7 },
    { sound = "cadenceTutorial5", text = "Looks like those skeletons put their hands in the air when they're about to jump. If I'm in the way when they move, it's gonna hurt.", duration = 8 },
    { sound = "cadenceTutorial6", text = "That trap is mostly harmless, but Eli warned me of deadlier traps to come.", duration = 6 },
}

-- Backstop only; the trap ends itself once the queue runs dry.
local MAX_SECONDS = 60

trapSystem.define({
    name     = "ExpositionTrap",
    flyaway  = "Exposition!",
    duration = MAX_SECONDS,
    clock    = trapSystem.Clock.REAL,
    -- A speech scheduler: audio and subtitles, nothing simulated.
    storage  = trapSystem.Storage.VOLATILE,
    start    = function(ctx)
        ctx.state.index    = 1
        ctx.state.nextTime = 0
        return true
    end,
    -- Tick-driven so lines keep playing while the player stands still.
    tick     = function(ctx)
        if gameState.isPaused() then return end
        if timer.getGlobalTime() < ctx.state.nextTime then return end

        local line = TUTORIAL_LINES[ctx.state.index]
        if not line then return trapSystem.stop("ExpositionTrap") end

        sound.playUI(line.sound)
        subtitles.say(line.text)

        ctx.state.index    = ctx.state.index + 1
        ctx.state.nextTime = timer.getGlobalTime() + line.duration + LINE_GAP
    end,
})
