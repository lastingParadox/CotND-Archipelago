local apLog = require("AP.scripts.utils.log").apLog

local handlers = {}

handlers.registry = {}

local function printTable_recursive(tbl, indent)
    indent = indent or 0
    local indentString = string.rep("  ", indent)

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            apLog(indentString .. k .. ": {", "warning")
            printTable_recursive(v, indent + 1)
            apLog(indentString .. "}", "warning")
        else
            apLog(indentString .. k .. ": " .. tostring(v), "warning")
        end
    end
end

function handlers.register(datatype, fn)
    handlers.registry[datatype] = fn
end

function handlers.dispatch(message, ctx)
    local datatype = message.datatype
    local handler = handlers.registry[datatype]

    if handler then
        apLog(message.datatype .. " message received from server.")
        handler(message, ctx)
    else
        apLog("Unhandled datatype: " .. tostring(datatype), "warning")
        printTable_recursive(message)
    end
end

return handlers
