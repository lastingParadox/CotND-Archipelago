local currentLevel = require "necro.game.level.CurrentLevel"
local gameSession = require "necro.client.GameSession"
local predictor = require "necro.game.system.Predictor"

local apLocationItem = require("AP.scripts.utils.apLocationItem")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local FLAWLESS = "Flawless"

local function flawlessChecksActive()
    if not apUtils.isAPContext() then return false end
    if gameSession.getCurrentMode().id == "APBossRush" then return false end
    if predictor.isGameStateSpeculative() then return false end

    return currentLevel.isBoss() and progression.getFlawlessChestChecks()
end

-- After "storageInit" filled the chest, before "markSeen" reads it.
event.objectSpawn.add("apStockFlawlessChest", { filter = "chestLike", order = "markSeen", sequence = -1 },
    function(ev)
        if not flawlessChecksActive() then return end

        -- All three chests carry the same check, since the player may open any one of them.
        local located = progression.getNextChestLocation(currentLevel.getZone(), FLAWLESS)
        if not located then return end

        local locationName = located.Location
        if not locationName or locationName == "" then return end

        apLocationItem.store(ev.entity, located, locationName)
    end)
