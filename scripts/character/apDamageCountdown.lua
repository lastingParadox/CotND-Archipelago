local currentLevel = require("necro.game.level.CurrentLevel")
local damage = require("necro.game.system.Damage")
local flyaway = require("necro.game.system.Flyaway")
local gameDLC = require "necro.game.data.resource.GameDLC"
local kill = require "necro.game.character.Kill"
local sound = require("necro.audio.Sound")
local ecs = require("system.game.Entities")

local apFlags = require("AP.scripts.utils.flags")

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

-- DeathLink's countdown and the Timer Trap's, run side by side.
local COUNTDOWNS = { "AP_damageCountdown", "AP_timerCountdown" }

local FIELDS = { "countdown", "countdownReset", "damage", "killerName", "type" }

local function ticks(entity, countdown)
    return entity.gameObject.active and countdown.active
        and (not entity.descent or not entity.descent.active)
        and (not entity.grooveChainImmunity or not entity.grooveChainImmunity.idle)
end

local function tick(entity, countdown)
    local remaining = countdown.countdown
    countdown.countdown = remaining - 1

    if remaining <= 0 then
        local possessor = entity.Sync_possessable and ecs.getEntityByID(entity.Sync_possessable.possessor)

        damage.inflict({
            type = countdown.type,
            damage = countdown.damage,
            killerName = countdown.killerName,
            victim = entity
        })

        -- A DeathLink run out on a possessed body takes Chaunter with it.
        if possessor and countdown.type == apFlags.DAMAGE_DEATH_LINK then
            damage.inflict({
                type = countdown.type,
                damage = countdown.damage,
                killerName = countdown.killerName,
                victim = possessor
            })
        end

        countdown.countdown = countdown.countdownReset
    end

    local text = damageCountdownFlyaways.texts[remaining]

    if text then
        flyaway.create({ entity = entity, text = text })
    end

    local soundEntry = getDamageCountdownSound(entity, remaining)

    if soundEntry then
        sound.playIfFocused(soundEntry, entity)
    end
end

event.turn.add("apReduceDamageCountdown", "damageCountdown", function()
    if currentLevel.isSafe() then return end

    for _, component in ipairs(COUNTDOWNS) do
        for entity in ecs.entitiesWithComponents({ component }) do
            local countdown = entity[component]

            if ticks(entity, countdown) then
                tick(entity, countdown)
            end
        end
    end
end)

event.objectKill.add("apResetTimerCountdownOnKill", { filter = "AP_timerCountdown", order = "damageCountdown" },
    function(ev)
        local countdown = ev.entity.AP_timerCountdown

        if countdown.active and kill.Credit.check(ev.credit, kill.Credit.DAMAGE_COUNTDOWN) then
            countdown.countdown = countdown.countdownReset
        end
    end)

event.gameStateLevel.add("apRemoveDamageCountdown", "damageCountdown", function()
    for _, component in ipairs(COUNTDOWNS) do
        for entity in ecs.entitiesWithComponents({ component }) do
            entity[component].active = false
        end
    end
end)

event.entitySchemaLoadEntity.add("apDamageCountdownOnControllable", { order = "overrides", sequence = 2 },
    function(ev)
        if ev.entity.controllable then
            for _, component in ipairs(COUNTDOWNS) do
                ev.entity[component] = ev.entity[component] or {}
            end
        end
    end)

local carried = {}

event.objectControllerChanged.add("apCarryDamageCountdown", { order = "player", sequence = -1 },
    function(ev)
        -- Arriving in a new body: pick the countdowns back up.
        if ev.playerID then
            for component, saved in pairs(carried[ev.playerID] or {}) do
                local countdown = ev.entity[component]

                if countdown then
                    for _, field in ipairs(FIELDS) do countdown[field] = saved[field] end
                    countdown.active = true
                end
            end

            carried[ev.playerID] = nil
            return
        end

        local playerID = ev.entity.controllable and ev.entity.controllable.playerID
        if not (playerID and playerID ~= 0) then return end

        for _, component in ipairs(COUNTDOWNS) do
            local countdown = ev.entity[component]

            if countdown and countdown.active then
                local saved = {}
                for _, field in ipairs(FIELDS) do saved[field] = countdown[field] end

                carried[playerID] = carried[playerID] or {}
                carried[playerID][component] = saved
                countdown.active = false
            end
        end
    end)

-- Dropped with the countdowns themselves, at the end of the floor they were owed on.
event.gameStateLevel.add("apClearCarriedDamageCountdown", "damageCountdown", function()
    carried = {}
end)
