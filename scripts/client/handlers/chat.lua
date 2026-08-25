local chat = require "necro.client.Chat"

local apLog       = require("AP.scripts.utils.log").apLog
local apStorage   = require("AP.scripts.client.storage")
local handlers    = require("AP.scripts.client.initHandlers")
local AP_SENTINEL = require("AP.scripts.ui.apChatBadge").sentinel

handlers.register("Chat", function(message, ctx)
    if message.slot ~= nil and message.slot == apStorage.slot then
        return
    end

    apLog("Received chat message from " .. tostring(message.player) .. ": " .. message.msg)

    if message.player and message.player ~= "Archipelago" and message.player ~= "Server" then
        chat.addMessage({
            name  = message.player,
            text  = message.msg,
            sound = chat.Sound.MESSAGE_LOCAL,
        })
    else
        -- AP Badge override
        local msg = {
            name = "",
            text  = message.msg,
            sound = chat.Sound.MESSAGE_REMOTE,
            AP_SENTINEL = AP_SENTINEL
        }
        chat.addMessage(msg)
    end
end)
