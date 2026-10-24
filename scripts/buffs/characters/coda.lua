local apDamageCountdownHUD = require "AP.scripts.ui.apDamageCountdown"
local apFlyaways  = require "AP.scripts.ui.apFlyaways"
local apUtils     = require "AP.scripts.utils.apUtils"
local progression = require "AP.scripts.client.progression"

local coda = {}

local MAX_STRIKES = 10
local codaStrikes = {}

local function isCodaBuff()
    return apUtils.isAPContext() and progression.getCharacterBuff("Coda")
end

event.levelLoad.add("apCodaBuffResetStrikes", { order = "currentLevel" }, function(level)
    if level.zone == 1 and level.floor == 1 then
        codaStrikes = {}
    end
end)

event.objectTakeDamage.add("apCodaBuffStrike", {
    filter   = "health",
    order    = "deathProtection",
    sequence = 1,
}, function(ev)
    if ev.suppressed then return end
    if not isCodaBuff() or ev.entity.name ~= "Coda" then return end
    if ev.damage <= 0 then return end
    if ev.damage < ev.entity.health.health then return end

    local currentStrikes = codaStrikes[ev.entity.id] or 0
    if currentStrikes >= MAX_STRIKES then return end

    codaStrikes[ev.entity.id] = currentStrikes + 1
    local remaining = MAX_STRIKES - (currentStrikes + 1)

    if remaining > 0 then
        ev.damage = 0
        local label = remaining == 1 and "1 strike left!" or (tostring(remaining) .. " strikes left!")
        apFlyaways.addToFlyawayQueue({ entity = ev.entity, text = label })
    end
end)

apDamageCountdownHUD.register(function(entity)
    if not isCodaBuff() or entity.name ~= "Coda" then return end

    local remaining = MAX_STRIKES - (codaStrikes[entity.id] or 0)
    if remaining > 0 then return { value = remaining, beats = false } end
end)

function coda.apply() end
function coda.revoke() end
return coda
