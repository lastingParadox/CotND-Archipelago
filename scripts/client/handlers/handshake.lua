local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")
local handlers = require("AP.scripts.client.initHandlers")

handlers.register("Handshake", function(message, ctx)
    local seed = message.seed or ""
    local playerName = message.playerName or ""
    local slot = message.slot or 0
    print("HANDSHAKE", slot)
    ctx.seed = seed
    ctx.playerName = playerName

    -- Initialise a fresh in-memory session when the seed/player/slot changes (or
    -- on the very first connection).  For within-session TCP reconnects the
    -- script.persist state is kept so that already-processed items are not
    -- re-triggered and the receivedItems dedup table remains intact.
    if apStorage.seedName ~= seed
        or apStorage.playerName ~= playerName
        or apStorage.slot ~= slot then
        apLog("New session for player " .. playerName .. " (seed: " .. seed .. "). Initialising.")
        apStorage.initSession(seed, playerName, slot)
    else
        apLog("Reconnecting for player " .. playerName .. " (seed: " .. seed .. ").")
    end

    -- Items the mod has already processed this session (0 on a fresh start).
    -- Reported so the AP client can distinguish genuinely-new traps from ones
    -- that were already in flight before a TCP drop.
    local lastApIndex = 0
    local receivedItems = (apStorage.saveData or {}).receivedItems or {}
    for k, _ in pairs(receivedItems) do
        local idx = tonumber(k)
        if idx and idx + 1 > lastApIndex then
            lastApIndex = idx + 1
        end
    end

    -- Always request full state; without a local save file the AP server is the
    -- sole source of truth, so every (re)connect starts from scratch.
    ctx.sendPacket({
        datatype = "State",
        init = true,
        last_ap_index = lastApIndex,
    })
end)
