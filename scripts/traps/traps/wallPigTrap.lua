local currentLevel = require "necro.game.level.CurrentLevel"
local object       = require "necro.game.object.Object"
local rng          = require "necro.game.system.RNG"
local tile         = require "necro.game.tile.Tile"
local turn         = require "necro.cycles.Turn"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local INFEST_CHANCE = 0.07
local MINIMUM_PIGS  = 5

---Every wall a pig could face out of: it breathes down a row, so it needs floor to its
---left or right. Immutable walls are the level border and are left alone.
local function candidateWalls()
    local walls = {}
    local levelX, levelY, levelW, levelH = tile.getLevelBounds()

    for y = levelY, levelY + levelH - 1 do
        for x = levelX, levelX + levelW - 1 do
            local info = tile.getInfo(x, y)

            if info.isWall and not info.immutable then
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

TrapHandler.register("WallPigTrap", makeSimpleTrap({
    flyawayText   = "Wall Pig Trap!",
    sound         = "spellFireball",
    alwaysSucceed = true,
    setup         = function()
        local walls = candidateWalls()
        if #walls == 0 then return false end

        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())

        for _, wall in ipairs(chooseWalls(walls, channel)) do
            object.spawn(wall.facesLeft and "FirepigLeft" or "FirepigRight", wall.x, wall.y)
        end
    end,
}))
