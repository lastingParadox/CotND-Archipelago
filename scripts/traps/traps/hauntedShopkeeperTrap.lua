local collision = require "necro.game.tile.Collision"
local marker    = require "necro.game.tile.Marker"
local object    = require "necro.game.object.Object"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

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

TrapHandler.register("HauntedShopkeeperTrap", makeSimpleTrap({
    flyawayText = "Haunted Shopkeeper!",
    setup = function()
        -- Anchor on the level exit stairs. Use the STAIRS marker, which is
        -- present whether or not a miniboss still locks the exit (LockedStairs
        -- inherits it from Stairs) — unlike transformOnMinibossDeath, which only
        -- exists while a boss/miniboss holds the exit. The ring walk in
        -- findSpawnPosition spreads multiple ghosts out from the anchor.
        local x, y = marker.lookUpFirst(marker.Type.STAIRS)
        if not x then return false end
        return { anchorX = x, anchorY = y, used = {} }
    end,
    action = function(entity, ctx)
        local x, y = findSpawnPosition(ctx.anchorX, ctx.anchorY, ctx.used)
        if not x then return false end
        object.spawn("ShopkeeperGhost", x, y)
    end,
}))
