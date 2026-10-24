local action = require "necro.game.system.Action"
local localCoop = require "necro.client.LocalCoop"
local menu = require "necro.menu.Menu"
local settingsMenu = require "necro.menu.settings.SettingsMenu"
local sound = require "necro.audio.Sound"
local turn = require "necro.cycles.Turn"

local apClient = require("AP.scripts.client.client")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local MENU_NAME = "AP_songRandomizer"

local MODES = {
    { value = "OFF", name = "Off", desc = "Archipelago runs play every song where it normally plays" },
    { value = "RANDOM_ARTIST", name = "Random artist", desc = "Every area keeps its own song, played by a random artist" },
    { value = "SHUFFLE_SONGS", name = "Shuffle songs", desc = "Every song the picked artists have is dealt out across the run" },
}

local ARTIST_SCOPES = {
    { value = "PER_RUN",   name = "Per run",   desc = "A random artist will be played each run" },
    { value = "PER_ZONE",  name = "Per zone",  desc = "A random artist will be played each zone" },
    { value = "PER_FLOOR", name = "Per floor", desc = "A random artist will be played each floor" },
}

local SEEDINGS = {
    { value = "PER_CHARACTER", name = "Per character", desc = "Every character keeps its own songlist, drawn from the multiworld seed" },
    { value = "FULLY_RANDOM",  name = "Fully random",  desc = "A new songlist every run" },
}

local DUPLICATES = {
    { value = "MINIMAL",  name = "Minimal",  desc = "Each song is played once, by whichever artist gets it" },
    { value = "PARTIAL",  name = "Partial",  desc = "A song can return in another artist's version" },
    { value = "COMPLETE", name = "Complete", desc = "Any song can be played repeatedly" },
}

local function findChoice(choices, value)
    for index, choice in ipairs(choices) do
        if choice.value == value then
            return index, choice
        end
    end

    return 1, choices[1]
end

-- One setting as a menu row; only the host can change it, and the change lands when Python echoes it back.
local function choiceEntry(key, label, choices)
    local function current()
        return select(2, findChoice(choices, progression.getSongRandomizer()[key]))
    end

    local function step(direction)
        return function()
            local index = findChoice(choices, progression.getSongRandomizer()[key])
            local value = choices[(index - 1 + direction) % #choices + 1].value

            apClient.sendPacket({ datatype = "SetSongRandomizer", song_randomizer = { [key] = value } })
        end
    end

    return {
        id = key,
        label = function()
            return string.format("%s: %s", label, current().name)
        end,
        customDesc = function()
            if not apClient.isHost() then
                return "Only the host can change the Archipelago song randomizer"
            end

            return current().desc
        end,
        enableIf = function()
            return apClient.isHost()
        end,
        action = step(1),
        leftAction = step(-1),
        rightAction = step(1),
    }
end

event.menu.add("apSongRandomizerMenu", MENU_NAME, function(ev)
    local mode = progression.getSongRandomizer().mode
    local entries = { choiceEntry("mode", "AP Mode", MODES) }

    if mode == "RANDOM_ARTIST" then
        entries[#entries + 1] = choiceEntry("artistScope", "New artist", ARTIST_SCOPES)
    elseif mode == "SHUFFLE_SONGS" then
        entries[#entries + 1] = choiceEntry("seeding", "Shuffle", SEEDINGS)
        entries[#entries + 1] = choiceEntry("duplicates", "Song duplication", DUPLICATES)
    end

    entries[#entries + 1] = {
        id = "characters",
        label = "Toggle Characters",
        customDesc = "Pick which characters will be affected by the song randomizer, here and outside Archipelago",
        action = function()
            menu.open("CustomArtists_songRandomizerCharacters")
        end,
    }

    entries[#entries + 1] = {
        id = "customArtists",
        label = "Toggle Custom Artists",
        customDesc = "Pick which artists will be included in the song randomizer, here and outside Archipelago",
        action = function()
            menu.open("CustomArtists_grid")
        end,
    }

    entries[#entries + 1] = { height = 0 }
    entries[#entries + 1] = {
        id = "done",
        label = "Done",
        sound = "UIBack",
        action = function()
            menu.close()
        end,
    }

    local footer, tickCallback = settingsMenu.createDynamicFooter({ customDesc = true })
    entries[#entries + 1] = footer

    ev.menu = {
        label = "AP Song Randomizer",
        entries = entries,
        tickCallback = tickCallback,
        escapeAction = function()
            menu.close()
        end,
    }
end)

local menuTurnID = -1

-- The shrine standing in the AP lobby opens this menu in place of Custom Artists' own.
event.objectInteract.override("CustomArtists_showSongRandomizerMenu", function(func, ev)
    if not apUtils.isAPContext(ev.entity) then return func(ev) end

    local playerID = ev.interactor and ev.interactor.controllable and ev.interactor.controllable.playerID or 0

    if playerID ~= 0 and localCoop.isLocal(playerID) and not menu.isOpen() and menuTurnID < turn.getCurrentTurnID() then
        menuTurnID = turn.getCurrentTurnID()
        menu.suppressKeyControlForTick()
        menu.open(MENU_NAME)
        sound.playUI("minibossShake")
    end

    ev.result = action.Result.INTERACT
end)

event.gameStateLevel.add("apResetSongRandomizerMenuTurn", "resetLevelVariables", function()
    menuTurnID = -1
end)

local lastSettings = nil

-- A change lands after the click (Python's echo, or APState on a joiner), so the open menu rebuilds then.
event.tick.add("apSongRandomizerMenuWatch", { order = "lobby", sequence = 10 }, function()
    local settings = progression.getSongRandomizer()
    local key = settings.mode .. settings.artistScope .. settings.seeding .. settings.duplicates

    if key ~= lastSettings then
        lastSettings = key

        if menu.isNamedOpen(MENU_NAME) then
            menu.update()
        end
    end
end)
