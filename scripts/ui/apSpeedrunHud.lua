local countdown = require "necro.client.Countdown"
local currentLevel = require "necro.game.level.CurrentLevel"
local focus = require "necro.game.character.Focus"
local gameSession = require "necro.client.GameSession"
local gfx = require "system.gfx.GFX"
local hud = require "necro.render.hud.HUD"
local instantReplay = require "necro.client.replay.InstantReplay"
local replayPlayer = require "necro.client.replay.ReplayPlayer"
local runSummary = require "necro.client.RunSummary"
local settingsStorage = require "necro.config.SettingsStorage"
local speedrunTimer = require "necro.client.SpeedrunTimer"
local textFormat = require "necro.config.i18n.TextFormat"
local theme = require "necro.config.Theme"
local ui = require "necro.render.UI"

local apCharacters = require("AP.scripts.utils.apCharacters")
local progression = require("AP.scripts.client.progression")

local apSpeedrunHud = {}

local MARK_PASS = "mods/AP/gfx/icons/ap_check.png"
local MARK_FAIL = "mods/AP/gfx/icons/ap_no_check.png"
local MARK_SCALE = 1

function apSpeedrunHud.getTargetSeconds()
    if gameSession.getCurrentMode().id ~= "APAllZones" then return nil end

    local hudEntity = focus.getFirst(focus.Flag.HUD)
    if not hudEntity then return nil end

    local minutes = progression.getSpeedrunTime(apCharacters.cotNDCharToAPLocation(hudEntity.name))
    if minutes == 0 then return nil end

    return minutes * 60
end

function apSpeedrunHud.formatTarget(seconds)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

event.renderGlobalHUD.add("apSpeedrunTarget", { order = "timer", sequence = -1 }, function(ev)
    if ev.timerName ~= nil then return end

    local target = apSpeedrunHud.getTargetSeconds()
    if not target then return end

    ev.timerName = ("All Zones (%s)"):format(apSpeedrunHud.formatTarget(target))
end)

-- Mirrors TimerHUD's own getTime so the number does not jump when the colour changes.
local function getDisplayTime()
    local summary = runSummary.getPendingSummary()
        or runSummary.getDecisiveSummary()
        or runSummary.getFinalSummary()
    local countdownTarget = countdown.getUpcomingTargetTime()
    local time = summary and summary.duration
        or (countdownTarget and speedrunTimer.getCumulativeLevelTime() + countdownTarget)
        or speedrunTimer.getTime()

    if replayPlayer.hasAutoSkip() then
        time = time - speedrunTimer.getCurrentLoopStartTime()
    end

    return time
end

function apSpeedrunHud.isExceeded()
    local target = apSpeedrunHud.getTargetSeconds()
    return target ~= nil and getDisplayTime() > target
end

event.renderGlobalHUD.override("renderSpeedrunTimer", function(func, ev)
    if not apSpeedrunHud.isExceeded() then return func(ev) end

    local mode = currentLevel.getMode()
    if not mode.timerHUD or ev.timerHUD == false or instantReplay.isActive()
        or settingsStorage.get("video.hud.showSpeedrunTimer") == false then
        return func(ev)
    end

    local timerName = ev.timerName
    if timerName == nil and gfx.getWidth() > 600 then
        timerName = mode.timerName or "Speedrun"
    end

    local formatted = speedrunTimer.formatTime(getDisplayTime())

    hud.drawText({
        alignY = 1,
        element = "timer",
        useCache = false,
        maxWidth = -1,
        text = timerName and ("%s: %s"):format(timerName, formatted) or formatted,
        font = ui.Font.MEDIUM,
        scale = mode.timerNameScale or 1,
        fillColor = theme.Color.STATUS_ERROR,
    })
end)

event.menu.override("runSummary", function(func, ev)
    func(ev)

    local result = progression.getSpeedrunResult()
    if not result then return end

    local summary = (ev.arg and ev.arg.summary) or runSummary.getActiveSummary()
    local durationText = summary and summary.duration
        and speedrunTimer.formatTime(summary.duration)

    local tint = result.passed and theme.Color.STATUS_OK or theme.Color.STATUS_ERROR

    for _, entry in ipairs(ev.menu and ev.menu.entries or {}) do
        if entry.id == "duration" then
            entry.label = ("%s %s (goal %s)"):format(entry.label,
                textFormat.icon(result.passed and MARK_PASS or MARK_FAIL, MARK_SCALE),
                apSpeedrunHud.formatTarget(result.target))

            if durationText then
                local first, last = entry.label:find(durationText, 1, true)
                if first then
                    entry.label = entry.label:sub(1, first - 1)
                        .. textFormat.color(durationText, tint)
                        .. entry.label:sub(last + 1)
                end
            end
        end
    end
end)

return apSpeedrunHud
