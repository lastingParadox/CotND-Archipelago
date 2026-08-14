local ecs = require "system.game.Entities"
local lightSource = require "necro.game.vision.LightSource"
local sound = require "necro.audio.Sound"

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")

handlers.register("SetTrapLink", function(message, ctx)
    apLog("TrapLink setting changed: " .. tostring(message.traplink or false))
    apStorage.saveData.traplink = message.traplink or false
    local traplinkState = apStorage.saveData.traplink and "enabled" or "disabled"
    for entity in ecs.entitiesWithComponents({ "playableCharacter" }) do
        if entity.controllable.playerID ~= 0 then
            apFlyaways.addToFlyawayQueue({
                entity = entity,
                text = "TrapLink " .. traplinkState .. "!"
            })
            sound.playFromEntity("shrineActivate", entity)
        end
    end

    -- sync shrine visual
    for entity in ecs.entitiesWithComponents({ "AP_traplinkShrine" }) do
        entity.shrine.active = apStorage.saveData.traplink
        entity.spriteSheet.frameX = apStorage.saveData.traplink and 2 or 1
        lightSource.update(entity)
    end
end)
