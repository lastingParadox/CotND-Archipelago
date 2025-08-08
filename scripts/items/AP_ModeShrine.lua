local customEntities = require("necro.game.data.CustomEntities")
local extraMode = require "necro.game.data.modifier.ExtraMode"
local gameState = require("necro.client.GameState")
local gfx = require "system.gfx.GFX"

local apConnection = require("AP.scripts.ap_handlers.APConnection")
local apUtils = require("AP.scripts.ap_handlers.APUtils")

local modeShrine = extraMode.Type.data[extraMode.Type.HARD].shrine
local textureWidth, textureHeight = gfx.getImageSize(modeShrine.texture)

customEntities.extend({
    name = "AP_ModeShrine",
    template = customEntities.template.item(),
    data = {
        flyaway = "Mode Unlocked",
        slot = "misc",
    },
    components = {
        sprite = {
            texture = modeShrine.texture,
            width = math.floor(textureWidth / 2),
            height = math.floor(textureHeight / 2)
        },
        positionalSprite = {
            offsetX = modeShrine.offsetX,
            offsetY = modeShrine.offsetY
        },
        AP_itemHintLabel = {
            text = L("Mode", "AP.mode.shrine.hint"),
        },
        itemDestructible = {},
    },
})

event.objectTryCollectItem.add("pickupAPModeShrine", { order = "checkItem" }, function(ev)
    if not (gameState.isInLobby() and apUtils.isInLobby(ev.entity)) then
        return
    end

    if (ev.item.name == "AP_ModeShrine") then
        apConnection.enableExtraMode(string.gsub(ev.item.text, " Mode", ""))
    end
end)
