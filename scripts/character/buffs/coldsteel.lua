local animationTimer = require "necro.render.AnimationTimer"
local apUtils        = require "AP.scripts.utils.apUtils"
local color_mod      = require "system.utils.Color"
local ecs            = require "system.game.Entities"
local flyaway        = require "necro.game.system.Flyaway"
local inventory      = require "necro.game.item.Inventory"
local progression    = require "AP.scripts.client.progression"
local render_mod     = require "necro.render.Render"
local utils_mod      = require "system.utils.Utilities"
local visualExtent   = require "necro.render.level.VisualExtent"

local coldsteel = {}

local BUFF_COMBO = 3

local function isMikuBuff()
    return apUtils.isAPContext() and progression.getCharacterBuff("Hatsune Miku")
end

-- Replicated from ColdsteelComboBar.lua with limit hard-set to BUFF_COMBO.
local buffedVisual = { texture = "", texRect = {0, 0, 0, 0}, rect = {0, 0, 0, 0}, anim = 0, z = 0, color = 0 }

local function drawBuffedBar(item, entity, flash)
    if (entity.sprite and not entity.sprite.visible) or (entity.visibility and not entity.visibility.visible) then
        return
    end
    local buf   = render_mod.getBuffer(render_mod.Buffer.HEALTH_BAR)
    local bar   = item.Coldsteel_weaponComboBar
    local limit = BUFF_COMBO
    local combo = item.Coldsteel_weaponComboTracker and item.Coldsteel_weaponComboTracker.combo
                  or item.itemComboable.combo
    local baseY = math.min(math.floor(combo / limit), bar.stages - 1)
    buffedVisual.texture  = bar.texture
    local x, y = visualExtent.getPosition(entity, 0.5, 0, 1)
    buffedVisual.rect[3]  = bar.width
    buffedVisual.rect[4]  = bar.height
    x = x - bar.width * (limit * 0.5)
    y = y - bar.height + 6
    buffedVisual.texRect[1] = 0
    buffedVisual.texRect[4] = bar.height
    buffedVisual.anim = entity.spriteExtrapolatable and entity.spriteExtrapolatable.animID or 0
    buffedVisual.color = color_mod.fade(
        item.itemComboable.combo ~= 0 and color_mod.WHITE
        or color_mod.opacity(1 - animationTimer.getFactorClamped(item.id, "Coldsteel_weaponComboTracker", 0.5)),
        flash or 1
    )
    if flash then
        buffedVisual.texRect[2] = (bar.flashY - 1) * bar.height
    end
    for i = 0, limit - 1 do
        buffedVisual.rect[1] = x + bar.width * i
        buffedVisual.rect[2] = y - bar.height
        if i == 0 then
            buffedVisual.rect[1]    = buffedVisual.rect[1] - 1
            buffedVisual.rect[3]    = bar.width + 1
            buffedVisual.texRect[3] = bar.width + 1
        else
            buffedVisual.rect[3]    = bar.width
            buffedVisual.texRect[1] = bar.width * (i < limit - 1 and 1 or 2) + 1
            buffedVisual.texRect[3] = bar.width
        end
        if flash then
            buffedVisual.z = y + 1
        else
            buffedVisual.texRect[2] = bar.height * (baseY + utils_mod.step(i + 1, combo % limit))
            buffedVisual.z = y
        end
        buf.draw(buffedVisual)
    end
    if not flash then
        local consume = animationTimer.getFactorClamped(item.id, "Coldsteel_weaponComboTrackerConsume", 0.5)
        if consume < 1 then
            drawBuffedBar(item, entity, 1 - consume)
        end
    end
end

-- Suppress vanilla grant (seq 2) by clearing pendingIncrease at seq 1, then replicate with BUFF_COMBO at seq 3.
local savedPendingByWeapon = {}

event.gameStateLevel.add("apMikuBuffClearPending", "resetLevelVariables", function()
    savedPendingByWeapon = {}
end)

event.holderPerformAttack.add("apMikuBuffSuppressComboGrant", {
    order = "inflictDamage", sequence = 1, filter = "Coldsteel_weaponComboable",
}, function(ev)
    if not isMikuBuff() or ev.holder.name ~= "Coldsteel_Coldsteel" then return end
    savedPendingByWeapon[ev.entity.id] = ev.entity.Coldsteel_weaponComboable.pendingIncrease
    ev.entity.Coldsteel_weaponComboable.pendingIncrease = false
end)

event.holderPerformAttack.add("apMikuBuffComboGrant", {
    order = "inflictDamage", sequence = 3, filter = "Coldsteel_weaponComboable",
}, function(ev)
    if not isMikuBuff() or ev.holder.name ~= "Coldsteel_Coldsteel" then return end
    local wasPending = savedPendingByWeapon[ev.entity.id]
    savedPendingByWeapon[ev.entity.id] = nil
    if not wasPending then return end
    ev.entity.itemComboable.combo = ev.entity.itemComboable.combo + 1
    local combo = ev.entity.itemComboable.combo
    if ev.holder.hitChain and ev.entity.Coldsteel_weaponComboableOverrideHitChain then
        local step = (combo - 1) % BUFF_COMBO
        ev.holder.hitChain.consecutiveHits = step == BUFF_COMBO - 1 and BUFF_COMBO or step
    end
    local grantData = ev.entity.Coldsteel_weaponComboableGrantItem
    if grantData and combo % BUFF_COMBO == 0 then
        inventory.grant(grantData.item, ev.holder)
        flyaway.createIfFocused { entity = ev.holder, text = grantData.flyaway }
        if ev.entity.Coldsteel_weaponComboTracker then
            ev.entity.Coldsteel_weaponComboTracker.consumedChain = ev.entity.Coldsteel_weaponComboTracker.chain
            ev.entity.Coldsteel_weaponComboTracker.chain = {{ 0, ev.holder.position.x, ev.holder.position.y }}
            animationTimer.play(ev.entity.id, "Coldsteel_weaponComboTrackerConsume")
        end
    end
end)

-- Pre/post handlers around vanilla renderComboBar (sequence 0).
-- Pre sets equipped=false so vanilla skips Miku's leek; post restores and draws buffed 3-blip version.
local cachedLeek   = nil
local cachedHolder = nil

event.render.add("apMikuBuffComboBarPre", { order = "healthBars", sequence = -1 }, function()
    cachedLeek, cachedHolder = nil, nil
    if not isMikuBuff() then return end
    for item in ecs.entitiesWithComponents { "Coldsteel_weaponComboBar", "item" } do
        local holder = ecs.getEntityByID(item.item.holder)
        if holder and holder.name == "Coldsteel_Coldsteel" and item.item.equipped then
            cachedLeek   = item
            cachedHolder = holder
            item.item.equipped = false
            break
        end
    end
end)

event.render.add("apMikuBuffComboBarPost", { order = "healthBars", sequence = 1 }, function()
    if not cachedLeek then return end
    cachedLeek.item.equipped = true
    drawBuffedBar(cachedLeek, cachedHolder)
    cachedLeek, cachedHolder = nil, nil
end)

function coldsteel.apply() end
function coldsteel.revoke() end
return coldsteel
