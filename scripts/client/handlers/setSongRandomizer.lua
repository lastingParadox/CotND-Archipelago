local ecs = require "system.game.Entities"
local sound = require "necro.audio.Sound"

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")
local progression = require("AP.scripts.client.progression")

local function describe(settings)
    if settings.mode == "RANDOM_ARTIST" then
        return "Songs played by random artists"
    elseif settings.mode == "SHUFFLE_SONGS" then
        return settings.seeding == "FULLY_RANDOM" and "Songs are fully random" or "Songs randomized per character"
    end

    return "Songs not randomized"
end

handlers.register("SetSongRandomizer", function(message)
    if type(message.song_randomizer) ~= "table" then return end

    local before = describe(progression.getSongRandomizer())
    apStorage.saveData.songRandomizer = message.song_randomizer

    local after = describe(progression.getSongRandomizer())
    apLog("Song randomizer set to " .. after)

    if after == before then return end

    for entity in ecs.entitiesWithComponents({ "playableCharacter" }) do
        if entity.controllable.playerID ~= 0 then
            apFlyaways.addToFlyawayQueue({
                entity = entity,
                text = after .. "!"
            })
            sound.playFromEntity("shrineActivate", entity)
        end
    end
end)
