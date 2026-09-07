local marker = require "necro.game.tile.Marker"
local move   = require "necro.game.system.Move"

local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name    = "HomeTrap",
    flyaway = "Going home...",
    start   = function(ctx)
        local x, y = marker.lookUpFirst(marker.Type.SPAWN)
        ctx.state.x = x or 0
        ctx.state.y = y or 0
    end,
    apply   = function(ctx)
        move.absolute(ctx.entity, ctx.state.x, ctx.state.y)
    end,
})
