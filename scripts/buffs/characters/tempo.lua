local currentLevel = require "necro.game.level.CurrentLevel"
local ecs         = require "system.game.Entities"
local hud         = require "necro.render.hud.HUD"
local kill        = require "necro.game.character.Kill"
local ui          = require "necro.render.UI"

local apUtils     = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local tempo = {}

local BUFF_COUNTDOWN = 24

local function isTempoWithBuff(entity)
    return entity ~= nil
        and entity.name == "Tempo"
        and apUtils.isAPContext()
        and progression.getCharacterBuff("Tempo")
end

event.gameStateLevel.add("apTempoBuffCountdown", { order = "damageCountdown", sequence = 1 }, function()
    if not apUtils.isAPContext() then return end
    if not progression.getCharacterBuff("Tempo") then return end
    for entity in ecs.entitiesWithComponents({ "damageCountdown" }) do
        if entity.name == "Tempo" then
            entity.damageCountdown.countdown = BUFF_COUNTDOWN
        end
    end
end)

event.objectDealDamage.add("apTempoBuffCountdownOnAttack", {
    filter   = "damageCountdown",
    order    = "damageCountdown",
    sequence = 1,
}, function(ev)
    if not isTempoWithBuff(ev.entity) then return end
    if not ev.victim.damageCountdownResetWhenAttacked then return end
    ev.entity.damageCountdown.countdown = BUFF_COUNTDOWN
end)

event.objectKill.add("apTempoBuffCountdownOnKill", {
    filter   = "damageCountdown",
    order    = "damageCountdown",
    sequence = 1,
}, function(ev)
    if not isTempoWithBuff(ev.entity) then return end
    if not kill.Credit.check(ev.credit, kill.Credit.DAMAGE_COUNTDOWN) then return end
    ev.entity.damageCountdown.countdown = BUFF_COUNTDOWN
end)

event.objectInteract.add("apTempoBuffCountdownOnInteract", {
    filter   = "interactableResetDamageCountdown",
    order    = "activate",
    sequence = 1,
}, function(ev)
    if not ev.interactor or not ev.interactor.damageCountdown then return end
    if not isTempoWithBuff(ev.interactor) then return end
    if not ev.entity.interactableResetDamageCountdown.requireSuccess or not ev.suppressed then
        ev.interactor.damageCountdown.countdown = BUFF_COUNTDOWN
    end
end)

-- vanilla sets active = false before sequence = 1 handlers run, so override directly
event.inventoryCollectItem.override("resetDamageCountdown", function(func, ev)
    func(ev)
    if not ev.holder or not ev.holder.damageCountdown then return end
    if not isTempoWithBuff(ev.holder) then return end
    if ev.holder.damageCountdown.countdown == ev.holder.damageCountdown.countdownReset then
        ev.holder.damageCountdown.countdown = BUFF_COUNTDOWN
    end
end)

event.itemConsume.override("resetDamageCountdown", function(func, ev)
    func(ev)
    if not ev.holder or not ev.holder.damageCountdown then return end
    if not isTempoWithBuff(ev.holder) then return end
    if ev.holder.damageCountdown.countdown == ev.holder.damageCountdown.countdownReset then
        ev.holder.damageCountdown.countdown = BUFF_COUNTDOWN
    end
end)

event.renderPlayerHUD.override("damageCountdown", function(func, entity)
    if isTempoWithBuff(entity) and entity.damageCountdown and not currentLevel.isSafe() then
        hud.drawText({
            alignX = 0.5,
            alignY = 1,
            element = "damageCountdown",
            text = tostring(math.min(entity.damageCountdown.countdown, BUFF_COUNTDOWN)),
            font = ui.Font.MEDIUM,
        })
    else
        func(entity)
    end
end)

function tempo.apply(entity) end
function tempo.revoke(entity) end
return tempo
