local makeSoundLoopTrap = (require "AP.scripts.traps.factories.makeSoundLoopTrap").makeSoundLoopTrap

makeSoundLoopTrap({
    name        = "LaughterTrap",
    flyaway     = "Haha!",
    duration    = 10,
    minBurst    = 1,
    maxBurst    = 3,
    soundGroups = { "necrodancerLaugh" },
})
