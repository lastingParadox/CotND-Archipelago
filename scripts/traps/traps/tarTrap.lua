local makeFloorTrap = (require "AP.scripts.traps.factories.makeFloorTrap").makeFloorTrap
local TrapHandler   = require "AP.scripts.traps.trapHandler"

TrapHandler.register("TarTrap", makeFloorTrap({
    flyawayText = "Tar Floor!",
    tileType    = "Tar",
}))
