local collision = require("necro.game.tile.Collision")
local rng       = require("necro.game.system.RNG")
local tile      = require("necro.game.tile.Tile")

local trapSystem = require("AP.scripts.traps.trapSystem")

local ENCASE_RADIUS   = 1    -- solid wall ring at this Chebyshev distance
local SCATTER_RADIUS  = 5    -- random splatter out to this distance
local SCATTER_CHANCE  = 0.45

local function placeDirt(x, y)
    local info = tile.getInfo(x, y)
    if info.isFloor and not info.immutable and not collision.check(x, y, collision.Type.PLAYER) then
        tile.setType(x, y, "DirtWall")
    end
end

trapSystem.define({
    name    = "EarthTrap",
    flyaway = "Earth Trap!",
    sound   = "spellEarth",
    apply   = function(ctx)
        local px = ctx.entity.position.x
        local py = ctx.entity.position.y

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
})
