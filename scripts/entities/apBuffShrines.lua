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

local apCharacters = require("AP.scripts.utils.apCharacters")
local apClient = require("AP.scripts.client.client")
local apInventory = require("AP.scripts.utils.apInventory")
local apPreview = require("AP.scripts.utils.apPreview")
local player = require("necro.game.character.Player")
local progression = require("AP.scripts.client.progression")

local function isCharacterLocked(apName)
    if not apClient.isSessionConnected() then return true end
    if not progression.getCharacters(apName) then return true end

    -- Slots that do not randomise buffs are granted all of them up front.
    return not progression.hasBuffItem(apName)
end

local function isCharacterDisabled(apName)
    local requirement = apCharacters.characterRequirements[apName]
    if progression.getCharacterBlacklist(apName) then return true end
    if requirement and requirement ~= "None" and not progression.isDLCEnabled(requirement) then return true end
    return false
end

local BUFF_DESCRIPTIONS = {
    Aria              = "Stackable extra lives",
    Bard              = "Familiar crypt",
    Bolt              = "First hit skips a beat",
    Coda              = "10 strikes and you're out",
    Cadence           = "Start with more gear",
    Diamond           = "Sharper diagonals",
    Dorian            = "Baby steps hurt less",
    Dove              = "Stronger flower and quick exit",
    Eli               = "Farther knockback and dazed foes",
    Mary              = "Armored Marv",
    Melody            = "A louder, throwable lute",
    Monk              = "Merciful vowbreaking",
    Nocturna          = "Heartier lifesteal",
    Reaper            = "Hardier souls",
    Tempo             = "More time to live",
    Klarinetta        = "Upgradeable Zweihander",
    Chaunter          = "Longer possessions",
    Suzu              = "Braver lance dashes",
    ["Hatsune Miku"]  = "Reduced combo to SING, on pointe",
    ["Shovel Knight"] = "More digging, richer loot",
}

event.objectPreview.add("APSuppressHoverForBuffShrine", {
    order = "hover",
    sequence = 1,
}, function(ev)
    if ev.AP_noHover and ev.hoverY and ev.hoverY ~= 0 and ev.visual then
        local dy = ev.hoverY
        ev.visual.rect[2] = ev.visual.rect[2] - dy
        ev.visual.z = (ev.visual.z or 0) - dy
        ev.hoverY = 0
    end
end)

