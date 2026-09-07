local makeMirrorXTrap = (require "AP.scripts.traps.factories.makeMirrorXTrap").makeMirrorXTrap

makeMirrorXTrap({
    name         = "PaperTrap",
    flyaway      = "Papered!",
    sound        = "spellFreeze",
    mirrorXScale = 0.05,
    scaleY       = 1.0,
    eventOrder   = "sprite",
    targetAll    = true,
})
