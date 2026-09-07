local ecs = require("system.game.Entities")
local enum = require("system.utils.Enum")
local gameSession = require("necro.client.GameSession")
local multiCharacter = require("necro.game.data.modifier.MultiCharacter")

-- apCharacters and progression are lazy-required to avoid a load-time cyclic dependency.

gameSession.Mode.extend(
    "APEnsemble",
    enum.data({
        id = "APEnsemble",
        name = "AP Ensemble",
        visible = false,
        bossFlawlesses = true,
        cutscenes = true,
        diamondCounter = true,
        extraEnemiesPerFloor = 3,
        generatorOptions = {
            type = "Necro",
        },
        introText = true,
        multiCharEnabled = true,
        progressionUnlockCharacters = false,
        resetDiamonds = false,
        resetTimeScale = true,
        statisticsEnabled = true,
        statisticsTrackHardcoreClears = true,
        timerHUD = true,
        timerName = "Speedrun",
    })
)

-- Never call multiCharacter.getCharacterList() in here; it recurses back into this function.
multiCharacter.Mode.extend("AP_ENSEMBLE", enum.data({
    ensemble = true,
    defaultCharacter = "Cadence",
    storyBossCharacters = {},
    columns = 4,
    characters = function()
        local apCharacters = require("AP.scripts.utils.apCharacters")
        local progression = require("AP.scripts.client.progression")
        local result = {}

        for _, charName in ipairs(progression.getPlayableCharacters()) do
            local cotndName = apCharacters.apLocationToCotNDChar(charName)
            if ecs.typeHasComponent(cotndName, "controllable") then
                table.insert(result, cotndName)
            end
        end

        table.sort(result)

        if #result == 0 then
            local startChar = apCharacters.apLocationToCotNDChar(
                progression.getStartingCharacter() or "Cadence"
            )
            if not ecs.typeHasComponent(startChar, "controllable") then
                startChar = "Cadence"
            end
            result = { startChar }
        end

        local numSlots = progression.isDLCEnabled("Amplified") and 20 or 16
        local numChars = #result
        local expanded = {}
        for i = 1, numSlots do
            expanded[i] = result[((i - 1) % numChars) + 1]
        end
        return expanded
    end,
}))

event.runSettingsInit.add("apEnsembleInitMultiChar", "extraModes", function(ev)
    if ev.mode.id ~= "APEnsemble" then return end
    ev.settings["gameplay.modifiers.multiChar"] = multiCharacter.Mode.AP_ENSEMBLE
end)

event.levelSequenceUpdate.add("apEnsembleColumns", { order = "initEnsemble" }, function(ev)
    if ev.mode.id ~= "APEnsemble" then return end
    local progression = require("AP.scripts.client.progression")
    local apAmplifiedEnabled = progression.isDLCEnabled("Amplified")
    multiCharacter.Mode.data[multiCharacter.Mode.AP_ENSEMBLE].columns = apAmplifiedEnabled and 5 or 4
end)
