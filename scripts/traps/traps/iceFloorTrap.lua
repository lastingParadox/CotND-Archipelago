local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name     = "IceFloorTrap",
    flyaway  = "Ice Floor!",
    voice    = "voiceConfused",
    duration = 16,
    floor    = { tileType = "Ice", restore = true },
})
