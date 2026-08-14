local currency = require "necro.game.item.Currency"
local player = require "necro.game.character.Player"

local apFlags = require("AP.scripts.utils.flags")
local handlers = require("AP.scripts.client.initHandlers")
local progression = require("AP.scripts.client.progression")

handlers.register("SetDiamonds", function(message)
    local value = message.value
    if type(value) ~= "number" then return end
    local amount = math.floor(value)
    progression.setDiamonds(amount)
    -- Update the shared pool (used by gameStateReset / in-game affordability).
    currency.setShared(apFlags.CURRENCY_AP_DIAMOND, amount)
    -- Update per-entity currency (used in the AP lobby).
    for _, entity in ipairs(player.getPlayerEntities()) do
        currency.set(entity, apFlags.CURRENCY_AP_DIAMOND, amount)
    end
end)
