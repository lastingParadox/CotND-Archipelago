local makeItemBanTrap = (require "AP.scripts.traps.factories.makeItemBanTrap").makeItemBanTrap

makeItemBanTrap({
    name             = "CommandoTrap",
    flyaway          = "Commando!",
    components       = { "itemArmor", "itemArmorHeadSpriteRow" },
    voice            = "voiceConfused",
    deleteFloor      = true,
    deleteContainers = true,
})
