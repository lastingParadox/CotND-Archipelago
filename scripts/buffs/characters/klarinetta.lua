local apUtils    = require "AP.scripts.utils.apUtils"
local itemBan    = require "necro.game.item.ItemBan"
local itemPickup = require "necro.game.item.ItemPickup"
local progression = require "AP.scripts.client.progression"

local klarinetta = {}

local ZWEIHANDER_UNBAN = itemBan.Flag.unmask(
    itemBan.Flag.mask(itemBan.Type.FULL, itemBan.Type.LOCK),
    itemBan.Flag.LOSS_SCATTER
)

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
                if not hasBuff then return false end

                local slot = item.itemSlot and item.itemSlot.name
                if args.slot and slot ~= args.slot then return false end
                if args.bannedSlots and args.bannedSlots[slot or ""] then return false end

                return not (args.transmutedItem and item.name == args.transmutedItem.name)
            end
        end
        return baseFilter and baseFilter(item, args, player) or false
    end
end)


event.itemBanCheck.add("apKlarinettaBuffZweihanderUnban", {
    order    = "unbanComponent",
    sequence = 1,
}, function(ev)
    if ev.holder.name ~= "Sync_Klarinetta" then return end
    if not ev.item.Sync_weaponCollisionCheck then return end
    ev.mask = itemBan.Flag.unmask(ev.mask, ZWEIHANDER_UNBAN)
end)

event.objectTryCollectItem.add("apKlarinettaBuffPickupCheck", {
    order    = "itemBans",
    sequence = 1,
}, function(ev)
    if not apUtils.isAPContext() then return end
    if ev.entity.name ~= "Sync_Klarinetta" then return end
    if ev.result == itemPickup.Result.NONE then return end

    if not ev.item.AP_klarinettaWeaponScroll then return end

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
