local collision = require "necro.game.tile.Collision"
local object    = require "necro.game.object.Object"
local rng       = require "necro.game.system.RNG"

local makeFloorTrap = (require "AP.scripts.traps.factories.makeFloorTrap").makeFloorTrap
local TrapHandler   = require "AP.scripts.traps.trapHandler"

local TRAP_CHANCE = 0.10

local TRAP_WEIGHTS = {
    SpikeTrap          = 10,
    ConfusionTrap      = 8,
    BombTrap           = 6,
    ScatterTrap        = 6,
    TeleportTrap       = 6,
    TempoUpTrap        = 4,
    TempoDownTrap      = 4,
    Sync_DiceTrap      = 3,
    BounceTrapRight    = 3,
    BounceTrapLeft     = 3,
    BounceTrapUp       = 3,
    BounceTrapDown     = 3,
    BounceTrapOmni     = 2,
    BounceTrapRotating = 2,
}

-- Sorted so every client builds the same weighted list from the same table.
local weightedTraps = {}
do
    local names = {}
    for name in pairs(TRAP_WEIGHTS) do
        names[#names + 1] = name
    end
    table.sort(names)

    for _, name in ipairs(names) do
        for _ = 1, TRAP_WEIGHTS[name] do
            weightedTraps[#weightedTraps + 1] = name
        end
    end
end

-- A tile already holding a trap has nothing to gain, and one under a player would fire the
-- instant they moved off it.
local OCCUPIED = collision.Type.mask(collision.Type.TRAP, collision.Type.PLAYER)

TrapHandler.register("TrapTrap", makeFloorTrap({
    flyawayText = "Trap Trap!",
    setTile     = function(x, y, channel)
        if collision.check(x, y, OCCUPIED) then return end
        if not rng.roll(TRAP_CHANCE, channel) then return end

        object.spawn(rng.choice(weightedTraps, channel), x, y)
    end,
}))
