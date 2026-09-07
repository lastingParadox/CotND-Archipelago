local currentLevel = require "necro.game.level.CurrentLevel"
local player = require "necro.game.character.Player"
local visualUpdate = require "necro.cycles.VisualUpdate"
local worldLabel = require "necro.game.system.WorldLabel"

local apInventory = require("AP.scripts.utils.apInventory")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

-- The carrier for the potion-capacity tiers; AP_StackablePotion is the potion they grant.
apItemFactory.define({
    name = "AP_ProgressivePotions",
    texture = "items/progressive_potion.png",
    hint = L("Progressive Potions", "AP.item.progressivePotions"),
    flyaway = L("Progressive Potions Obtained!", "AP.item.progressivePotions.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
    -- The tier is counted from the received-items log; the grant switches the new one on.
    grant = {
        item = "APProgressivePotions",
        carrier = false,
        sound = "shrineActivate",
        apply = function()
            progression.addPotionTier()

            if currentLevel.isLobby() then
                for _, playerEntity in ipairs(player.getPlayerEntities()) do
                    apInventory.applyStarterInventory(playerEntity, progression, { sanitize = true })
                end
                visualUpdate.trigger()
                worldLabel.updateAll()
            end
        end,
    },
})
