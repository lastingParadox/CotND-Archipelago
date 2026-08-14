local gameSession = require "necro.client.GameSession"
local enum = require("system.utils.Enum")

gameSession.Mode.extend(
    "APAllZones",
    enum.data({
        id = "APAllZones",
        name = "AP Zones Mode",
        visible = false,
        bossFlawlesses = true,
        cutscenes = true,
        diamondCounter = true,
        extraEnemiesPerFloor = 3,
        generatorOptions = {
            type = "Necro",
        },
        introText = true,
        multiCharEnabled = false,
        progressionUnlockCharacters = false,
        resetDiamonds = false,
        resetTimeScale = true,
        statisticsEnabled = true,
        statisticsTrackHardcoreClears = true,
        timerHUD = true,
        timerName = "Speedrun",
    })
)
