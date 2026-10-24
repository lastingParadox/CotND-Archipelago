local character      = require "necro.game.character.Character"
local customEntities = require "necro.game.data.CustomEntities"
local ecs            = require "system.game.Entities"
local soundtrack     = require "necro.game.data.Soundtrack"

local apVocalLayers = require "AP.scripts.audio.apVocalLayers"

local DAOUST_SPRITE = {
    texture = "ext/entities/shopkeeper6.png",
    width   = 25,
    height  = 26,
    offsetX = 11,
    offsetY = 12,
}

customEntities.extend({
    name       = "ShopkeeperAlt",
    template   = customEntities.template.enemy("shopkeeper"),
    components = {
        AP_altVocalist         = {},
        AP_editorCategory      = {},
        musicLayerAddVolume    = { layerTag = apVocalLayers.DAOUST.layer },
        upgradeByVocalSettings = false,
    },
    -- Bakes what setDynamicSprite would apply, so the editor draws the prototype in place.
    modifier = function(definition)
        local positional = definition.positionalSprite

        definition.sprite.texture = DAOUST_SPRITE.texture
        definition.sprite.width   = DAOUST_SPRITE.width
        definition.sprite.height  = DAOUST_SPRITE.height
        definition.rowOrder.z     = definition.rowOrder.z - DAOUST_SPRITE.offsetY
        positional.offsetX        = positional.offsetX + DAOUST_SPRITE.offsetX
        positional.offsetY        = positional.offsetY + DAOUST_SPRITE.offsetY
    end,
})

-- Cancels the prototype's baked-in Daoust offsets to land back on the vanilla shopkeeper.
local function standardSprite()
    local vanilla = ecs.getEntityPrototype("Shopkeeper").sprite

    return {
        texture = vanilla.texture,
        width   = vanilla.width,
        height  = vanilla.height,
        offsetX = -DAOUST_SPRITE.offsetX,
        offsetY = -DAOUST_SPRITE.offsetY,
    }
end

local function applyAltSprite(entity)
    local daoust = apVocalLayers.getActive(apVocalLayers.DAOUST) == soundtrack.Vocals.NICOLAS_DAOUST

    character.setDynamicSprite(entity, not daoust and standardSprite() or nil)
end

event.objectSpawn.add("apShopkeeperAltSprite", { filter = "AP_altVocalist", order = "upgrade" }, function(ev)
    applyAltSprite(ev.entity)
end)

event.snapshotResync.add("apShopkeeperAltSprite", "spriteOverrides", function(ev)
    for entity in ecs.entitiesWithComponents({ "AP_altVocalist" }) do
        applyAltSprite(entity)
    end
end)
