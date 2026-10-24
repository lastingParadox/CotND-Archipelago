local customEntities = require "necro.game.data.CustomEntities"

local apVocalLayers = require "AP.scripts.audio.apVocalLayers"

customEntities.extend({
    name       = "ShopkeeperMonstrous",
    template   = customEntities.template.enemy("shopkeeper", 5),
    components = {
        AP_editorCategory        = {},
        musicLayerAddVolume      = { layerTag = apVocalLayers.MONSTROUS.layer },
        castOnHitDeferred        = false,
        castOnSpawn              = false,
        innateAttackInhibitOnHit = false,
        musicLayerVocalOverride  = false,
        provokeOnTrespass        = false,
    },
})
