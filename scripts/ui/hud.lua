local Event = require("necro.event.Event")
local currentLevel = require("necro.game.level.CurrentLevel")
local gameMod = require("necro.game.data.resource.GameMod")
local gameWindow = require("necro.config.GameWindow")
local hud = require("necro.render.hud.HUD")
local leaderboardContext = require("necro.client.leaderboard.LeaderboardContext")
local lowPercent = require("necro.game.item.LowPercent")
local menu = require("necro.menu.Menu")
local multiInstance = require("necro.client.MultiInstance")
local render = require("necro.render.Render")
local settings = require("necro.config.Settings")
local soundtrack = require("necro.game.data.Soundtrack")
local ui = require("necro.render.UI")
local color = require("system.utils.Color")
local gfx = require("system.gfx.GFX")
local customText = L("Custom mode", "indicator.customModeActive")
local customMusicText = L("Custom music", "indicator.customMusicActive")
local moddedText = L("Modded", "indicator.modsActive")
local customColor = color.rgb(170, 80, 80)
local lowPercentText = L("Low percent")
local lowPercentColor = color.rgb(51, 51, 170)
local indicatorHUD = require("necro.render.hud.IndicatorHUD")
local settingsStorage = require("necro.config.SettingsStorage")
local apConnection = require("AP.scripts.ap_handlers.APConnection")

local function renderIndicator(text, textColor, y)
    local scale = gameWindow.getEffectiveScale() < 1 and 4 or 3
    y = y or gfx.getHeight() - 20

    if text then
        ui.drawText({
            alignY = 1,
            buffer = menu.isOpen() and render.Buffer.UI_MENU or render.Buffer.UI_HUD,
            text = text,
            font = ui.Font.SMALL,
            fillColor = textColor,
            size = ui.Font.SMALL.size * scale,
            x = math.max(hud.getOverscanMargins().left + 10, 20),
            y = y - hud.getOverscanMargins().bottom
        })
    end

    return y - scale * 8
end

apDisplayMode = settings.user.enum({
    id = "AP.hud.indicator",
    name = "Show AP connected indicator",
    enum = indicatorHUD.DisplayMode,
    default = indicatorHUD.DisplayMode.LOBBY
})

Event.renderUI.override("renderLowPercentIndicator", function(func, ev)
    if ev.showIndicatorHUD == false then
        return
    end

    local currentMenu = menu.getCurrent()

    if currentMenu and not currentMenu.showIndicatorHUD then
        return
    end

    local hasIndicatorMenu = currentMenu and currentMenu.showIndicatorHUD
    local y = nil

    if currentLevel.getMode().lowPercentHUD ~= false then
        y = renderIndicator(hasIndicatorMenu and lowPercent.isActive() and lowPercentText, lowPercentColor, y)
    end

    local vanillaModdedMode = settingsStorage.get("video.hud.indicator.modded")
    local visFunc = indicatorHUD.DisplayMode.data[vanillaModdedMode].func
    local apVisFunc = indicatorHUD.DisplayMode.data[apDisplayMode].func

    if not multiInstance.isDuplicate() and (leaderboardContext.isDisabledByModifications() or soundtrack.isCustomMusicEnabled()) then
        if apVisFunc and apVisFunc(hasIndicatorMenu) then
            if apConnection.connected then
                y = renderIndicator(L("AP Connected", "indicator.apModeActive"), color.rgb(95, 168, 80), y)
            else
                y = renderIndicator(L("AP Disconnected", "indicator.apModeInactive"), color.rgb(105, 105, 105), y)
            end
        end

        if visFunc and visFunc(hasIndicatorMenu) then
            if gameMod.isModdedSession() then
                y = renderIndicator(moddedText, customColor, y)
            elseif soundtrack.isCustomMusicEnabled() then
                y = renderIndicator(customMusicText, customColor, y)
            else
                y = renderIndicator(customText, customColor, y)
            end
        end

        ev.hasModdedIndicator = true
    end
end)
