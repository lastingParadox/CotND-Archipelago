local controls = require("necro.config.Controls")
local cutscene = require("necro.client.Cutscene")
local fileIO = require("system.game.FileIO")
local music = require("necro.audio.Music")
local player = require("necro.game.character.Player")
local rng = require("necro.game.system.RNG")
local settings = require("necro.config.Settings")
local settingsStorage = require("necro.config.SettingsStorage")
local stateControl = require("necro.client.StateControl")

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apLog = require("AP.scripts.utils.log").apLog
local trapSystem = require("AP.scripts.traps.trapSystem")

local KNOWN_STORIES = {
    { character = "cadence",  index = 0 },
    { character = "cadence",  index = 1 },
    { character = "cadence",  index = 2 },
    { character = "cadence",  index = 3 },
    { character = "cadence",  index = 4 },
    { character = "cadence",  index = 5 },
    { character = "melody",   index = 0 },
    { character = "melody",   index = 1 },
    { character = "melody",   index = 2 },
    { character = "melody",   index = 3 },
    { character = "melody",   index = 4 },
    { character = "melody",   index = 5 },
    { character = "aria",     index = 0 },
    { character = "aria",     index = 1 },
    { character = "aria",     index = 2 },
    { character = "aria",     index = 3 },
    { character = "aria",     index = 4 },
    { character = "aria",     index = 5 },
    { character = "nocturna", index = 1 },
    { character = "nocturna", index = 2 },
    { character = "nocturna", index = 3 },
    { character = "nocturna", index = 4 },
    { character = "nocturna", index = 5 },
    { character = "nocturna", index = 6 },
}

local storyPool = nil
local trapCutsceneActive = false
local shouldFadeInMusicOnUnpause = false

-- sequence = -1 runs before the built-in "cutscene" handler so we consume inputs first
event.tick.add("APCutsceneTrapBlockSkip", { order = "cutscene", sequence = -1 }, function()
    if trapCutsceneActive and cutscene.isActive() then
        controls.consumeAnyAction()
        controls.consumeMiscKey(controls.Misc.SELECT)
        controls.consumeMiscKey(controls.Misc.PAUSE)
    end
end)

-- order "menu" runs after the engine's "music" order, so musicTime is correct when we fade in
event.gameStateUnpause.add("APCutsceneTrapFadeInMusic", { order = "menu" }, function()
    if shouldFadeInMusicOnUnpause then
        shouldFadeInMusicOnUnpause = false
        music.fadeIn(0.5)
    end
end)

local function buildStoryPool()
    local pool = {}
    for _, entry in ipairs(KNOWN_STORIES) do
        local path = ("ext/video/cutscene_%s_%d.ogv"):format(entry.character, entry.index)
        if fileIO.exists(path) then
            pool[#pool + 1] = entry
        end
    end
    return pool
end

local clearOverridePending = false

local function announce()
    for _, entity in ipairs(player.getPlayerEntities()) do
        if not (entity and entity.playableCharacter) then goto continue end
        apFlyaways.addToFlyawayQueue({ entity = entity, text = "Cutscene!" })
        ::continue::
    end
end

event.cutsceneEnd.add("APCutsceneTrapClearOverride", { order = "cutscene" }, function()
    if clearOverridePending then
        clearOverridePending = false
        trapCutsceneActive = false
        shouldFadeInMusicOnUnpause = true
        settingsStorage.set("video.cutscene.displayModeStory", nil, settings.Layer.SCRIPT_OVERRIDE)
        stateControl.unpauseBeats()
        announce()
        -- Frees the slot, so a queued Cutscene Trap can start its own screening.
        trapSystem.stop("CutsceneTrap")
    end
end)

-- One screening at a time, ended from cutsceneEnd rather than by a clock.
trapSystem.define({
    name     = "CutsceneTrap",
    -- The announcement comes at the end, off the back of cutsceneEnd.
    announce = trapSystem.Announce.NONE,
    -- Video playback and a settings override; nothing here is simulated.
    storage  = trapSystem.Storage.VOLATILE,
    stateful = true,
    guard    = function()
        -- A cutscene from anywhere else still blocks this one.
        return not cutscene.isActive()
    end,
    start    = function(ctx)
        if storyPool == nil then
            storyPool = buildStoryPool()
        end

        if #storyPool == 0 then
            cutscene.play({
                type     = cutscene.Type.SPLASH,
                image    = "ext/mainmenu/mainmenu.png",
                duration = 5,
            })

            -- No override to unwind and no pause to lift, so nothing to wait for.
            announce()
            trapSystem.stop("CutsceneTrap")

            return true
        end

        local entry = rng.choice(storyPool, ctx.channel)
        apLog(("Cutscene trap picked %s_%d of %d"):format(entry.character, entry.index, #storyPool))

        -- Forces story cutscenes on regardless of the user display setting.
        settingsStorage.set("video.cutscene.displayModeStory",
            cutscene.DisplayMode.ALWAYS, settings.Layer.SCRIPT_OVERRIDE)
        clearOverridePending = true
        trapCutsceneActive = true

        cutscene.play({
            type      = cutscene.Type.STORY,
            character = entry.character,
            index     = entry.index,
        })
        stateControl.pauseWithoutMenu()

        return true
    end,
})
