local action      = require "necro.game.system.Action"
local apUtils     = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local diamond = {}

local DIAGONAL_DIRECTIONS = {
    [action.Direction.UP_RIGHT]  = true,
    [action.Direction.UP_LEFT]   = true,
    [action.Direction.DOWN_LEFT] = true,
    [action.Direction.DOWN_RIGHT] = true,
}

-- Diagonal attacks deal +1 bonus damage.
event.objectDealDamage.add("apDiamondBuffDiagonalDamage", {
    filter = "character",
    order  = "baseIncrease",
}, function(ev)
    if ev.entity.name ~= "Diamond" then return end
    if not DIAGONAL_DIRECTIONS[ev.direction] then return end
    if not apUtils.isAPContext() then return end
    if not progression.getCharacterBuff("Diamond") then return end
    ev.damage = ev.damage + 1
end)

function diamond.apply(entity) end
function diamond.revoke(entity) end
return diamond
