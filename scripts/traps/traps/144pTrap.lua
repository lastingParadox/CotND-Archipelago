local gameWindow      = require("necro.config.GameWindow")
local settingsStorage = require("necro.config.SettingsStorage")

local trapSystem = require("AP.scripts.traps.trapSystem")

local DURATION        = 20
local trapResolution  = { width = 256, height = 144 }
local trapScaleFactor = 1
local trapScaleMode   = gameWindow.ScaleMode.FIXED

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

trapSystem.define({
    name     = "144pTrap",
    flyaway  = "144p!",
    duration = DURATION,
    clock    = trapSystem.Clock.REAL,
    -- Window settings, which must survive a rollback rather than snap back.
    storage  = trapSystem.Storage.VOLATILE,
    -- Saves the original display settings and applies 144p, aborting if they cannot be read.
    start    = function(ctx)
        local currentResolution = getConfiguredResolution()
        if not currentResolution then return false end

        ctx.state.resolution = { width = currentResolution.width, height = currentResolution.height }

        local currentScale = getConfiguredScale()
        if currentScale then
            ctx.state.scaleFactor = currentScale.scaleFactor
            ctx.state.scaleMode   = currentScale.scaleMode
        end

        if not setDisplaySettings(trapResolution.width, trapResolution.height,
                trapScaleFactor, trapScaleMode) then
            return false
        end

        return true
    end,
    -- Re-enforce 144p in case the player manually resizes.
    tick     = function()
        local cur   = getConfiguredResolution()
        local scale = getConfiguredScale()
        if not cur or not scale
            or cur.width  ~= trapResolution.width
            or cur.height ~= trapResolution.height
            or scale.scaleFactor ~= trapScaleFactor
            or scale.scaleMode   ~= trapScaleMode then
            setDisplaySettings(trapResolution.width, trapResolution.height, trapScaleFactor, trapScaleMode)
        end
    end,
    expire   = function(ctx)
        if not ctx.state.resolution then return end

        setDisplaySettings(
            ctx.state.resolution.width, ctx.state.resolution.height,
            ctx.state.scaleFactor, ctx.state.scaleMode
        )
    end,
})
