local animationTimer = require("necro.render.AnimationTimer")
local ecs            = require("system.game.Entities")
local render         = require("necro.render.Render")
local sound          = require("necro.audio.Sound")
local visualExtent   = require("necro.render.level.VisualExtent")

local apFlyaways  = require("AP.scripts.ui.apFlyaways")
local apUtils     = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local mary = {}

local SHIELD_BREAK_SOUND = "glassBreak"

local hitAbsorbed = {}

event.gameStateLevel.add("apMaryBuffReset", "resetLevelVariables", function()
    hitAbsorbed = {}
end)

local function isDeathLinkMarv(entity)
    local tag = entity.AP_marvDeathLinkTag

    return tag ~= nil and tag.text ~= nil and tag.text ~= ""
end

local function isArmored(entity)
    return entity.name == "Marv"
        and not isDeathLinkMarv(entity)
        and not hitAbsorbed[entity.id]
        and apUtils.isAPContext()
        and progression.getCharacterBuff("Mary")
end

event.objectTakeDamage.add("apMaryBuffAbsorbHit", {
    filter = "followerDamageParentWhileDead",
    order  = "immunity",
}, function(ev)
    if ev.damage <= 0 then return end
    if not isArmored(ev.entity) then return end

    hitAbsorbed[ev.entity.id] = true
    ev.suppressed = true
    ev.damage = 0
    sound.playFromEntity(SHIELD_BREAK_SOUND, ev.entity)
    apFlyaways.addToFlyawayQueue({ entity = ev.entity, text = "Blocked!" })
end)

local SHIELD = {
    frontTexture = "mods/AP/gfx/effects/small_shield_front.png",
    backTexture  = "mods/AP/gfx/effects/small_shield_back.png",
    width        = 26,
    height       = 26,
    offsetX      = 0,
    offsetY      = 4,
    frontZ       = 11,
    backZ        = -14,
    numFrames    = 3,
    period       = 0.4,
}

local shieldBuffer = render.getBuffer(render.Buffer.PARTICLE)
local shieldArgs   = { anim = 0, z = 0, rect = { 0, 0, 0, 0 }, texRect = { 0, 0, 0, 0 } }

event.render.add("apMaryBuffShield", { order = "particles", sequence = 1 }, function()
    local time    = animationTimer.getTime()
    local frameX  = math.floor(time / SHIELD.period % 1 * SHIELD.numFrames)

    for entity in ecs.entitiesWithComponents({ "AP_followerDamageParentWhileDead", "visibility" }) do
        if isArmored(entity) and entity.visibility.fullyVisible and entity.sprite.visible then
            local x, y, z = visualExtent.getOrigin(entity)
            local cropped = entity.croppedSprite and entity.croppedSprite.bottom or 0

            shieldArgs.rect[1] = x + SHIELD.offsetX - SHIELD.width * 0.5
            shieldArgs.rect[2] = y + z + SHIELD.offsetY - SHIELD.height
            shieldArgs.rect[3] = SHIELD.width
            shieldArgs.rect[4] = SHIELD.height - cropped

            shieldArgs.texRect[1] = SHIELD.width * frameX
            shieldArgs.texRect[2] = 0
            shieldArgs.texRect[3] = SHIELD.width
            shieldArgs.texRect[4] = shieldArgs.rect[4]

            shieldArgs.anim = entity.spriteExtrapolatable and entity.spriteExtrapolatable.animID or 0

            local zOrder = visualExtent.getZOrder(entity)

            shieldArgs.texture = SHIELD.frontTexture
            shieldArgs.z       = zOrder + SHIELD.frontZ
            shieldBuffer.draw(shieldArgs)

            shieldArgs.texture = SHIELD.backTexture
            shieldArgs.z       = zOrder + SHIELD.backZ
            shieldBuffer.draw(shieldArgs)
        end
    end
end)

function mary.apply(entity) end
function mary.revoke(entity) end
return mary
