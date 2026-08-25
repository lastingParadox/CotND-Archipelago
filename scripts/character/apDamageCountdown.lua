local currentLevel = require("necro.game.level.CurrentLevel")
local damage = require("necro.game.system.Damage")
local flyaway = require("necro.game.system.Flyaway")
local gameDLC = require "necro.game.data.resource.GameDLC"
local sound = require("necro.audio.Sound")
local ecs = require("system.game.Entities")

local damageCountdownFlyaways = {
    texts = {
        "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        nil,
        nil,
        nil,
        nil,
        "10",
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        "20",
        nil,
        nil,
        nil,
        "23"
    }
}
local soundDamageCountdown = {
    sounds = {
        "tempoTick4",
        "tempoTick3",
        "tempoTick2",
        "tempoTick1"
    }
}

local function getDamageCountdownSound(entity, countdown)
    if gameDLC.isAmplifiedLoaded() then
        return soundDamageCountdown.sounds[countdown]
    end

    local baseName = string.lower(entity.name or "cadence")
    local fallbackSounds = {
        baseName .. "Melee4",
        baseName .. "Melee3",
        baseName .. "Melee2",
        baseName .. "Melee1"
    }

    return fallbackSounds[countdown]
end

event.turn.add("apReduceDamageCountdown", "damageCountdown", function(ev)
    for entity in ecs.entitiesWithComponents({
        "AP_damageCountdown"
    }) do
        if entity.gameObject.active and entity.AP_damageCountdown.active and (not entity.descent or not entity.descent.active) and (not entity.grooveChainImmunity or not entity.grooveChainImmunity.idle) and not currentLevel.isSafe() then
            local countdown = entity.AP_damageCountdown.countdown
            entity.AP_damageCountdown.countdown = countdown - 1

            if countdown <= 0 then
                damage.inflict({
                    type = entity.AP_damageCountdown.type,
                    damage = entity.AP_damageCountdown.damage,
                    killerName = entity.AP_damageCountdown.killerName,
                    victim = entity
                })

                entity.AP_damageCountdown.countdown = entity.AP_damageCountdown.countdownReset
            end

            local text = damageCountdownFlyaways.texts[countdown]

            if text then
                flyaway.create({ entity = entity, text = text })
            end

            local soundEntry = getDamageCountdownSound(entity, countdown)

            if soundEntry then
                sound.playIfFocused(soundEntry, entity)
            end
        end
    end
end)
event.gameStateLevel.add("apRemoveDamageCountdown", "damageCountdown", function(ev)
    for entity in ecs.entitiesWithComponents({
        "AP_damageCountdown"
    }) do
        entity.AP_damageCountdown.active = false
        entity.AP_damageCountdown.countdown = 24
        entity.AP_damageCountdown.killerName = "DeathLink"
    end
end)


