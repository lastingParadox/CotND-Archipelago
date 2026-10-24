local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap

makeSummonTrap({
    name          = "FreddyTrap",
    flyawayText   = "Freddy Trap!",
    sound         = "shopkeeperDeath",
    min           = 1,
    max           = 3,
    radius        = 4,
    variants      = { Shopkeeper = 2, AP_ShopkeeperAlt = 1, AP_ShopkeeperMonstrous = 1 },
    spawnProps    = false,
    particles     = false,
    checkGrabbed  = false,
    requireSpawns = true,
})
