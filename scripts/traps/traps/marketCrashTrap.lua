local currentLevel = require "necro.game.level.CurrentLevel"
local ecs          = require "system.game.Entities"
local object       = require "necro.game.object.Object"
local tile         = require "necro.game.tile.Tile"

local apLog      = require("AP.scripts.utils.log").apLog
local trapSystem = require "AP.scripts.traps.trapSystem"

local function closeShops()
    local saleItems = {}
    local skipped = 0

    for item in ecs.entitiesWithComponents({ "sale" }) do
        if item.AP_locationItem and item.AP_locationItem.slot ~= 0 then
            -- AP shop slots are location checks, not stock. Leave them alone.
        elseif item.position and item.sale.priceTag ~= 0 and not (item.item and item.item.equipped) then
            saleItems[#saleItems + 1] = item
        else
            skipped = skipped + 1
        end
    end

    for _, item in ipairs(saleItems) do
        local x, y = item.position.x, item.position.y
        local priceTag = ecs.getEntityByID(item.sale.priceTag)
        if priceTag then object.delete(priceTag) end
        object.delete(item)
        tile.setType(x, y, "OutOfStockFloor")
    end

    -- The shopkeeper stays: prices depend on their proximity.
    apLog(("Market Crash closed %d item(s), left %d unpriced sale entit(ies)")
        :format(#saleItems, skipped))

    return #saleItems > 0
end

-- Every floor after the crash opens closed too, until the run ends.
event.gameStateLevel.add("APMarketCrashTrap", { order = "splitScreen", sequence = 1 }, function()
    if currentLevel.isLobby() then return end
    if trapSystem.isActive("MarketCrashTrap") then closeShops() end
end)

trapSystem.define({
    name     = "MarketCrashTrap",
    flyaway  = "Market Crash!",
    scope    = trapSystem.Scope.RUN,
    stateful = true,
    start    = function()
        closeShops()
        return true
    end,
})
