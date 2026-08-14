local controls = require("necro.config.Controls")
local cutscene = require("necro.client.Cutscene")
local fileIO = require("system.game.FileIO")
local music = require("necro.audio.Music")
local player = require("necro.game.character.Player")
local rng = require("necro.game.system.RNG")
local settings = require("necro.config.Settings")
local settingsStorage = require("necro.config.SettingsStorage")
local stateControl = require("necro.client.StateControl")
local turn = require("necro.cycles.Turn")

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apReplay = require("AP.scripts.utils.apReplay")
local TrapHandler = require("AP.scripts.traps.trapHandler")

local REPLAY_KEY = "cutsceneTrap"

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
local trapCutscenePendingSuccess = false
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

event.cutsceneEnd.add("APCutsceneTrapClearOverride", { order = "cutscene" }, function()
    if clearOverridePending then
        clearOverridePending = false
        trapCutsceneActive = false
        trapCutscenePendingSuccess = true
        shouldFadeInMusicOnUnpause = true
        settingsStorage.set("video.cutscene.displayModeStory", nil, settings.Layer.SCRIPT_OVERRIDE)
        stateControl.unpauseBeats()
    end
end)

local function cutsceneTrap(ev)
    if apReplay.seen(REPLAY_KEY) then return true end

    if trapCutscenePendingSuccess then
        trapCutscenePendingSuccess = false
        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end
            apFlyaways.addToFlyawayQueue({ entity = entity, text = "Cutscene!" })
            ::continue::
        end
        apReplay.mark(REPLAY_KEY)
        return true
    end

    if trapCutsceneActive then
        return false
    end

    if storyPool == nil then
        storyPool = buildStoryPool()
    end

    local channel = rng.makeChannel(turn.getCurrentTurnID())

    if #storyPool > 0 then
        local entry = rng.choice(storyPool, channel)
        local scene = {
            type      = cutscene.Type.STORY,
            character = entry.character,
            index     = entry.index,
        }
        -- force story cutscenes on regardless of user display setting, matching built-in debug commands
        settingsStorage.set("video.cutscene.displayModeStory", cutscene.DisplayMode.ALWAYS, settings.Layer.SCRIPT_OVERRIDE)
        clearOverridePending = true
        trapCutsceneActive = true

        cutscene.play(scene)
        stateControl.pauseWithoutMenu()

        return false
    else
        cutscene.play({
            type     = cutscene.Type.SPLASH,
            image    = "ext/mainmenu/mainmenu.png",
            duration = 5,
        })

        local trapSuccess = false
        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end
            apFlyaways.addToFlyawayQueue({ entity = entity, text = "Cutscene!" })
            trapSuccess = true
            ::continue::
        end
        if trapSuccess then apReplay.mark(REPLAY_KEY) end
        return trapSuccess
    end
end

TrapHandler.register("CutsceneTrap", cutsceneTrap)

return cutsceneTrap
