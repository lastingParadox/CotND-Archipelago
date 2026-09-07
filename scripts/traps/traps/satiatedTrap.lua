local makeItemBanTrap = (require "AP.scripts.traps.factories.makeItemBanTrap").makeItemBanTrap

makeItemBanTrap({
    name             = "SatiatedTrap",
    flyaway          = "Satiated!",
    components       = { "consumableFood" },
    sound            = "eatFood",
    deleteContainers = true,
})
