local currentLevel = require "necro.game.level.CurrentLevel"
local freeze       = require "necro.game.character.Freeze"
local rng          = require "necro.game.system.RNG"
local turn         = require "necro.cycles.Turn"

local makeFreezeTrap = (require "AP.scripts.traps.factories.makeFreezeTrap").makeFreezeTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

---Ice and Stone are the same stun mechanically; the variant is flavor.
---TrapLink can force one via args.variant, otherwise picked at random.
local trapFns = {
    Ice = makeFreezeTrap({
        turns       = 10,
        freezeType  = freeze.Type.ICE,
        sound       = "spellFreeze",
        flyawayText = "Freeze!",
    }),
    Stone = makeFreezeTrap({
        turns       = 10,
        freezeType  = freeze.Type.STONE,
        sound       = "gorgonStone",
        flyawayText = "Stoned!",
    }),
}

local variantNames = { "Ice", "Stone" }

TrapHandler.register("FreezeTrap", function(ev, args)
    local variant = args and args.variant
    if not (variant and trapFns[variant]) then
        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        variant = rng.choice(variantNames, channel)
    end
    return trapFns[variant](ev)
end)
