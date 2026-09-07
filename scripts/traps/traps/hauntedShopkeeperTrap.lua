local collision = require "necro.game.tile.Collision"
local marker    = require "necro.game.tile.Marker"
local object    = require "necro.game.object.Object"

local trapSystem = require "AP.scripts.traps.trapSystem"

local function positionKey(x, y)
    return tostring(x) .. "," .. tostring(y)
end

local function findSpawnPosition(anchorX, anchorY, usedPositions)
    local collisionMask = collision.mask(collision.Group.SOLID, collision.Type.OBJECT, collision.Type.TRAP)
    for radius = 0, 6 do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.max(math.abs(dx), math.abs(dy)) == radius then
                    local x = anchorX + dx
                    local y = anchorY + dy
                    local key = positionKey(x, y)
                    if not usedPositions[key] and not collision.check(x, y, collisionMask) then
                        usedPositions[key] = true
                        return x, y
                    end
                end
            end
        end
    end
    return nil, nil
end

trapSystem.define({
    name    = "HauntedShopkeeperTrap",
    flyaway = "Haunted Shopkeeper!",
    -- Anchors on the STAIRS marker, which is present whether or not a miniboss locks the exit.
    start   = function(ctx)
        local x, y = marker.lookUpFirst(marker.Type.STAIRS)
        if not x then return false end

        ctx.state.anchorX = x
        ctx.state.anchorY = y
        ctx.state.used    = {}
    end,
    apply   = function(ctx)
        local x, y = findSpawnPosition(ctx.state.anchorX, ctx.state.anchorY, ctx.state.used)
        if not x then return false end

        object.spawn("ShopkeeperGhost", x, y)
    end,
})
