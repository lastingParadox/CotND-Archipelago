local levelSequence = require("necro.game.level.LevelSequence")

local apStorage = require("AP.scripts.client.storage")

local function attach(progression)
    -- The zone list a run will use, with zone 5 gated on the slot's Amplified setting.
    function progression.getZoneList()
        local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4
        local zones = {}

        for _, zone in ipairs(levelSequence.getDefaultZoneList()) do
            if zone <= lastZone then
                zones[#zones + 1] = zone
            end
        end

        return zones
    end

    ---Zones an AP Zones run may visit, in play order.
    ---@param zoneList table|nil Defaults to the full list; pass the sequence's own if reordered.
    function progression.getAccessibleZones(zoneList)
        zoneList = zoneList or progression.getZoneList()

        local mode = progression.getZoneAccessKeys()
        if mode == "disabled" then return zoneList end

        local startingZone = progression.getStartingZone()
        local accessible = {}

        if mode == "progressive" then
            local unlocked = 1 + progression.getProgressiveZoneAccessCount()

            for i = 1, math.min(unlocked, #zoneList) do
                accessible[#accessible + 1] = zoneList[i]
            end
        else
            for _, zone in ipairs(zoneList) do
                if zone == startingZone or progression.hasZoneAccess(zone) then
                    accessible[#accessible + 1] = zone
                end
            end
        end

        return accessible
    end

    -- "disabled", "separate", or "progressive".
    function progression.getZoneAccessKeys()
        return apStorage.saveData.zoneAccessKeys or "disabled"
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

    function progression.getProgressiveZoneAccessCount()
        local access = apStorage.saveData.zoneAccess or {}
        return access.progressiveCount or 0
    end

    -- Returns true when every zone up to lastZone is accessible.
    function progression.allZonesUnlocked(lastZone)
        if progression.getZoneAccessKeys() == "separate" then
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
