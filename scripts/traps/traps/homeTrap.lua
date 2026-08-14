local marker = require "necro.game.tile.Marker"
local move   = require "necro.game.system.Move"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

TrapHandler.register("HomeTrap", makeSimpleTrap({
    flyawayText = "Going home...",
    setup = function()
        local x, y = marker.lookUpFirst(marker.Type.SPAWN)
        return { spawnX = x or 0, spawnY = y or 0 }
    end,
    action = function(entity, ctx)
        move.absolute(entity, ctx.spawnX, ctx.spawnY)
    end,
}))
