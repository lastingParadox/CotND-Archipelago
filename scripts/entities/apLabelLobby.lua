local ecs = require("system.game.Entities")
local customEntities = require("necro.game.data.CustomEntities")
local object = require("necro.game.object.Object")
local textFormat = require "necro.config.i18n.TextFormat"
local textPool = require "necro.config.i18n.TextPool"
local theme = require "necro.config.Theme"

local progression = require("AP.scripts.client.progression")

customEntities.register({
    name = "AP_LabelLobby",
    position = {},
    AP_labelLobby = {}
})

local function isVictoryTriggered()
    local victoryTrigger = progression.getVictoryTrigger()
    if victoryTrigger == "Boss Rush" then
        return (progression.getCharacterLocations("BossRush") or {})["Completed"] == true
    end
    if victoryTrigger == "Expensive Purchase" then
        return (progression.getCharacterLocations("ExpensivePurchase") or {})["Completed"] == true
    end
    return (progression.getCharacterLocations("Ensemble") or {})["Completed"] == true
end

local CATALYST_LABELS = {
    ["Boss Rush"]          = "Boss Rush",
    ["Expensive Purchase"] = "the Victory Purchase",
    ["Ensemble"]           = "Ensemble Mode",
    ["Disabled"]           = "victory",
}

local GOAL_MET_KEYS = {
    ["Boss Rush"]          = "mod.AP.lobby.bossRushHint",
    ["Expensive Purchase"] = "mod.AP.lobby.expensivePurchaseHint",
    ["Ensemble"]           = "mod.AP.lobby.ensembleHint",
    ["Disabled"]           = "mod.AP.lobby.noCatalystHint",
}

local GOAL_HINT_KEYS = {
    ["Zones"]              = "mod.AP.lobby.zonesHint",
    ["Golden Lute Shards"] = "mod.AP.lobby.shardsHint",
    ["All Zones"]          = "mod.AP.lobby.allZonesHint",
    ["Story"]              = "mod.AP.lobby.storyHint",
}

local function getGoalHintText(goalRequired)
    local victoryTrigger = progression.getVictoryTrigger()
    local _, goalMet = progression.calculateGoalCompletion(false)
    if goalMet then
        return textPool.format(GOAL_MET_KEYS[victoryTrigger] or "mod.AP.lobby.ensembleHint")
    end
    local goal = progression.getGoal()
    local key = GOAL_HINT_KEYS[goal] or "mod.AP.lobby.allZonesHint"
    local catalystLabel = CATALYST_LABELS[victoryTrigger] or "Ensemble Mode"
    return textPool.format(key, goalRequired, catalystLabel)
end

local function getAPStatus(goalRequired)
    local goal = progression.getGoal()

    if goal == "Golden Lute Shards" then
        if isVictoryTriggered() then
            return textFormat.color("Complete!", theme.Color.HIGHLIGHT)
        end
        local shardCount = progression.calculateGoalCompletion(false)
        if shardCount == 0 then return "" end
        return math.min(shardCount, goalRequired) .. "/" .. goalRequired .. " Shards Collected"
    end

    if isVictoryTriggered() then
        return textFormat.color("Complete!", theme.Color.HIGHLIGHT)
    end
    local amountCompleted = progression.calculateGoalCompletion(false)
    if amountCompleted == 0 then return "" end
    local display = math.min(amountCompleted, goalRequired)

    if goal == "Story" then
        return display .. "/" .. goalRequired .. " Story Bosses Beaten"
    end

    return display .. "/" .. goalRequired .. " Zones Complete"
end

event.objectSpawn.add("apSpawnLabelLobby", { filter = "AP_labelLobby", order = "items" }, function(ev)
    local goalRequired = progression.getGoalRequired()

    local top = object.spawn("LabelLobby", ev.x, ev.y - 1, {
        worldLabel = {
            offsetY = 3,
            text = getGoalHintText(goalRequired)
        },
    })

    ev.entity.AP_labelLobby.topLabel = top

    local bottom = object.spawn("LabelLobby", ev.x, ev.y, {
        worldLabel = {
            offsetY = 11,
            text = getAPStatus(goalRequired)
        },
    })

    ev.entity.AP_labelLobby.bottomLabel = bottom
end)

local function refreshLabels()
    for entity in ecs.entitiesWithComponents({ "AP_labelLobby" }) do
        local goalRequired = progression.getGoalRequired()
        if entity.AP_labelLobby.topLabel then
            local topLabel = ecs.getEntityByID(entity.AP_labelLobby.topLabel)
            if topLabel then
                topLabel.worldLabel.text = getGoalHintText(goalRequired)
            end
        end
        if entity.AP_labelLobby.bottomLabel then
            local bottomLabel = ecs.getEntityByID(entity.AP_labelLobby.bottomLabel)
            if bottomLabel then
                bottomLabel.worldLabel.text = getAPStatus(goalRequired)
            end
        end
    end
end

event.apConnect.add("apLabelLobbyUpdate", { order = "connected", sequence = 1 }, function(ev)
    if ev.status ~= "Connected" then return end
    refreshLabels()
end)

event.updateVisuals.add("apLabelLobbyRefresh", { order = "worldLabel" }, function()
    refreshLabels()
end)
