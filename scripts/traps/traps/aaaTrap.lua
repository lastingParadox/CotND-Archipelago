local makeSoundLoopTrap = (require "AP.scripts.traps.factories.makeSoundLoopTrap").makeSoundLoopTrap
local TrapHandler       = require "AP.scripts.traps.trapHandler"

TrapHandler.register("AaaTrap", makeSoundLoopTrap({
    name        = "AaaTrap",
    flyawayText = "AAA!",
    duration    = 5,
    minBurst    = 2,
    maxBurst    = 4,
    soundGroups = {
        "deadRingerCharge",
        "deadRingerLaugh",
        "deadRingerAngry",
        "deadRingerHammer",
        "deadRingerDeath",
        "necrodancerLaugh",
        "necrodancerDeath",
        "deathMetal_welcome",
        "deathMetal_death",
    },
}))
