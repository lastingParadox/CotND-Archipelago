local gameSession = require "necro.client.GameSession"
local enum = require("system.utils.Enum")

gameSession.Mode.extend(
    "APSingleZone",
    enum.data({
        id = "APSingleZone",
        name = "AP Single Zone",
        cutscenes = true,
        depthPriceMultiplier = false,
        diamondCounter = true,
        generatorOptions = {
            type = "Necro",
            procedural = {
                singleZone = true,
            },
        },
        multiCharEnabled = false,
        progressionClearGrants = false,
        progressionUnlockCharacters = false,
        resetDiamonds = false,
        seedHUD = false,
        statisticsEnabled = true,
        statisticsIgnoreLeaderboardConditions = true,
        visible = false,
    })
)

gameSession.Mode.extend(
    "APHintMode",
    enum.data({
        id = "APHintMode",
        name = "AP Hint Run",
        cutscenes = true,
        depthPriceMultiplier = false,
        diamondCounter = true,
        generatorOptions = {
            type = "Necro",
            procedural = {
                singleZone = true,
            },
        },
        multiCharEnabled = false,
        progressionClearGrants = false,
        progressionUnlockCharacters = false,
        resetDiamonds = false,
        seedHUD = false,
        statisticsEnabled = true,
        statisticsIgnoreLeaderboardConditions = true,
        visible = false,
    })
)
