local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")

handlers.register("Handshake", function(message, ctx)
    local seed = message.seed or ""
    local playerName = message.playerName or ""
    local slot = message.slot or 0
    ctx.seed = seed
    ctx.playerName = playerName

    -- A changed seed/player/slot starts a fresh session; a reconnect keeps the persisted one.
    if apStorage.seedName ~= seed
        or apStorage.playerName ~= playerName
        or apStorage.slot ~= slot then
        apLog("New session for player " .. playerName .. " (seed: " .. seed .. "). Initialising.")
        apStorage.initSession(seed, playerName, slot)
    else
        apLog("Reconnecting for player " .. playerName .. " (seed: " .. seed .. ").")
    end

    -- Items the mod has already processed this session, 0 on a fresh start.
    local lastApIndex = 0
    local receivedItems = (apStorage.saveData or {}).receivedItems or {}
    for k, _ in pairs(receivedItems) do
        local idx = tonumber(k)
        if idx and idx + 1 > lastApIndex then
            lastApIndex = idx + 1
        end
    end

    -- Always requests full state, since there is no local save file to start from.
    ctx.sendPacket({
        datatype = "State",
        init = true,
        last_ap_index = lastApIndex,
    })
end)
