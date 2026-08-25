local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

-- No aggro, no stair lock, no catch: a crowd of shopkeepers turns up and sings over each
-- other. The joke is the whole effect.
TrapHandler.register("FreddyTrap", makeSummonTrap({
    flyawayText   = "Freddy Trap!",
    sound         = "shopkeeperCry",
    min           = 1,
    max           = 1,
    radius        = 4,
    variants      = { Shopkeeper = 4, Shopkeeper2 = 1, Shopkeer3 = 1, Shopkeeper4 = 1 },
    spawnProps    = false,
    particles     = false,
    checkGrabbed  = false,
    requireSpawns = true,
}))
