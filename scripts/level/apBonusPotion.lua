local currentLevel = require "necro.game.level.CurrentLevel"
local inventory = require "necro.game.item.Inventory"
local player = require "necro.game.character.Player"

local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local POTION = "MiscPotion"
local STACKABLE_POTION = "AP_StackablePotion"

local MODE_EACH_RUN = 1
local MODE_EACH_ZONE = 2

local function grantPotion(entity)
    for _, item in ipairs(inventory.getItems(entity)) do
        if item.name == STACKABLE_POTION then
            local stack = item.itemStack
            local limit = item.itemStackLimitQuantity and item.itemStackLimitQuantity.limit or 1
            if stack and stack.quantity < limit then
                stack.quantity = stack.quantity + 1
            end
            return
        elseif item.name == POTION then
            return
        end
    end

    -- apAriaReplacePotion converts this to the stackable one for buffed Aria.
    inventory.grant(POTION, entity)
end

event.levelLoad.add("apGrantBonusPotion", { order = "extraEntities" }, function()
    if not apUtils.isAPContext() then return end

    local mode = progression.getPotionMode()
    if mode == 0 then return end
    if mode == MODE_EACH_RUN and currentLevel.getSequentialNumber() ~= 1 then return end
    if mode == MODE_EACH_ZONE and currentLevel.getFloor() ~= 1 then return end

    for _, entity in ipairs(player.getPlayerEntities()) do
        if entity.playableCharacter then
            grantPotion(entity)
        end
    end
end)
