local rng       = require "necro.game.system.RNG"
local tile      = require "necro.game.tile.Tile"
local tileTypes = require "necro.game.tile.TileTypes"

local trapSystem = require "AP.scripts.traps.trapSystem"

-- Every valid non-immutable floor tile ID, built once per run.
local floorPool = nil

local function getFloorPool()
    if floorPool then return floorPool end

    floorPool = {}
    for id = 1, tileTypes.getMaximumTileID() do
        local info = tileTypes.getTileInfo(id)
        if info and info.isFloor and not info.immutable then
            floorPool[#floorPool + 1] = id
        end
    end

    return floorPool
end

trapSystem.define({
    name    = "ChaosTrap",
    flyaway = "Chaos!",
    voice   = "voiceConfused",
    floor   = {
        setTile = function(x, y, ctx)
            tile.set(x, y, rng.choice(getFloorPool(), ctx.channel))
        end,
    },
})
