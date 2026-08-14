local ecs = require "system.game.Entities"
local lightSource = require "necro.game.vision.LightSource"
local sound = require("necro.audio.Sound")

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")

handlers.register("SetDeathLink", function(message, ctx)
    apLog("Deathlink setting changed: " .. tostring(message.deathlink or false))
    apStorage.saveData.deathlink = message.deathlink or false
    local deathlinkState = "disabled"
    if apStorage.saveData.deathlink then deathlinkState = "enabled" end
    for entity in ecs.entitiesWithComponents({ "playableCharacter" }) do
        if entity.controllable.playerID ~= 0 then
            apFlyaways.addToFlyawayQueue({
                entity = entity,
                text = "Deathlink " .. deathlinkState .. "!"
            })
            sound.playFromEntity("shrineActivate", entity)
        end
    end

    -- sync shrine visual
    for entity in ecs.entitiesWithComponents({ "AP_deathlinkShrine" }) do
        entity.shrine.active = apStorage.saveData.deathlink
        entity.spriteSheet.frameX = apStorage.saveData.deathlink and 2 or 1
        lightSource.update(entity)
    end
end)
