local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local worldLabel = require("necro.game.system.WorldLabel")

local lobbyUtils = require("AP.scripts.utils.lobbyUtils")
local progression = require("AP.scripts.client.progression")

customEntities.register({
    name = "AP_ZonesStairLabel",
    position = {},
    AP_zonesStairLabel = {}
})

local AP_ZONES_KEY = "mod.AP.lobby.stair.zones"
-- Vanilla's own label. With every zone unlocked the run is an All Zones run in all
-- but the mode id, which stays APAllZones because the whole AP pipeline keys off it.
local ALL_ZONES_KEY = "label.lobby.stair.allZones"

local function currentKey()
    local lastZone = progression.isDLCEnabled("Amplified") and 5 or 4
    return progression.allZonesUnlocked(lastZone) and ALL_ZONES_KEY or AP_ZONES_KEY
end

local function refreshLabels()
    for entity in ecs.entitiesWithComponents({ "AP_zonesStairLabel" }) do
        local label = ecs.getEntityByID(entity.AP_zonesStairLabel.label)
        if label and label.worldLabelTextPool then
            local key = currentKey()
            if label.worldLabelTextPool.key ~= key then
                label.worldLabelTextPool.key = key
                worldLabel.update(label)
            end
        end
    end
end

event.objectSpawn.add("apSpawnZonesStairLabel", { filter = "AP_zonesStairLabel", order = "items" }, function(ev)
    ev.entity.AP_zonesStairLabel.label = lobbyUtils.addLabel(ev.x, ev.y, AP_ZONES_KEY)
    refreshLabels()
end)

event.apConnect.add("apZonesStairLabelUpdate", { order = "connected", sequence = 1 }, function(ev)
    if ev.status ~= "Connected" then return end
    refreshLabels()
end)

event.updateVisuals.add("apZonesStairLabelRefresh", { order = "worldLabel" }, function()
    refreshLabels()
end)
