local makeMirrorXTrap = (require "AP.scripts.traps.factories.makeMirrorXTrap").makeMirrorXTrap
local TrapHandler     = require "AP.scripts.traps.trapHandler"

TrapHandler.register("PaperTrap", makeMirrorXTrap({
    name         = "PaperTrap",
    flyawayText  = "Papered!",
    sound        = "spellFreeze",
    mirrorXScale = 0.05,
    scaleY       = 1.0,
    eventOrder   = "sprite",
    targetAll    = true,
}))
