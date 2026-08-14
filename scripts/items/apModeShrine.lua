local extraMode = require "necro.game.data.modifier.ExtraMode"
local gameState = require("necro.client.GameState")
local gfx = require "system.gfx.GFX"
local itemPickup = require "necro.game.item.ItemPickup"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local apItemShowcase = require("AP.scripts.entities.apItemShowcase")
local apLobby = require("AP.scripts.level.apLobby")
local progression = require("AP.scripts.client.progression")

-- Half the sheet: mode shrine textures are 2 columns by 2 rows.
local function shrineSpriteSize(shrine)
    local width, height = gfx.getImageSize(shrine.texture)
    return math.floor(width / 2), math.floor(height / 2)
end

local hardShrine = extraMode.Type.data[extraMode.Type.HARD].shrine
local hardWidth, hardHeight = shrineSpriteSize(hardShrine)

apItemFactory.define({
    name = "AP_ModeShrine",
    rawTexture = hardShrine.texture,
    width = hardWidth,
    height = hardHeight,
    hint = L("Mode", "AP.mode.shrine.hint"),
    data = { flyaway = "Mode Unlocked" },
    components = {
        positionalSprite = {
            offsetX = hardShrine.offsetX,
            offsetY = hardShrine.offsetY,
        },
        spriteSheet = { frameX = 2, frameY = 1 },
    },
})

local BASE_OFFSET_X, BASE_OFFSET_Y, BASE_Z = -6, -19, 20

for _, name in ipairs(apItemShowcase.apShowcaseList.__keyOrder) do
    local entry = apItemShowcase.apShowcaseList[name]
    local modeData = entry.modeType and extraMode.Type.data[entry.modeType]
    local shrine = modeData and modeData.shrine

    if shrine then
        local width, height = shrineSpriteSize(shrine)

        apItemFactory.defineDisplay({
            name = entry.preview,
            rawTexture = shrine.texture,
            width = width,
            height = height,
            components = {
                positionalSprite = {
                    offsetX = shrine.offsetX or BASE_OFFSET_X,
                    offsetY = shrine.offsetY or BASE_OFFSET_Y,
                },
                rowOrder = { z = shrine.offsetZ or BASE_Z },
            },
        })
    end
end

event.objectTryCollectItem.add("pickupAPModeShrine", { order = "priceTag", sequence = 1 }, function(ev)
    if not (gameState.isInLobby() and apLobby.isInLobby(ev.entity)) then
        return
    end

    if (ev.item.name == "AP_ModeShrine") then
        if ev.result ~= itemPickup.Result.SUCCESS then return end
        progression.enableExtraMode(string.gsub(ev.item.AP_itemHintLabel.text, " Mode", ""))
    end
end)
