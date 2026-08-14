local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local eli = {}

local function isEliBuff()
    if not apUtils.isAPContext() then return false end
    if not progression.getCharacterBuff("Eli") then return false end
    return true
end

event.weaponAttack.add("apEliBuffKnockback", {
    order = "spell",
}, function(ev)
    if ev.weapon.name ~= "WeaponEli" then return end
    if not isEliBuff() then return end
    for _, target in ipairs(ev.result.targets) do
        target.knockback = (target.knockback or 0) + 1
        if target.victim.stun then
            target.victim.stun.counter = target.victim.stun.counter + 1
        end
    end
end)

function eli.apply(entity) end

function eli.revoke(entity) end

return eli
