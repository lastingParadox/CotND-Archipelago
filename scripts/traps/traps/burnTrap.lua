local tile = require("necro.game.tile.Tile")

local trapSystem = require("AP.scripts.traps.trapSystem")

local BURN_TURNS = 12

trapSystem.define({
    name      = "BurnTrap",
    flyaway   = "Burn!",
    sound     = "dragonFire",
    perPlayer = true,
    duration  = BURN_TURNS,
    scope     = trapSystem.Scope.RUN,
    tickOrder = "traps",
    tick      = function(ctx)
        tile.setType(ctx.entity.position.x, ctx.entity.position.y, "HotCoals")
    end,
})
