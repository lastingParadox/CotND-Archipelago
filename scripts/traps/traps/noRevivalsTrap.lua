local makeItemBanTrap = (require "AP.scripts.traps.factories.makeItemBanTrap").makeItemBanTrap

makeItemBanTrap({
    name       = "NoRevivalsTrap",
    flyaway    = "No Revivals!",
    components = { "itemConsumeOnLethalHit" },
    sound      = "drinkCursedPotion",
})
