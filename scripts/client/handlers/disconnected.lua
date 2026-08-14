local apLog = require("AP.scripts.utils.log").apLog
local handlers = require("AP.scripts.client.initHandlers")
local trapHandler = require("AP.scripts.traps.trapHandler")
local visualUpdate = require "necro.cycles.VisualUpdate"

handlers.register("Disconnected", function(message, ctx)
    if not ctx.isConnected() then return end
    if message.reason then
        ctx.lastConnectError = message.reason
    end
    apLog("Disconnecting from Archipelago server.")

    ctx.disconnect()

    trapHandler.clearTraps()

    visualUpdate.trigger()
end)
