local apUtils = require("AP.scripts.utils.apUtils")
local damage = require("necro.game.system.Damage")
local progression = require("AP.scripts.client.progression")

local monk = {}

local function isMonkBuff()
    if not apUtils.isAPContext() then return false end
    if not progression.getCharacterBuff("Monk") then return false end
    return true
end

event.objectTakeDamage.add("apMonkBuffVow", {
    filter = "itemCollectorBannedPickupDamage",
    order = "increase",
}, function(ev)
    if not isMonkBuff() then return end
    if ev.type ~= damage.Type.SUICIDE then return end
    if not ev.entity.health then return end
    ev.damage = math.floor(ev.entity.health.maxHealth / 2)
end)

function monk.apply(entity) end

function monk.revoke(entity) end

return monk
