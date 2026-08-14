local makeItemBanTrap = (require "AP.scripts.traps.factories.makeItemBanTrap").makeItemBanTrap
local TrapHandler     = require("AP.scripts.traps.trapHandler")

TrapHandler.register("CommandoTrap", makeItemBanTrap({
    flyawayText      = "Commando!",
    components       = { "itemArmor", "itemArmorHeadSpriteRow" },
    voice            = "voiceConfused",
    deleteFloor      = true,
    deleteContainers = true,
}))
