local apUtils       = require "AP.scripts.utils.apUtils"
local flyaway       = require "necro.game.system.Flyaway"
local invincibility  = require "necro.game.character.Invincibility"
local player        = require "necro.game.character.Player"
local progression   = require "AP.scripts.client.progression"
local spriteEffects = require "necro.render.level.SpriteEffects"

local suzu = {}

local pendingState = {}

local function isSuzuBuff()
    return apUtils.isAPContext() and progression.getCharacterBuff("Suzu")
end

event.gameStateLevel.add("apSuzuBuffClear", "resetLevelVariables", function()
    pendingState = {}
end)

event.holderPerformAttack.add("apSuzuBuffCapturePending", {
    order    = "killDash",
    sequence = 0,
    filter   = "Sync_weaponSuperCharge",
}, function(ev)
    if ev.holder.name ~= "Sync_Suzu" then return end
    pendingState[ev.holder.id] = ev.entity.Sync_weaponSuperCharge.pending
end)

event.holderPerformAttack.add("apSuzuBuffPostDashInvuln", {
    order    = "killDash",
    sequence = 2,
    filter   = "Sync_weaponSuperCharge",
}, function(ev)
    if not isSuzuBuff() then return end
    if ev.holder.name ~= "Sync_Suzu" then return end
    local wasPending = pendingState[ev.holder.id]
    pendingState[ev.holder.id] = nil
    if not wasPending then return end
    invincibility.activate(ev.holder, 2)
end)

event.objectTakeDamage.add("apSuzuBuffCourageFlyaway", {
    filter = "invincibility",
    order = "invincibility",
    sequence = 1,
}, function(ev)
    if not isSuzuBuff() or ev.entity.name ~= "Sync_Suzu" then return end
    if ev.suppressed and ev.damage > 0 and invincibility.isActive(ev.entity) then
        flyaway.createIfFocused { entity = ev.entity, text = "Courage!" }
    end
end)

event.turn.add("apSuzuBuffInvincibilityBlink", "startAnimations", function()
    if not isSuzuBuff() then return end
    for _, entity in ipairs(player.getPlayerEntities()) do
        if entity.name == "Sync_Suzu"
            and entity.invincibility
            and entity.invincibility.remainingTurns > 0
            and entity.invincibilityBlinkEffect
        then
            spriteEffects.blink(entity, entity.invincibilityBlinkEffect.duration)
        end
    end
end)

function suzu.apply() end
function suzu.revoke() end
return suzu
