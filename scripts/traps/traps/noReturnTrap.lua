local extraMode = require "necro.game.data.modifier.ExtraMode"
local inventory = require "necro.game.item.Inventory"
local object    = require "necro.game.object.Object"

local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name      = "NoReturnTrap",
    flyaway   = function()
        return extraMode.isActive(extraMode.Type.NO_RETURN)
            and "No Return Trap Negated!"
            or  "Don't look back!"
    end,
    perPlayer = true,
    -- The instance outlives the trigger so the granted square can be taken back next floor.
    stateful  = true,
    apply     = function(ctx)
        local entity = ctx.entity

        for _, item in ipairs(inventory.getItems(entity)) do
            if item.name == "NoReturnModeSquare" then return false end
        end

        if extraMode.isActive(extraMode.Type.NO_RETURN) then return end

        ctx.state.item = inventory.grant(entity.extraModeNoReturnInnateItem.type, entity)
    end,
    expire    = function(ctx)
        if ctx.state.item then object.delete(ctx.state.item) end
    end,
})
