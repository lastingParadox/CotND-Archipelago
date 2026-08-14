local jsonOrig = require("system.utils.serial.JSON")

local json = {}

setmetatable(json, {
    __index = function(_, k) return jsonOrig[k] end,
    __call  = function(_, ...) return jsonOrig(...) end
})

-- Attach a pretty encoder without touching the original source file
function json.encode_pretty(value, indent, level)
    indent  = indent or "  "
    level   = level or 0
    local t = type(value)

    if t == "table" then
        local isArray = true
        for k in pairs(value) do
            if type(k) ~= "number" then
                isArray = false
                break
            end
        end

        local pieces = {}
        local nextLevel = level + 1
        local pad = string.rep(indent, nextLevel)

        if isArray then
            for _, v in ipairs(value) do
                table.insert(pieces, "\n" .. pad .. json.encode_pretty(v, indent, nextLevel))
            end
            return "[" .. table.concat(pieces, ",") .. "\n" .. string.rep(indent, level) .. "]"
        else
            for k, v in pairs(value) do
                local key = string.format("%q", k)
                table.insert(pieces,
                    "\n" .. pad .. key .. ": " .. json.encode_pretty(v, indent, nextLevel))
            end
            return "{" .. table.concat(pieces, ",") .. "\n" .. string.rep(indent, level) .. "}"
        end
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    else
        return "null"
    end
end

return json
