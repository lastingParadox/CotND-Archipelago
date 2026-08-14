local gameWindow       = require("necro.config.GameWindow")
local settingsStorage  = require("necro.config.SettingsStorage")
local timer            = require("system.utils.Timer")

local makeCameraTrap = (require "AP.scripts.traps.factories.makeCameraTrap").makeCameraTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local DURATION        = 20
local trapResolution  = { width = 256, height = 144 }
local trapScaleFactor = 1
local trapScaleMode   = gameWindow.ScaleMode.FIXED

local trapTimestamp      = 0
local originalResolution = nil
local originalScaleFactor = nil
local originalScaleMode  = nil
trapTimestamp, originalResolution, originalScaleFactor, originalScaleMode = script.persist(function()
    return trapTimestamp, originalResolution, originalScaleFactor, originalScaleMode
end)

local function normalizeScaleMode(scaleMode)
    if scaleMode == nil then return nil end
    if type(scaleMode) == "number" then return scaleMode end
    if type(scaleMode) == "string" then
        local numericMode = tonumber(scaleMode)
        if numericMode ~= nil then return numericMode end
        local enumKey = string.upper(scaleMode)
        local enumValue = gameWindow.ScaleMode and gameWindow.ScaleMode[enumKey]
        if type(enumValue) == "number" then return enumValue end
    end
    return nil
end

local function setDisplaySettings(width, height, scaleFactor, scaleMode)
    if type(width) ~= "number" or type(height) ~= "number" then return false end
    if scaleFactor ~= nil and type(scaleFactor) ~= "number" then return false end
    local rawScaleMode = scaleMode
    scaleMode = normalizeScaleMode(scaleMode)
    if scaleMode == nil and rawScaleMode ~= nil then return false end
    if scaleMode ~= nil and type(scaleMode) ~= "number" then return false end
    if width < 10 or height < 10 or width > 15360 or height > 8640 then return false end
    settingsStorage.set("video.resolution.width",  math.floor(width))
    settingsStorage.set("video.resolution.height", math.floor(height))
    if scaleFactor ~= nil then settingsStorage.set("display.scaleFactor", scaleFactor) end
    if scaleMode   ~= nil then settingsStorage.set("display.scaleMode",   scaleMode)   end
    gameWindow.applyChanges()
    return true
end

local function getConfiguredResolution()
    local width  = tonumber(settingsStorage.get("video.resolution.width"))
    local height = tonumber(settingsStorage.get("video.resolution.height"))
    if not width or not height then return nil end
    return { width = width, height = height }
end

local function getConfiguredScale()
    local scaleFactor = tonumber(settingsStorage.get("display.scaleFactor"))
    local scaleMode   = normalizeScaleMode(settingsStorage.get("display.scaleMode"))
    if not scaleFactor or scaleMode == nil then return nil end
    return { scaleFactor = scaleFactor, scaleMode = scaleMode }
end

local function restoreResolution()
    if not originalResolution then return end
    local restored = setDisplaySettings(
        originalResolution.width, originalResolution.height,
        originalScaleFactor, originalScaleMode
    )
    if restored then
        originalResolution  = nil
        originalScaleFactor = nil
        originalScaleMode   = nil
    end
end

TrapHandler.register("144pTrap", makeCameraTrap({
    name        = "144pTrap",
    flyawayText = "144p!",
    duration    = DURATION,

    isActive     = function() return trapTimestamp ~= 0 end,
    getTimestamp = function() return trapTimestamp end,
    setTimestamp = function(t) trapTimestamp = t end,

    -- Save original display settings and apply 144p on trigger.
    -- Return false to cancel if settings cannot be read (defensive guard).
    onTrigger = function()
        local currentResolution = getConfiguredResolution()
        if not currentResolution then return false end
        local currentScale = getConfiguredScale()
        originalResolution  = { width = currentResolution.width, height = currentResolution.height }
        if currentScale then
            originalScaleFactor = currentScale.scaleFactor
            originalScaleMode   = currentScale.scaleMode
        end
        local applied = setDisplaySettings(
            trapResolution.width, trapResolution.height,
            trapScaleFactor, trapScaleMode
        )
        if not applied then return false end
    end,

    -- Re-enforce 144p each tick in case the player manually resizes.
    tickEffect = function()
        local cur = getConfiguredResolution()
        local scale = getConfiguredScale()
        if not cur or not scale
            or cur.width  ~= trapResolution.width
            or cur.height ~= trapResolution.height
            or scale.scaleFactor ~= trapScaleFactor
            or scale.scaleMode   ~= trapScaleMode then
            setDisplaySettings(trapResolution.width, trapResolution.height, trapScaleFactor, trapScaleMode)
        end
    end,

    onExpire = restoreResolution,
    -- onExit: expire() already calls onExpire (= restoreResolution), so no additional teardown needed.
    -- The handler is still registered by passing a no-op so the factory sets up event.exit.
    onExit = function() end,
}))
