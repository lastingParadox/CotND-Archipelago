local apUtils    = require "AP.scripts.utils.apUtils"
local itemPickup = require "necro.game.item.ItemPickup"
local progression = require "AP.scripts.client.progression"

local klarinetta = {}

event.itemGenerate.add("apKlarinettaBuffZweihanderPool", {
    order    = "initPool",
    sequence = -1,
}, function(ev)
    if not apUtils.isAPContext() then return end
    local hasBuff = progression.getCharacterBuff("Klarinetta")
    local baseFilter = ev.filter
    ev.filter = function(item, args, player)
        if player and player.name == "Sync_Klarinetta" then
            local isZweihander = item.Sync_weaponCollisionCheck ~= nil
            local isScroll = item.AP_klarinettaWeaponScroll ~= nil
            if isZweihander or isScroll then
                return hasBuff and true or false
            end
        end
        return baseFilter and baseFilter(item, args, player) or false
    end
end)

-- getBanFlags caches per (holder, item) at level-gen time before progression data
-- is available, so a buff check here would always evaluate false and stick.
event.itemBanCheck.add("apKlarinettaBuffZweihanderUnban", {
    order    = "unbanComponent",
    sequence = 1,
}, function(ev)
    if ev.holder.name ~= "Sync_Klarinetta" then return end
    if not ev.item.Sync_weaponCollisionCheck then return end
    ev.mask = 0
end)

event.objectTryCollectItem.add("apKlarinettaBuffPickupCheck", {
    order    = "itemBans",
    sequence = 1,
}, function(ev)
    if not apUtils.isAPContext() then return end
    if ev.entity.name ~= "Sync_Klarinetta" then return end
    if ev.result == itemPickup.Result.NONE then return end

    local isZweihander = ev.item.Sync_weaponCollisionCheck ~= nil
    local isScroll = ev.item.AP_klarinettaWeaponScroll ~= nil

    if not (isZweihander or isScroll) then return end

    if not progression.getCharacterBuff("Klarinetta") then
        ev.result = itemPickup.Result.NONE
        ev.silent = true
    end
end)

function klarinetta.apply()
end

function klarinetta.revoke()
end

return klarinetta
