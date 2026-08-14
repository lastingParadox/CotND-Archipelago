local collision    = require("necro.game.tile.Collision")
local currentLevel = require("necro.game.level.CurrentLevel")
local rng          = require("necro.game.system.RNG")
local tile         = require("necro.game.tile.Tile")
local turn         = require("necro.cycles.Turn")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local ENCASE_RADIUS   = 1    -- solid wall ring at this Chebyshev distance
local SCATTER_RADIUS  = 5    -- random splatter out to this distance
local SCATTER_CHANCE  = 0.45

local function placeDirt(x, y)
    local info = tile.getInfo(x, y)
    if info.isFloor and not info.immutable and not collision.check(x, y, collision.Type.PLAYER) then
        tile.setType(x, y, "DirtWall")
    end
end

TrapHandler.register("EarthTrap", makeSimpleTrap({
    flyawayText = "Earth Trap!",
    sound  = "spellEarth",
    setup  = function()
        return { channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID()) }
    end,
    action = function(entity, ctx)
        local px = entity.position.x
        local py = entity.position.y
        for dx = -SCATTER_RADIUS, SCATTER_RADIUS do
            for dy = -SCATTER_RADIUS, SCATTER_RADIUS do
                local dist = math.max(math.abs(dx), math.abs(dy))
                if dist == ENCASE_RADIUS then
                    placeDirt(px + dx, py + dy)
                elseif dist > ENCASE_RADIUS and rng.roll(SCATTER_CHANCE, ctx.channel) then
                    placeDirt(px + dx, py + dy)
                end
            end
        end
    end,
}))
