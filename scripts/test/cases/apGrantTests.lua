local ecs      = require "system.game.Entities"
local utils    = require "system.utils.Utilities"

local apGrants = require("AP.scripts.items.apGrants")
local apTest   = require("AP.scripts.test.apTest")

local PLACEHOLDERS = {
    "AP_ItemFiller",
    "AP_ItemProgression",
    "AP_ItemUseful",
    "AP_ItemTrap",
}

local FILLER_ITEMS = {
    "APScrollNeed",
    "APBomb",
    "APBomb3",
    "APScrollDescend",
    "APHeartTransplant",
    "APBombGrenade",
    "APSpareCoupon",
}

apTest.define({
    name = "placeholderCarriersAreRegistered",
    run = function(t)
        for _, name in ipairs(PLACEHOLDERS) do
            t.hasComponent(name, "AP_item")
        end
    end,
})

apTest.define({
    name = "customEntitiesRegisterInNameOrder",
    run = function(t)
        local placeholders = utils.listToSet(PLACEHOLDERS)
        local seen = {}

        for _, name in ipairs(ecs.getEntityTypesWithComponents({ "AP_item" })) do
            if placeholders[name] then seen[#seen + 1] = name end
        end

        local sorted = utils.fastCopy(seen)
        table.sort(sorted)

        t.eq(table.concat(seen, ","), table.concat(sorted, ","),
            "custom entities no longer register in name order, so declaration order now matters")
    end,
})

apTest.define({
    name = "fillerItemsResolveToTheirOwnRule",
    run = function(t)
        for _, itemId in ipairs(FILLER_ITEMS) do
            local rule = apGrants.resolve(itemId)

            if t.ok(rule, ("%s resolves to no rule"):format(itemId)) then
                t.eq(rule.item, itemId, ("%s fell through to another rule"):format(itemId))
                t.eq(type(rule.apply), "function", ("%s has no apply"):format(itemId))
            end
        end
    end,
})

apTest.define({
    name = "unknownItemsFallBackToADrop",
    run = function(t)
        local rule = apGrants.resolve("APThisItemDoesNotExist")

        if t.ok(rule, "no fallback grant rule is registered") then
            t.eq(type(rule.apply), "function", "the fallback rule has no apply")
        end

        t.eq(apGrants.resolve(nil), nil)
    end,
})
