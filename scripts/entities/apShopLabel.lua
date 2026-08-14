local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local worldLabel = require("necro.game.system.WorldLabel")

local lobbyUtils = require("AP.scripts.utils.lobbyUtils")
local progression = require("AP.scripts.client.progression")

customEntities.register({
    name = "AP_ShopLabel",
    position = {},
    AP_shopLabel = {}
})

local STATE_KEYS = {
    stocked = "mod.AP.lobby.shopHint",
    gated   = "mod.AP.lobby.shopRestockHint",
    empty   = "mod.AP.lobby.shopSoldOutHint",
}

local function refreshLabels()
    for entity in ecs.entitiesWithComponents({ "AP_shopLabel" }) do
        local label = ecs.getEntityByID(entity.AP_shopLabel.label)
        if label and label.worldLabelTextPool then
            local key = STATE_KEYS[progression.getShopState(entity.AP_shopLabel.npc)]
            if key and label.worldLabelTextPool.key ~= key then
                label.worldLabelTextPool.key = key
                worldLabel.update(label)
            end
        end
    end
end

event.objectSpawn.add("apSpawnShopLabel", { filter = "AP_shopLabel", order = "items" }, function(ev)
    ev.entity.AP_shopLabel.label = lobbyUtils.addLabel(
        ev.x, ev.y, STATE_KEYS.stocked, ev.entity.AP_shopLabel.offsetY
    )
    refreshLabels()
end)

event.apConnect.add("apShopLabelUpdate", { order = "connected", sequence = 1 }, function(ev)
    if ev.status ~= "Connected" then return end
    refreshLabels()
end)

event.updateVisuals.add("apShopLabelRefresh", { order = "worldLabel" }, function()
    refreshLabels()
end)
