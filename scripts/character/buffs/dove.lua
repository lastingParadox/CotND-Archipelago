local apUtils = require("AP.scripts.utils.apUtils")
local inventory = require("necro.game.item.Inventory")
local progression = require("AP.scripts.client.progression")

local dove = {}

local function isDoveBuff()
    if not apUtils.isAPContext() then return false end
    if not progression.getCharacterBuff("Dove") then return false end
    return true
end

event.weaponAttack.add("apDoveBuffConfusion", {
    filter = "weaponInflictConfusion",
    order = "spell",
    sequence = 1,
}, function(ev)
    if not isDoveBuff() then return end
    for _, target in ipairs(ev.result.targets) do
        local victim = target.victim
        if victim.confusable then
            victim.confusable.remainingTurns = victim.confusable.remainingTurns + 2
        end
    end
end)

function dove.apply(entity)
    if not entity then return end
    inventory.replace("MiscCompass", entity)
end

function dove.revoke(entity) end

return dove