event.particle.add("APBuffShrineOrbit", "APBuffShrineOrbit", function(ev)
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

commonShrine.registerShrine("APBuffCharacter", {
    name = "AP_BuffCharacterShrine",
    AP_buffCharacterShrine = {},
    AP_character = { name = "" },
    AP_preview = {},
    friendlyName = {
        name = "Character Buff Shrine"
    },
    sprite = {
        height = 52,
        texture = "mods/AP/gfx/shrines/shrine_character.png",
        width = 35
    },
    positionalSprite = {
        offsetX = -6,
        offsetY = -23
    },
    priceTag = {
        active = false
    },
    lobbyImmunity = {},
    shrinePoolExcludeFromShriner = {},
    AP_editorCategory = {},
})

event.render.add("buffCharacterShrinePreview", { order = "characterPreview", sequence = 2 }, function()
    for entity in ecs.entitiesWithComponents({ "AP_buffCharacterShrine", "AP_preview" }) do
        if not entity.visibility or entity.visibility.visible then
            local charName = entity.AP_character and entity.AP_character.name
            if charName and charName ~= "" then
                local cotndName = apCharacters.apLocationToCotNDChar(charName)
                local preview = ecs.getEntityPrototype(cotndName)
                if preview then
                    local isActive = entity.shrine and entity.shrine.active
                    local disabled = isCharacterDisabled(charName)
                    local locked = disabled or isCharacterLocked(charName)
                    local dimmed = not isActive or locked

                    apPreview.draw(preview, {
                        entity = entity,
                        offsetY = -11,
                        offsetZ = 100,
                        silhouette = locked,
                        grayscale = not locked and not isActive,
                        underlay = locked and "AP_BuffCharacterShrine" or nil,
                        indicatorColor = apPreview.indicatorColor(disabled, false),
                        animationSpeed = dimmed and 0 or nil,
                        previewArgs = {
                            AP_noHover = dimmed,
                            shadow = false,
                        },
                    })
                end
            end
        end
    end
end)

local function spawnBuffOrbitParticles(entity)
    particle.playFromTable({
        bounciness = 0.5,
        color = color.rgb(0, 227, 197),
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
        type = "APBuffShrineOrbit",
        velocity = 0,
        velocityZ = 80,
        x = entity.position.x,
        y = entity.position.y,
    })
end

-- The shrine's frame, light and particles follow progression rather than the interact handler.
local function refreshBuffShrine(entity)
    local character = entity.AP_character and entity.AP_character.name
    if not character or character == "" then return end

    local active = progression.getCharacterBuff(character) and true or false
    if entity.shrine.active == active then return end

    entity.shrine.active = active
    entity.spriteSheet.frameX = active and 2 or 1
    lightSource.update(entity)

    if active then
        spawnBuffOrbitParticles(entity)
    end
end

event.updateVisuals.add("apRefreshBuffShrines", { order = "configInteractable" }, function()
    for entity in ecs.entitiesWithComponents({ "AP_buffCharacterShrine", "shrine", "spriteSheet" }) do
        refreshBuffShrine(entity)
    end
end)

event.objectInteract.add("toggleBuffCharacterShrine", {
    filter = "AP_buffCharacterShrine",
    order = "priceTag",
    sequence = -1
}, function(ev)
    local character = ev.entity.AP_character and ev.entity.AP_character.name
    if not character or character == "" then
        ev.result = action.Result.FAILURE
        ev.suppressed = true
        return
    end

    if isCharacterDisabled(character) then
        flyaway.create({ entity = ev.entity, text = "Disabled!" })
        sound.playFromEntity("error", ev.entity, { deduplicationID = ev.interactor and ev.interactor.id })
        ev.suppressed = true
        return
    end

    if not apClient.isSessionConnected() or not progression.getCharacters(character) then
        flyaway.create({ entity = ev.entity, text = "Find " .. character .. " to unlock!" })
        sound.playFromEntity("error", ev.entity, { deduplicationID = ev.interactor and ev.interactor.id })
        ev.suppressed = true
        return
    end

    if not progression.hasBuffItem(character) then
        flyaway.create({ entity = ev.entity, text = "Find " .. character .. "'s buff to unlock!" })
        sound.playFromEntity("error", ev.entity, { deduplicationID = ev.interactor and ev.interactor.id })
        ev.suppressed = true
        return
    end

    local isActive = not progression.getCharacterBuff(character)
    ev.entity.shrine.active = isActive
    ev.entity.spriteSheet.frameX = isActive and 2 or 1
    lightSource.update(ev.entity)
    screenShake.createOnEntity(ev.entity, isActive and 0.5 or 0.25, 15)
    sound.playFromEntity(
        isActive and "shrineActivate" or "bossShake",
        ev.entity,
        { deduplicationID = ev.interactor and ev.interactor.id }
    )
    if isActive then
        spawnBuffOrbitParticles(ev.entity)
    end

    progression.setCharacterBuff(character, isActive)

    for _, playerEntity in ipairs(player.getPlayerEntities()) do
        local apName = apCharacters.cotNDCharToAPLocation(playerEntity.name)
        if apName == character then
            apInventory.applyStarterInventory(playerEntity, progression, { sanitize = true })
            break
        end
    end

    flyaway.create({
        entity = ev.entity,
        text = isActive
            and (BUFF_DESCRIPTIONS[character] or (character .. " buffed!"))
            or (character .. " buff disabled")
    })

    ev.result = action.Result.INTERACT
    ev.suppressed = true
end)
