local rng = require "necro.game.system.RNG"

local makeTempoTrap = (require "AP.scripts.traps.factories.makeTempoTrap").makeTempoTrap
local TrapHandler   = require "AP.scripts.traps.trapHandler"

---Forceable variants (harsher than the random rolls, matching the old
---standalone Fast/Slow traps).
local VARIANTS = {
    Fast = { 1.25, "Fast!" },
    Slow = { 0.75, "Slow!" },
}

---Classic in-game tempo trap rolls used when no variant is forced.
local RANDOM_CHOICES = {
    { 0.875, "Tempo Down!" },
    { 1.125, "Tempo Up!" },
}

-- All variants share one makeTempoTrap instance (and thus one active-region
-- slot), so tempo effects can never stack with each other.
local requestedVariant = nil

local tempoFn = makeTempoTrap({
    name      = "TempoTrap",
    getFactor = function(channel)
        local forced = requestedVariant and VARIANTS[requestedVariant]
        if forced then
            return forced[1], forced[2]
        end
        local entry = rng.choice(RANDOM_CHOICES, channel)
        return entry[1], entry[2]
    end,
})

TrapHandler.register("TempoTrap", function(ev, args)
    requestedVariant = args and args.variant or nil
    return tempoFn(ev)
end)
