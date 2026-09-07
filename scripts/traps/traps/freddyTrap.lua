local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap

-- No aggro, no stair lock: a crowd of shopkeepers turns up and sings over each other.
makeSummonTrap({
    name          = "FreddyTrap",
    flyawayText   = "Freddy Trap!",
    sound         = "shopkeeperCry",
    min           = 1,
    max           = 1,
    radius        = 4,
    variants      = { Shopkeeper = 4, Shopkeeper2 = 1, Shopkeeper3 = 1, Shopkeeper4 = 1 },
    spawnProps    = false,
    particles     = false,
    checkGrabbed  = false,
    requireSpawns = true,
})
