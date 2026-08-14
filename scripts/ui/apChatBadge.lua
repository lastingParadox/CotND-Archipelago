local chatBadge = require "necro.client.ChatBadge"
local chat      = require "necro.client.Chat"
local color     = require "system.utils.Color"

local AP_BADGE = chatBadge.Type.extend("ARCHIPELAGO", {
    data = {
        icons = {
            "mods/AP/gfx/icons/badge-ap-16.png",
            "mods/AP/gfx/icons/badge-ap-32.png",
            "mods/AP/gfx/icons/badge-ap-48.png",
            "mods/AP/gfx/icons/badge-ap-64.png",
        },
        color = color.rgb(49, 107, 132),
    }
})

local AP_SENTINEL = "_apBadge"

event.chatMessage.override("displayChatMessage", 0, function(orig, ev)
    orig(ev)
    if not ev.AP_SENTINEL then return end

    -- A message emitted during a turn carries a turnID, and Chat replaces the
    -- matching entry in place rather than pushing it onto the front, so the new
    -- message is not necessarily history[1].
    local history = chat.getMessageHistory()
    for i = 1, math.min(#history, 16) do
        local message = history[i]
        if message.text == ev.text and message.turnID == ev.turnID then
            message.badge = AP_BADGE
            return
        end
    end
end)

event.chatMessage.override("playChatNotificationSound", 0, function(orig, ev)
    if ev.AP_SENTINEL then return end
    orig(ev)
end)

local function addMessage(text)
    local msg = {
        name = "",
        text = text,
        AP_SENTINEL = AP_SENTINEL,
    }
    chat.addMessage(msg)
end

return {
    sentinel   = AP_SENTINEL,
    addMessage = addMessage,
}
