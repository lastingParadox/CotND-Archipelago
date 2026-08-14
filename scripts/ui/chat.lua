local player = require "necro.game.character.Player"
local playerList = require "necro.client.PlayerList"
local localization = require "system.i18n.Localization"
local settings = require "necro.config.Settings"
local singlePlayer = require "necro.client.SinglePlayer"

local apClient = require("AP.scripts.client.client")

apShowChat = settings.user.bool({
    id = "AP.hud.chat",
    name = "Show AP chat dynamically",
    default = true,
})

event.chatMessage.add("apSendChatMessage", "display", function(ev)
    if not apClient.isConnected() then return end
    
    -- Check if this is a local player
    local isLocalPlayer = false
    for _, playerEntity in ipairs(player.getPlayerEntities()) do
        if playerEntity and playerEntity.controllable and playerEntity.controllable.playerID == ev.playerID then
            isLocalPlayer = true
            break
        end
    end

    if isLocalPlayer then
        local text = tostring(ev.text or "")
        if text:find("${me}", 1, true) then
            text = text:gsub("%$%{me%}",
                playerList.getName(ev.playerID) or localization.get("client.playerList.fallbackPlayerName", "Player"))
        end;

        apClient.sendPacket({
            datatype = "Chat",
            msg = text,
        })
    end
end)

event.renderUI.override("renderChat", function(func, ev)
    if not apShowChat then return func(ev) end
    local wasActive = singlePlayer.isActive()
    singlePlayer.setActive(false)
    func(ev)
    singlePlayer.setActive(wasActive)
end)
