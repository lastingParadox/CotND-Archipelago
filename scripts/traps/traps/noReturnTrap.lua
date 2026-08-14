local extraMode = require "necro.game.data.modifier.ExtraMode"
local inventory = require("necro.game.item.Inventory")
local object    = require "necro.game.object.Object"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local noReturnTrapVictims = {}
noReturnTrapVictims = script.persist(function()
    return noReturnTrapVictims
end)

event.levelLoad.add("apClearNoReturnTrap", { order = "entities" }, function()
    for _, victim in pairs(noReturnTrapVictims) do
        object.delete(victim.item)
    end
    noReturnTrapVictims = {}
end)

TrapHandler.register("NoReturnTrap", makeSimpleTrap({
    flyawayText = function(entity)
        return extraMode.isActive(extraMode.Type.NO_RETURN)
            and "No Return Trap Negated!"
            or  "Don't look back!"
    end,
    guard = function(entity)
        for _, item in ipairs(inventory.getItems(entity)) do
            if item.name == "NoReturnModeSquare" then return false end
        end
        return true
    end,
    action = function(entity)
        if not extraMode.isActive(extraMode.Type.NO_RETURN) then
            local item = inventory.grant(entity.extraModeNoReturnInnateItem.type, entity)
            noReturnTrapVictims[#noReturnTrapVictims + 1] = { player = entity, item = item }
        end
    end,
}))
