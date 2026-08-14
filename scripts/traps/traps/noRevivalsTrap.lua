local makeItemBanTrap = (require "AP.scripts.traps.factories.makeItemBanTrap").makeItemBanTrap
local TrapHandler     = require("AP.scripts.traps.trapHandler")

TrapHandler.register("NoRevivalsTrap", makeItemBanTrap({
    flyawayText = "No Revivals!",
    components  = { "itemConsumeOnLethalHit" },
    sound       = "drinkCursedPotion",
}))
