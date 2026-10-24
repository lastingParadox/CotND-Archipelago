local ecs = require "system.game.Entities"
local focus = require "necro.game.character.Focus"
local gameState = require "necro.client.GameState"

local apClient = require("AP.scripts.client.client")
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

-- Registered only while Custom Artists is loaded.
if pcall(require, "CustomArtists.scripts.randomizer.Randomizer") then
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
