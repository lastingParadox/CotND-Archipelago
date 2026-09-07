local apLog = require("AP.scripts.utils.log").apLog
local handlers = require("AP.scripts.client.initHandlers")
local trapHandler = require("AP.scripts.traps.trapHandler")

handlers.register("Trap", function(message)
    local name = message.trap_name
    if type(name) ~= "string" or name == "" then return end
    apLog("Queuing TrapLink trap: " .. name)
    trapHandler.fire(name, message.args, { host = true })
end)
