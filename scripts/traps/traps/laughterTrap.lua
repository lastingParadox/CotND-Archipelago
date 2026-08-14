local makeSoundLoopTrap = (require "AP.scripts.traps.factories.makeSoundLoopTrap").makeSoundLoopTrap
local TrapHandler       = require "AP.scripts.traps.trapHandler"

TrapHandler.register("LaughterTrap", makeSoundLoopTrap({
    name        = "LaughterTrap",
    flyawayText = "Haha!",
    duration    = 10,
    minBurst    = 1,
    maxBurst    = 3,
    soundGroups = { "necrodancerLaugh" },
}))
