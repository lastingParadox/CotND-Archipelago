local tile      = require "necro.game.tile.Tile"
local tileTypes = require "necro.game.tile.TileTypes"
local rng       = require "necro.game.system.RNG"

local makeFloorTrap = (require "AP.scripts.traps.factories.makeFloorTrap").makeFloorTrap
local TrapHandler   = require "AP.scripts.traps.trapHandler"

-- Build a pool of all valid non-immutable floor tile IDs (numeric).
local function buildFloorPool(_channel)
    local pool = {}
    for id = 1, tileTypes.getMaximumTileID() do
        local info = tileTypes.getTileInfo(id)
        if info and info.isFloor and not info.immutable then
            pool[#pool + 1] = id
        end
    end
    return pool
end

TrapHandler.register("ChaosTrap", makeFloorTrap({
    flyawayText = "Chaos!",
    prepare     = buildFloorPool,
    setTile     = function(x, y, channel, pool)
        tile.set(x, y, rng.choice(pool, channel))
    end,
}))
