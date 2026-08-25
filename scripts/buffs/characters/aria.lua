local inventory = require("necro.game.item.Inventory")
local object = require("necro.game.object.Object")
local player = require("necro.game.character.Player")

local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local aria = {}

local POTION_TYPE = "AP_StackablePotion"
local VANILLA_POTION = "MiscPotion"
local STARTING_CHARGES = 3

local function isAriaBuff()
    if not apUtils.isAPContext() then return false end
    if not progression.getCharacterBuff("Aria") then return false end
    local characters = player.getSelectedPlayerCharacters()
    for _, charType in pairs(characters) do
        if charType == "Aria" then return true end
    end
    return false
end

function aria.apply(entity)
    if not entity then return end
    for _, item in ipairs(inventory.getItems(entity)) do
        if item.name == VANILLA_POTION then
            object.delete(item)
        end
    end
    local item = inventory.grant(POTION_TYPE, entity)
    if item and item.itemStack then
        item.itemStack.quantity = STARTING_CHARGES
    end
end

event.objectSpawn.add("apAriaReplacePotion", {
    filter = "item",
    order = "convert",
}, function(ev)
    if ev.entity.name ~= VANILLA_POTION then return end
    if not isAriaBuff() then return end
    object.convertImmediately(ev.entity, POTION_TYPE)
end)

function aria.revoke(entity) end

return aria
