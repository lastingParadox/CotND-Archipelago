local color = require "system.utils.Color"
local currentLevel = require "necro.game.level.CurrentLevel"
local damage = require "necro.game.system.Damage"
local ecs = require "system.game.Entities"
local gameDLC = require "necro.game.data.resource.GameDLC"
local render = require "necro.render.Render"
local sound = require "necro.audio.Sound"
local ui = require "necro.render.UI"
local visualExtent = require "necro.render.level.VisualExtent"

local apEventSync = require("AP.scripts.client.apEventSync")
local apFlags = require("AP.scripts.utils.flags")
local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local apTypes = require("AP.scripts.utils.types")
local apFollowerChain = require("AP.scripts.character.apFollowerChain")
local handlers = require("AP.scripts.client.initHandlers")

-- Translucency of the deathlink name tag, 0..1, passed to drawText as `opacity`.
local MARV_TAG_OPACITY = 0.5

local function applyDeathlink(message)
    apLog("Applying deathlink from " .. message)
    local deathlinkType = apStorage.saveData.deathlinkType or apTypes.DeathlinkTypes.TEMPO

    if deathlinkType == apTypes.DeathlinkTypes.MARV and not gameDLC.isAmplifiedLoaded() then
        deathlinkType = apTypes.DeathlinkTypes.TEMPO
    end

    sound.playUI("necrodancerLaugh")

    for entity in ecs.entitiesWithComponents({ "playableCharacter" }) do
        if deathlinkType == apTypes.DeathlinkTypes.ABSOLUTE then
            damage.inflict({
                victim = entity,
                damage = 999,
                type = apFlags.DAMAGE_DEATH_LINK,
                killerName = message
            })
        elseif deathlinkType == apTypes.DeathlinkTypes.MARV then
            apFlyaways.addToFlyawayQueue({
                entity = entity,
                text = "Protect your flock or perish!"
            })
            local sounds
            if entity.name == "Mary" then
                sounds = { "maryGrief1", "maryGrief2", "maryGrief3", "maryGrief4" }
            else
                sounds = { string.lower(entity.name) .. "Hurt" }
            end

            local chain = apFollowerChain.appendChainFollower(entity, "Marv", 0, 0)
            chain.AP_followerDamageParentWhileDead.killerName = message
            chain.AP_followerDamageParentWhileDead.sounds = sounds
            chain.AP_marvDeathLinkTag.text = message
        else
            if entity.AP_damageCountdown.active or (entity.damageCountdown and entity.damageCountdown.countdown >= 0) then
                damage.inflict({
                    victim = entity,
                    damage = 999,
                    type = apFlags.DAMAGE_DEATH_LINK,
                    killerName = message
                })
            else
                apFlyaways.addToFlyawayQueue({
                    entity = entity,
                    text = "The clock's ticking down!"
                })

                entity.AP_damageCountdown.killerName = message
                entity.AP_damageCountdown.active = true
            end
        end
    end
end

apEventSync.subscribe("deathlink", function(data)
    applyDeathlink(data.message)
end)

-- Only the host is handed the packet, so it publishes rather than applying.
handlers.register("Death", function(message, ctx)
    if not apStorage.saveData.deathlink or currentLevel.isSafe() then return end

    local deathlinkMessage = message.source or message.msg or "DeathLink"
    apLog("Deathlink received from " .. deathlinkMessage)
    apEventSync.publish("deathlink", { message = deathlinkMessage })
end)

event.render.add("apRenderMarvDeathLinkTags", { order = "playerNames" }, function(ev)
    for entity in ecs.entitiesWithComponents({ "AP_marvDeathLinkTag" }) do
        if entity.AP_marvDeathLinkTag.text ~= "" and entity.visibility and entity.visibility.visible then
            local x, y = visualExtent.getPosition(entity, 0.5, 0)
            ui.drawText({
                alignX = 0.5,
                alignY = 1,
                font = ui.Font.SMALL,
                size = ui.Font.SMALL.size,
                x = x,
                y = y + 2,
                text = entity.AP_marvDeathLinkTag.text,
                fillColor = color.rgb(255, 100, 100),
                shadowColor = color.TRANSPARENT,
                outlineColor = color.BLACK,
                opacity = MARV_TAG_OPACITY,
                buffer = render.Buffer.FLYAWAY,
                anim = entity.shadowPosition and entity.shadowPosition.animID or nil,
            })
        end
    end
end)
