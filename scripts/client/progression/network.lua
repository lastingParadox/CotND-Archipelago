local apLog = require("AP.scripts.utils.log").apLog
local apClient = require("AP.scripts.client.client")
local apStorage = require("AP.scripts.client.storage")

local function attach(progression)
    function progression.sendLocationChecks(locations)
        if not locations then return end

        if type(locations) ~= "table" then
            locations = { locations }
        end

        apLog("Sending " .. #locations .. " location checks")

        apClient.sendPacket({
            datatype = "Locations",
            sources = locations
        })
    end

    function progression.sendHint(hintType)
        apLog("Requesting hint")
        apClient.sendPacket({ datatype = "Hint" })
    end
end

return {
    attach = attach,
}
