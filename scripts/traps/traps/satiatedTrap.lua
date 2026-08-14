local makeItemBanTrap = (require "AP.scripts.traps.factories.makeItemBanTrap").makeItemBanTrap
local TrapHandler     = require("AP.scripts.traps.trapHandler")

TrapHandler.register("SatiatedTrap", makeItemBanTrap({
    flyawayText      = "Satiated!",
    components       = { "consumableFood" },
    sound            = "eatFood",
    deleteContainers = true,
}))
