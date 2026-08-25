local apFlyaways  = require("AP.scripts.ui.apFlyaways")
local apUtils     = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local mary = {}

local hitAbsorbed = {}

event.gameStateLevel.add("apMaryBuffReset", "resetLevelVariables", function()
    hitAbsorbed = {}
end)

event.objectTakeDamage.add("apMaryBuffAbsorbHit", {
    filter = "followerDamageParentWhileDead",
    order  = "immunity",
}, function(ev)
    if ev.entity.name ~= "Marv" then return end
    if ev.damage <= 0 then return end
    local apComp = ev.entity.AP_followerDamageParentWhileDead
    if apComp and apComp.killerName and apComp.killerName ~= "" then return end
    if not apUtils.isAPContext() then return end
    if not progression.getCharacterBuff("Mary") then return end
    if hitAbsorbed[ev.entity.id] then return end
    hitAbsorbed[ev.entity.id] = true
    ev.suppressed = true
    ev.damage = 0
    apFlyaways.addToFlyawayQueue({ entity = ev.entity, text = "Resilient!" })
end)

function mary.apply(entity) end
function mary.revoke(entity) end
return mary
