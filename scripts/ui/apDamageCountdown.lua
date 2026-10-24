local currentLevel = require("necro.game.level.CurrentLevel")
local hud = require("necro.render.hud.HUD")
local ui = require("necro.render.UI")

local color = require("AP.scripts.utils.apColors")

local apDamageCountdownHUD = {}

-- Offsets of the smaller timers from the centre of the slot.
local SECONDARY_OFFSET_X = 20
local SECONDARY_STEP_X = 14

local providers = {}

---Adds a countdown source: `provider(entity)` returns nil or `{ value, color?, native?, beats? }`.
---@param provider function
function apDamageCountdownHUD.register(provider)
    providers[#providers + 1] = provider
end

local function collect(entity)
    local timers = {}

    for _, provider in ipairs(providers) do
        local timer = provider(entity)
        if timer then
            timer.value = math.max(timer.value, 0)
            timers[#timers + 1] = timer
        end
    end

    return timers
end

---Whether this mod draws the entity's countdowns, so each source must not draw its own.
---@param entity table
---@return boolean
function apDamageCountdownHUD.ownsSlot(entity)
    if currentLevel.isSafe() then return false end

    local timers = collect(entity)

    return timers[2] ~= nil or (timers[1] ~= nil and not timers[1].native)
end

local function soonest(timers)
    local best = 1

    for i, timer in ipairs(timers) do
        local current = timers[best]
        if timer.beats ~= false and (current.beats == false or timer.value < current.value) then
            best = i
        end
    end

    return best
end

event.renderPlayerHUD.add("apCountdowns", { order = "damageCountdown" }, function(entity)
    if not apDamageCountdownHUD.ownsSlot(entity) then return end

    local timers = collect(entity)
    local primary = soonest(timers)
    local colored = timers[2] ~= nil

    hud.drawText({
        alignX = 0.5,
        alignY = 1,
        element = "damageCountdown",
        text = tostring(timers[primary].value),
        font = ui.Font.MEDIUM,
        fillColor = colored and timers[primary].color or nil,
    })

    local placed = 0

    for i, timer in ipairs(timers) do
        if i ~= primary then
            -- Alternates right, left, then steps further out.
            local side = placed % 2 == 0 and 1 or -1
            local distance = SECONDARY_OFFSET_X + math.floor(placed / 2) * SECONDARY_STEP_X

            hud.drawText({
                alignX = 0.5,
                alignY = 1,
                offsetX = side * distance,
                element = "damageCountdown",
                text = tostring(timer.value),
                font = ui.Font.SMALL,
                fillColor = timer.color,
            })

            placed = placed + 1
        end
    end
end)

apDamageCountdownHUD.register(function(entity)
    local countdown = entity.AP_damageCountdown
    if countdown and countdown.active then
        return { value = countdown.countdown, color = color.deathLinkCountdown }
    end
end)

apDamageCountdownHUD.register(function(entity)
    local countdown = entity.AP_timerCountdown
    if countdown and countdown.active then
        return { value = countdown.countdown, color = color.trap }
    end
end)

apDamageCountdownHUD.register(function(entity)
    local possessable = entity.Sync_possessable
    if possessable and possessable.possessor ~= 0 and entity.Sync_possessableTimer then
        local glow = entity.Sync_possessableGlow

        return {
            value = entity.Sync_possessableTimer.remainingBeats,
            color = glow and glow.color or color.possessionCountdown,
        }
    end
end)

event.renderPlayerHUD.override("Sync_possessionCountdown", function(func, entity)
    if apDamageCountdownHUD.ownsSlot(entity) then return end

    return func(entity)
end)

return apDamageCountdownHUD
