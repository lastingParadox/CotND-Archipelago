local inventory = require("necro.game.item.Inventory")
local move = require("necro.game.system.Move")

local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local dorian = {}

local stepCounters = {}
local suppressNextCurse = {}

local function isDorianBuff()
    if not apUtils.isAPContext() then return false end
    if not progression.getCharacterBuff("Dorian") then return false end
    return true
end

event.holderMove.add("apDorianBuffStep", {
    filter = "itemToggleable",
    order = "autoDig",
}, function(ev)
    if ev.entity.name ~= "FeetBootsLeaping" then return end
    if ev.entity.itemToggleable.active then return end
    if not move.Flag.check(ev.moveType, move.Flag.CONTINUOUS) then return end
    if not ev.holder or not ev.holder.takeDamageOnUntoggledMovement then return end
    if not isDorianBuff() then return end

    local id = ev.holder.id
    stepCounters[id] = (stepCounters[id] or 0) + 1
    if stepCounters[id] % 2 == 0 then
        suppressNextCurse[id] = true
    end
end)

event.objectTakeDamage.add("apDorianFreeStep", {
    filter = "takeDamageOnUntoggledMovement",
    order = "immunity",
}, function(ev)
    if ev.killerName ~= "Dorian's Curse" then return end
    if not isDorianBuff() then return end
    local id = ev.entity.id
    if suppressNextCurse[id] then
        suppressNextCurse[id] = false
        ev.suppressed = true
        ev.damage = 0
    end
end)

event.itemActivate.add("apDorianBuffReset", {
    filter = "itemToggleable",
    order = "holster",
}, function(ev)
    if ev.item.name ~= "FeetBootsLeaping" then return end
    if not ev.item.itemToggleable.active then return end
    if not ev.holder then return end
    if not isDorianBuff() then return end
    local id = ev.holder.id
    stepCounters[id] = nil
    suppressNextCurse[id] = nil
end)

function dorian.apply(entity)
    if not entity then return end
    inventory.replace("WeaponSpear", entity)
end

function dorian.revoke(entity) end

return dorian
