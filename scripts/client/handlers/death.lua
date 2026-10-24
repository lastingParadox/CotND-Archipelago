local color = require "system.utils.Color"
local currentLevel = require "necro.game.level.CurrentLevel"
local damage = require "necro.game.system.Damage"
local ecs = require "system.game.Entities"
local gameDLC = require "necro.game.data.resource.GameDLC"
local player = require "necro.game.character.Player"
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

local DEATHLINK_COUNTDOWN = 32

-- Starts a full countdown on the body, or ends it outright if one is already running.
local function startCountdown(entity, message)
    local countdown = entity.AP_damageCountdown
    if not countdown then return end

    if countdown.active then
        local possessor = entity.Sync_possessable and ecs.getEntityByID(entity.Sync_possessable.possessor)

        for _, victim in ipairs({ entity, possessor or nil }) do
            damage.inflict({
                victim = victim,
                damage = 999,
                type = apFlags.DAMAGE_DEATH_LINK,
                killerName = message
            })
        end
        return
    end

    apFlyaways.addToFlyawayQueue({
        entity = entity,
        text = "The clock's ticking down!"
    })

    countdown.countdown = DEATHLINK_COUNTDOWN
    countdown.countdownReset = 0
    countdown.damage = 999
    countdown.type = apFlags.DAMAGE_DEATH_LINK
    countdown.killerName = message
    countdown.active = true
end

local function applyDeathlink(message)
    apLog("Applying deathlink from " .. message)
    local deathlinkType = apStorage.saveData.deathlinkType or apTypes.DeathlinkTypes.TEMPO

    if deathlinkType == apTypes.DeathlinkTypes.MARV and not gameDLC.isAmplifiedLoaded() then
        deathlinkType = apTypes.DeathlinkTypes.TEMPO
    end

    sound.playUI("necrodancerLaugh")

    if deathlinkType == apTypes.DeathlinkTypes.TEMPO then
        -- The body each player is driving, so a possessed one shows and carries the countdown.
        for _, entity in ipairs(player.getPlayerEntities()) do
            startCountdown(entity, message)
        end
        return
    end

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
