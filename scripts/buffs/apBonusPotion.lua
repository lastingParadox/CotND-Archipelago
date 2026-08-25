local currentLevel = require "necro.game.level.CurrentLevel"
local focus = require "necro.game.character.Focus"
local inventory = require "necro.game.item.Inventory"
local itemPickup = require "necro.game.item.ItemPickup"
local object = require "necro.game.object.Object"
local player = require "necro.game.character.Player"
local sound = require "necro.audio.Sound"

local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local apBonusPotion = {}

local STACKABLE_POTION = "AP_StackablePotion"

-- Mirrors AP_StackablePotion's itemStackLimitQuantity.
local MAX_POTIONS = 3

local function heldPotion(entity)
    for _, item in ipairs(inventory.getItems(entity)) do
        if item.itemTagPotion then return item end
    end
end

-- Brings the player up to `count` potions, leaving a bigger stack (a character buff's) alone.
local function grantPotions(entity, count)
    if not entity or count <= 0 then return end

    local held = heldPotion(entity)

    -- A single potion stays the vanilla one; a stack has to carry its own count.
    if held and held.name ~= STACKABLE_POTION then
        if count <= 1 then return end
        object.delete(held)
        held = nil
    end

    if held then
        if held.itemStack then
            held.itemStack.quantity = math.max(held.itemStack.quantity, count)
        end
        return
    end

    local item = inventory.grant(STACKABLE_POTION, entity)
    if item and item.itemStack then
        item.itemStack.quantity = count
    end
end

-- Called at the end of applyStarterInventory, so the lobby shows what a run would start with.
function apBonusPotion.apply(entity)
    grantPotions(entity, progression.getPotionMode())
end

-- One potion on top of whatever is held, for the Spare Potion filler. grantPotions writes
-- the quantity straight onto the stack, so nothing else enforces AP_StackablePotion's limit.
function apBonusPotion.addPotion(entity)
    if not entity then return end

    local held = heldPotion(entity)
    local count = held and (held.itemStack and held.itemStack.quantity or 1) or 0

    grantPotions(entity, math.min(count + 1, MAX_POTIONS))
end

event.levelLoad.add("apGrantBonusPotion", { order = "extraEntities" }, function()
    if not apUtils.isAPContext() then return end
    if currentLevel.getSequentialNumber() ~= 1 then return end

    local count = progression.getPotionMode()
    if count <= 0 then return end

    for _, entity in ipairs(player.getPlayerEntities()) do
        if entity.playableCharacter then
            grantPotions(entity, count)
        end
    end
end)

-- Extra potions are temporary, so a held potion blocks collecting another whatever carries it.
event.holderTryCollectItem.add("apBlockExtraPotions", {
    filter = "itemTagPotion",
    order = "blockDuplicates",
    sequence = 1,
}, function(ev)
    if ev.result ~= itemPickup.Result.SUCCESS then return end
    if not ev.item.itemTagPotion then return end
    if not apUtils.isAPContext(ev.holder) then return end

    ev.result = itemPickup.Result.NONE

    if ev.item.itemPickupSound and focus.check(ev.holder, focus.Flag.SOUND_PLAYBACK) then
        sound.playFromEntity(ev.item.itemPickupSound.sound, ev.holder, { deduplicationID = ev.holder.id })
    end
end)

return apBonusPotion
