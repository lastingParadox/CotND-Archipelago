local currentLevel = require "necro.game.level.CurrentLevel"
local ecs          = require "system.game.Entities"
local object       = require "necro.game.object.Object"
local snapshot     = require "necro.game.system.Snapshot"
local tile         = require "necro.game.tile.Tile"

local apLog          = require("AP.scripts.utils.log").apLog
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

apMarketCrashActive = snapshot.runVariable(false)

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

event.gameStateLevel.add("APMarketCrashTrap", { order = "splitScreen" }, function()
    if currentLevel.isLobby() then
        apMarketCrashActive = false
    elseif apMarketCrashActive then
        closeShops()
    end
end)

TrapHandler.register("MarketCrashTrap", makeSimpleTrap({
    flyawayText = "Market Crash!",
    setup = function()
        if apMarketCrashActive then return false end
    end,
    after = function()
        apMarketCrashActive = true
        closeShops()
    end,
}))
