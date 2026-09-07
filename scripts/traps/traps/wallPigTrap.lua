local object    = require "necro.game.object.Object"
local rng       = require "necro.game.system.RNG"
local tile      = require "necro.game.tile.Tile"
local tileTypes = require "necro.game.tile.TileTypes"

local trapSystem = require "AP.scripts.traps.trapSystem"

local INFEST_CHANCE = 0.10
local MINIMUM_PIGS  = 5
local PIG_WALL      = "CatacombWall"

---Every mutable, non-doorway wall with floor to its left or right for the pig to breathe down.
local function candidateWalls()
    local walls = {}
    local levelX, levelY, levelW, levelH = tile.getLevelBounds()

    for y = levelY, levelY + levelH - 1 do
        for x = levelX, levelX + levelW - 1 do
            local info = tile.getInfo(x, y)

            if info.isWall and not info.immutable and not info.isDoor then
                local floorLeft = tile.getInfo(x - 1, y).isFloor
                local floorRight = tile.getInfo(x + 1, y).isFloor

                if floorLeft or floorRight then
                    -- The pig faces the open side, the way level generation places them.
                    walls[#walls + 1] = { x = x, y = y, facesLeft = floorLeft }
                end
            end
        end
    end

    return walls
end

---A flat chance per wall, then topped up to a floor so a cramped level still bites.
local function chooseWalls(walls, channel)
    local chosen = {}
    local skipped = {}

    for _, wall in ipairs(walls) do
        if rng.roll(INFEST_CHANCE, channel) then
            chosen[#chosen + 1] = wall
        else
            skipped[#skipped + 1] = wall
        end
    end

    skipped = rng.shuffle(skipped, channel)

    for i = 1, #skipped do
        if #chosen >= MINIMUM_PIGS then break end
        chosen[#chosen + 1] = skipped[i]
    end

    return chosen
end

trapSystem.define({
    name    = "WallPigTrap",
    flyaway = "Wall Pig Trap!",
    sound   = "spellFireball",
    -- The infestation is the whole trap, so it counts as landed on its own.
    start   = function(ctx)
        local walls = candidateWalls()
        if #walls == 0 then return false end

        for _, wall in ipairs(chooseWalls(walls, ctx.channel)) do
            -- Catacomb stone under every pig, so none sits in a diggable dirt wall.
            local zoneID = tile.getInfo(wall.x, wall.y).zoneID
            local wallID = tileTypes.lookUpTileID(PIG_WALL, zoneID)
                or tileTypes.lookUpTileID(PIG_WALL, 0)

            if wallID then tile.set(wall.x, wall.y, wallID) end

            object.spawn(wall.facesLeft and "FirepigLeft" or "FirepigRight", wall.x, wall.y)
        end

        return true
    end,
})
