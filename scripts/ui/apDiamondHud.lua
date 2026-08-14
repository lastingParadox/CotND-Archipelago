local animationTimer = require "necro.render.AnimationTimer"
local camera = require "necro.render.Camera"
local currency = require "necro.game.item.Currency"
local focus = require "necro.game.character.Focus"
local gameState = require "necro.client.GameState"
local gfx = require "system.gfx.GFX"
local hud = require "necro.render.hud.HUD"
local inventory = require "necro.game.item.Inventory"
local rectangle = require "system.utils.Rectangle"
local render = require "necro.render.Render"
local snapshot = require "necro.game.system.Snapshot"
local ui = require "necro.render.UI"
local utils = require "system.utils.Utilities"

local apFlags = require("AP.scripts.utils.flags")
local apProgression = require("AP.scripts.client.progression")
local apUtils = require("AP.scripts.utils.apUtils")

apDiamondAnimations = snapshot.levelVariable({})

event.gameStateReset.add("initAPDiamondPool", { order = "progressionState", sequence = 1 }, function()
    if apUtils.isAPContext() then
        currency.setShared(apFlags.CURRENCY_AP_DIAMOND, apProgression.getDiamonds() or 0)
    end
end)

event.pickupEffects.add("APDiamondAnimation", {
    filter = { "diamondPickupAnimation", "sprite", "itemCurrency" },
    order = "animation",
}, function(ev)
    if ev.item.itemCurrency.currencyType ~= apFlags.CURRENCY_AP_DIAMOND then return end
    animationTimer.play(ev.item.id, "diamondPickup")
    apDiamondAnimations[#apDiamondAnimations + 1] = {
        id = ev.item.id,
        holder = ev.holder.id,
        factor = ev.item.diamondPickupAnimation.factor,
        duration = ev.item.diamondPickupAnimation.duration,
        rect = { ev.item.sprite.x, ev.item.sprite.y, 25, 24 },
    }
end)

local iconDiamond = "ext/gui/diamond.png"

local function drawAPDiamondPickupAnimations(entity)
    if not apDiamondAnimations[1] then return end
    utils.removeIf(apDiamondAnimations, function(data)
        if entity == nil or data.holder == entity.id then
            local time = animationTimer.getTime(data.id, "diamondPickup")
            local rect = hud.getSlotRect({
                element = "currency",
                slot = { 1, 2 },
            })
            rectangle.lerp(rect, camera.transformRect(data.rect), data.factor ^ (time * 60))
            render.getBuffer(render.Buffer.UI_HUD).draw({
                texture = iconDiamond,
                rect = rect,
            })
            return data.duration < time
        end
    end)
end

local function drawAPDiamondCounter(amount)
    local width = gfx.getImageWidth(iconDiamond)
    hud.drawSprite({
        element = "currency",
        image = iconDiamond,
        slot = { 1, 2 },
        rect = { 0, 0, width == 24 and 0.96 or 1, 1 },
    })
    hud.drawText({
        element = "currency",
        font = ui.Font.SMALL,
        offsetY = 8,
        scale = 1.5,
        slot = { 2, 2 },
        text = inventory.formatQuantity(amount),
        rect = { 0, 0, 1.2, 1 },
    })
end

event.renderPlayerHUD.override("diamondCounter", function(func, entity)
    -- Suppress vanilla counter in AP context or any AP lobby sub-room
    if apUtils.isAPContext(entity) then return end
    return func(entity)
end)

event.renderGlobalHUD.override("diamondCounter", function(func, ev)
    local hudEntity = focus.getFirst(focus.Flag.HUD)
    if not hudEntity then return func(ev) end
    if not apUtils.isAPContext(hudEntity) then return func(ev) end
    -- Always read from saveData (authoritative), so sub-room transitions never cause a stale value
    drawAPDiamondCounter(apProgression.getDiamonds() or 0)
    drawAPDiamondPickupAnimations()
end)
