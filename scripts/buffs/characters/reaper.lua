local apFlyaways  = require("AP.scripts.ui.apFlyaways")
local apUtils     = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local hasSkins, SkinSprite = pcall(require, "CharacterSkins.SkinSprite")
local _, SkinTemplate      = pcall(require, "CharacterSkins.SkinTemplate")
local gfx          = require("system.gfx.GFX")

local RESILIENT_SPRITE      = "mods/AP/gfx/soul_follower.png"
local RESILIENT_SPRITE_RIFT = "mods/AP/gfx/soul_follower_rift.png"

local reaper = {}

local hitAbsorbed    = {}
local savedTextures  = {}
local savedBoundsW   = {}
local savedBoundsH   = {}

event.gameStateLevel.add("apReaperBuffReset", "resetLevelVariables", function()
    hitAbsorbed   = {}
    savedTextures = {}
    savedBoundsW  = {}
    savedBoundsH  = {}
end)

local function getResilientTexture(entity)
    if hasSkins then
        local ok, sprite = pcall(SkinSprite.getSpriteForEntity, entity, SkinTemplate.SpriteType.FOLLOWER)
        if ok and sprite then
            return RESILIENT_SPRITE_RIFT
        end
    end
    return RESILIENT_SPRITE
end

-- Recomputes CharacterSkins_textureBounds with the same formula CharacterSkins uses.
local function applyTextureBounds(entity, texture)
    if not entity.CharacterSkins_textureBounds then return end
    local sw = gfx.getImageWidth(texture)
    local sh = gfx.getImageHeight(texture)
    local fw = entity.sprite.width
    local fh = entity.sprite.height
    if not (fw and fw > 0 and fh and fh > 0) then return end
    entity.CharacterSkins_textureBounds.width  = math.max(1, math.floor(sw / fw)) * fw
    entity.CharacterSkins_textureBounds.height = math.max(1, math.floor(sh / fh)) * fh
end

event.objectSpawn.add("apReaperBuffSoulSprite", {
    filter   = "soulFollower",
    order    = "sprite",
    sequence = 1,
}, function(ev)
    if ev.entity.name ~= "ReaperSoul" then return end
    if not ev.entity.sprite then return end
    if not apUtils.isAPContext() then return end
    if not progression.getCharacterBuff("Reaper") then return end
    local id = ev.entity.id
    local tex = getResilientTexture(ev.entity)
    savedTextures[id] = ev.entity.sprite.texture
    if ev.entity.CharacterSkins_textureBounds then
        savedBoundsW[id] = ev.entity.CharacterSkins_textureBounds.width
        savedBoundsH[id] = ev.entity.CharacterSkins_textureBounds.height
    end
    ev.entity.sprite.texture = tex
    applyTextureBounds(ev.entity, tex)
end)

event.objectTakeDamage.add("apReaperBuffSoulAbsorbHit", {
    filter = "soulFollower",
    order  = "immunity",
}, function(ev)
    if ev.entity.name ~= "ReaperSoul" then return end
    if ev.damage <= 0 then return end
    if not apUtils.isAPContext() then return end
    if not progression.getCharacterBuff("Reaper") then return end
    if hitAbsorbed[ev.entity.id] then return end
    hitAbsorbed[ev.entity.id] = true
    ev.suppressed = true
    ev.damage = 0
    local id = ev.entity.id
    if ev.entity.sprite and savedTextures[id] then
        ev.entity.sprite.texture = savedTextures[id]
        if ev.entity.CharacterSkins_textureBounds and savedBoundsW[id] then
            ev.entity.CharacterSkins_textureBounds.width  = savedBoundsW[id]
            ev.entity.CharacterSkins_textureBounds.height = savedBoundsH[id]
        end
    end
    apFlyaways.addToFlyawayQueue({ entity = ev.entity, text = "Resilient!" })
end)

function reaper.apply(entity) end
function reaper.revoke(entity) end
return reaper
