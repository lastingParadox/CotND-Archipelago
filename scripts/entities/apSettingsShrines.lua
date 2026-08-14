local action = require "necro.game.system.Action"
local color = require "system.utils.Color"
local commonShrine = require "necro.game.data.object.CommonShrine"
local ecs = require "system.game.Entities"
local flyaway = require "necro.game.system.Flyaway"
local lightSource = require "necro.game.vision.LightSource"
local particle = require "necro.game.system.Particle"
local particleRenderer = require "necro.render.level.ParticleRenderer"
local render = require "necro.render.Render"
local screenShake = require "necro.render.ScreenShake"
local sound = require "necro.audio.Sound"

local apClient = require("AP.scripts.client.client")
local apStorage = require("AP.scripts.client.storage")

event.particle.add("APShrineOrbit", "APShrineOrbit", function(ev)
    particleRenderer.initStatefulParticles(ev, particleRenderer.Direction.NONE, 0)

    local entity = ecs.getEntityByID(ev.entityID)
    local isActive = entity and entity.shrine and entity.shrine.active

    if not isActive then
        if not ev.stop then
            ev.stop = ev.time or 0
            ev.baseFadeDelay = ev.fadeDelay
            particleRenderer.ceaseSpawning(ev)
        else
            ev.fadeDelay = ev.baseFadeDelay + math.min(1, ev.time - ev.stop)
        end

        local x, y = render.tileCenter(ev.x, ev.y)
        particleRenderer.attract(ev, x, y, 0, -1, 0)
        ev.gravity = 800
    end
end)

commonShrine.registerShrine("APDeathLink", {
    name = "AP_ShrineDeathLink",
    AP_deathlinkShrine = {},
    friendlyName = {
        name = "DeathLink Shrine"
    },
    shrineHintLabel = {
        text = "Toggle DeathLink"
    },
    sprite = {
        height = 46,
        texture = "mods/AP/gfx/shrines/shrine_deathlink.png",
        width = 30
    },
    positionalSprite = {
        offsetX = -6,
        offsetY = -13
    },
    priceTag = {
        active = false
    },
    lobbyImmunity = {},
    shrinePoolExcludeFromShriner = {},
    AP_editorCategory = {},
})

commonShrine.registerShrine("APTrapLink", {
    name = "AP_ShrineTrapLink",
    AP_traplinkShrine = {},
    friendlyName = {
        name = "TrapLink Shrine"
    },
    shrineHintLabel = {
        text = "Toggle TrapLink"
    },
    sprite = {
        height = 52,
        texture = "mods/AP/gfx/shrines/shrine_traplink.png",
        width = 35
    },
    positionalSprite = {
        offsetX = -6,
        offsetY = -21
    },
    priceTag = {
        active = false
    },
    lobbyImmunity = {},
    shrinePoolExcludeFromShriner = {},
    AP_editorCategory = {},
})

local function spawnOrbitParticles(entity, particleColor)
    particle.playFromTable({
        bounciness = 0.5,
        color = particleColor,
        duration = 10,
        explosiveness = 0,
        entityID = entity.id,
        fadeDelay = 0.5,
        fadeRandom = 0.25,
        fadeTime = 0.5,
        gravity = 0,
        maxDelay = 2,
        minDelay = 0,
        offsetX = 0,
        offsetY = 0,
        offsetZ = 10,
        particleCount = 50,
        spread = 12,
        texture = "gfx/necro/particles/particle_reconfigure.png",
        type = "APShrineOrbit",
        velocity = 0,
        velocityZ = 80,
        x = entity.position.x,
        y = entity.position.y,
    })
end

event.objectInteract.add("toggleDeathlinkShrine", {
    filter = "AP_deathlinkShrine",
    order = "priceTag",
    sequence = -1
}, function(ev)
    if not apClient.isSessionConnected() then
        sound.playFromEntity("error", ev.entity, { deduplicationID = ev.interactor and ev.interactor.id })
        flyaway.create({ entity = ev.entity, text = "Not Connected!" })
        ev.result = action.Result.FAILURE
        ev.suppressed = true
        return
    end

    ev.entity.shrine.active = not ev.entity.shrine.active
    ev.entity.spriteSheet.frameX = ev.entity.shrine.active and 2 or 1
    lightSource.update(ev.entity)
    screenShake.createOnEntity(ev.entity, ev.entity.shrine.active and 0.5 or 0.25, 15)
    sound.playFromEntity(ev.entity.shrine.active and "shrineActivate" or "bossShake", ev.entity, { deduplicationID = ev.interactor and ev.interactor.id })
    if ev.entity.shrine.active then
        spawnOrbitParticles(ev.entity, color.rgb(198, 25, 164))
    end
    apClient.sendPacket({ datatype = "SetDeathLink", deathlink = ev.entity.shrine.active })

    ev.result = action.Result.INTERACT
    ev.suppressed = true
end)

event.objectInteract.add("toggleTraplinkShrine", {
    filter = "AP_traplinkShrine",
    order = "priceTag",
    sequence = -1
}, function(ev)
    if not apClient.isSessionConnected() then
        sound.playFromEntity("error", ev.entity, { deduplicationID = ev.interactor and ev.interactor.id })
        flyaway.create({ entity = ev.entity, text = "Not Connected!" })
        ev.result = action.Result.FAILURE
        ev.suppressed = true
        return
    end

    ev.entity.shrine.active = not ev.entity.shrine.active
    ev.entity.spriteSheet.frameX = ev.entity.shrine.active and 2 or 1
    lightSource.update(ev.entity)
    screenShake.createOnEntity(ev.entity, ev.entity.shrine.active and 0.5 or 0.25, 15)
    sound.playFromEntity(ev.entity.shrine.active and "shrineActivate" or "bossShake", ev.entity, { deduplicationID = ev.interactor and ev.interactor.id })
    if ev.entity.shrine.active then
        spawnOrbitParticles(ev.entity, color.rgb(204, 144, 40))
    end
    apClient.sendPacket({ datatype = "SetTrapLink", traplink = ev.entity.shrine.active })

    ev.result = action.Result.INTERACT
    ev.suppressed = true
end)

event.apConnect.add("syncSettingsShrines", { order = "connected", sequence = 2 }, function(ev)
    if ev.status ~= "Connected" then return end

    local deathlink = apStorage.saveData and apStorage.saveData.deathlink == true
    for entity in ecs.entitiesWithComponents({ "AP_deathlinkShrine" }) do
        entity.shrine.active = deathlink
        entity.spriteSheet.frameX = deathlink and 2 or 1
        lightSource.update(entity)
        if deathlink then
            spawnOrbitParticles(entity, color.rgb(220, 50, 50))
        end
    end

    local traplink = apStorage.saveData and apStorage.saveData.traplink == true
    for entity in ecs.entitiesWithComponents({ "AP_traplinkShrine" }) do
        entity.shrine.active = traplink
        entity.spriteSheet.frameX = traplink and 2 or 1
        lightSource.update(entity)
        if traplink then
            spawnOrbitParticles(entity, color.rgb(255, 165, 0))
        end
    end
end)
