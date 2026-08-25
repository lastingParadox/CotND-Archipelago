local health      = require "necro.game.character.Health"
local kill        = require "necro.game.character.Kill"
local apUtils     = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local nocturna = {}

event.objectKill.add("apNocturnaBatBuffRegen", {
    filter   = "incrementRegenerationKillCounter",
    order    = "regeneration",
    sequence = -1,
}, function(ev)
    if ev.entity.name ~= "NocturnaBat" then return end
    if not kill.Credit.check(ev.credit, kill.Credit.REGENERATION) then return end
    if not apUtils.isAPContext() then return end
    if not progression.getCharacterBuff("Nocturna") then return end

    local counter = ev.entity.regenerationKillCounter
    if not counter then return end
    local newCount = counter.killCount + ev.entity.incrementRegenerationKillCounter.increment
    if math.floor(newCount / counter.killThreshold) >= 1 then
        health.heal({ target = ev.entity, healer = ev.entity, health = 1, invincibility = 0 })
    end
end)

function nocturna.apply(entity) end
function nocturna.revoke(entity) end
return nocturna
