local makeMirrorXTrap = (require "AP.scripts.traps.factories.makeMirrorXTrap").makeMirrorXTrap
local TrapHandler     = require "AP.scripts.traps.trapHandler"

TrapHandler.register("WideTrap", makeMirrorXTrap({
    name         = "WideTrap",
    flyawayText  = "W I D E!",
    mirrorXScale = 4,
}))
