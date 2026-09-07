local extraMode = require "necro.game.data.modifier.ExtraMode"
local gameState = require("necro.client.GameState")
local gfx = require "system.gfx.GFX"
local itemPickup = require "necro.game.item.ItemPickup"

local apGrants = require("AP.scripts.items.apGrants")
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

        local mode = string.match(ev.item.AP_hintLabel.text or "", "^(.*) Mode$")
        if mode then
            progression.enableExtraMode(mode)
        end
    end
end)

-- AP_ModeShrine stands in for all eight modes, so which one it is lives in its label.
local GRANTED_MODES = {
    APNoReturnMode    = "No Return",
    APHardMode        = "Hard",
    APPhasingMode     = "Phasing",
    APRandomizerMode  = "Randomizer",
    APMysteryMode     = "Mystery",
    APNoBeatMode      = "No Beat",
    APDoubleTempoMode = "Double Tempo",
    APLowPercentMode  = "Low Percent",
}

for itemId, mode in pairs(GRANTED_MODES) do
    apGrants.define({
        item = itemId,
        sound = "shrineActivate",
        apply = function() progression.enableExtraMode(mode) end,
    })
end
