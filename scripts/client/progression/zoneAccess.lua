local apStorage = require("AP.scripts.client.storage")

local function attach(progression)
    function progression.getZoneAccessKeys()
        return apStorage.saveData.zoneAccessKeys or 0
    end

    function progression.getStartingZone()
        return apStorage.saveData.startingZone or 1
    end

    -- Separate mode: mark zone N as accessible.
    function progression.addZoneAccess(zone)
        local access = apStorage.saveData.zoneAccess
        if not access then
            apStorage.saveData.zoneAccess = {}
            access = apStorage.saveData.zoneAccess
        end
        access[tostring(zone)] = true
    end

    -- Separate mode: check if zone N's key has been received.
    function progression.hasZoneAccess(zone)
        local access = apStorage.saveData.zoneAccess or {}
        return access[tostring(zone)] == true
    end

    -- Every copy counts, precollected included, so zone 1 is the base rather than
    -- the starting zone. Python's zone_access push uses the same accounting.
    function progression.addProgressiveZoneAccess()
        local access = apStorage.saveData.zoneAccess
        if not access then
            apStorage.saveData.zoneAccess = {}
            access = apStorage.saveData.zoneAccess
        end
        access.progressiveCount = (access.progressiveCount or 0) + 1
    end

    -- Progressive mode: number of "Progressive Zone Access" copies held.
    function progression.getProgressiveZoneAccessCount()
        local access = apStorage.saveData.zoneAccess or {}
        return access.progressiveCount or 0
    end

    -- Returns true when every zone up to lastZone is accessible.
    function progression.allZonesUnlocked(lastZone)
        if progression.getZoneAccessKeys() == 1 then
            for zone = 1, lastZone do
                if not progression.hasZoneAccess(zone) then
                    return false
                end
            end

            return true
        end

        return progression.getProgressiveZoneAccessCount() >= lastZone - 1
    end
end

return { attach = attach }
