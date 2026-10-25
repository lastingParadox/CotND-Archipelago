local chat = require "necro.client.Chat"
local ecs = require "system.game.Entities"
local focus = require "necro.game.character.Focus"
local gameState = require "necro.client.GameState"
local music = require "necro.audio.Music"
local hasDebugCommands, debugCommands = pcall(require, "necro.debug.DebugCommands")

local apClient = require("AP.scripts.client.client")
local apLog = require("AP.scripts.utils.log").apLog
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local apSongRandomizer = {}

-- The shrine frame Custom Artists shows for each mode.
local MODE_FRAMES = {
    OFF = 1,
    RANDOM_ARTIST = 2,
    SHUFFLE_SONGS = 3,
}

local lobbyTeleportPending = false

-- The AP lobby is a segment of the vanilla one, so the listener has to be standing in it -- except
-- while the teleport that puts them there is still queued, since the track is picked before it runs.
local function isAPListener()
    if not gameState.isInLobby() then
        return apUtils.isAPContext()
    end

    return apClient.isSessionConnected()
        and (lobbyTeleportPending or apUtils.isAPContext(focus.getFirst(focus.Flag.MUSIC_LAYER)))
end

--- Whether the AP settings decide the songs right now, rather than the Custom Artists menu's.
function apSongRandomizer.isOverriding()
    return isAPListener()
end

local hasRandomizer, randomizer = pcall(require, "CustomArtists.scripts.randomizer.Randomizer")

-- Registered only while Custom Artists is loaded.
if hasRandomizer then
    event.customArtistsSongRandomizer.add("apSongRandomizer", { order = "override" }, function(ev)
        if not apSongRandomizer.isOverriding() then return end

        local settings = progression.getSongRandomizer()

        ev.mode = settings.mode
        ev.artistScope = settings.artistScope
        ev.seeding = settings.seeding
        ev.duplicates = settings.duplicates
        ev.seed = ("%s-%d"):format(progression.getSeedName(), progression.getSlot())
        ev.source = "Archipelago Redux"
    end)
end

-- Set before the "level" pass picks the track, cleared once "splitScreen" has actually moved players.
event.gameStateLevel.add("apMarkAPLobbyTeleportPending", { order = "resetLevelVariables", sequence = 1 }, function()
    lobbyTeleportPending = gameState.isInLobby() and apClient.isSessionConnected()
end)

event.gameStateLevel.add("apClearAPLobbyTeleportPending", { order = "splitScreen", sequence = 1 }, function()
    lobbyTeleportPending = false
end)

-- Reports the settings the current track is dealt with, and whether AP is the one supplying them.
local function reportSongRandomizer()
    local lines = {
        ("connected=%s pending=%s apListener=%s"):format(tostring(apClient.isSessionConnected()),
            tostring(lobbyTeleportPending), tostring(isAPListener())),
    }

    if hasRandomizer then
        local config = randomizer.getConfig()
        lines[#lines + 1] = ("source=%s mode=%s seeding=%s seed=%s duplicates=%s"):format(tostring(config.source),
            tostring(config.mode), tostring(config.seeding), tostring(config.seed), tostring(config.duplicates))
    end

    local params = music.getParameters() or {}
    lines[#lines + 1] = ("track type=%s zone=%s floor=%s boss=%s"):format(tostring(params.type),
        tostring(params.zone), tostring(params.floor), tostring(params.boss))

    for _, line in ipairs(lines) do
        chat.addMessage({ name = "apSongs", text = line })
        apLog("apsongs: " .. line)
    end
end

if hasDebugCommands then
    debugCommands.register("apsongs", reportSongRandomizer)
end

-- Runs after Custom Artists pins every shrine to its own mode.
event.updateVisuals.add("apSongRandomizerShrineFrame", { order = "equipmentSprite", sequence = 1 }, function()
    if not gameState.isInLobby() or not apClient.isSessionConnected() then return end

    local frame = MODE_FRAMES[progression.getSongRandomizer().mode] or 1

    for entity in ecs.entitiesWithComponents({ "CustomArtists_interactableSongRandomizer", "spriteSheet", "position" }) do
        if apUtils.isAPContext(entity) then
            entity.spriteSheet.frameX = frame
        end
    end
end)

return apSongRandomizer
