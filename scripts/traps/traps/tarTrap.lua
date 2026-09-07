local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name    = "TarTrap",
    flyaway = "Tar Floor!",
    voice   = "voiceConfused",
    floor   = { tileType = "Tar" },
})
