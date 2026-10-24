local ecs    = require "system.game.Entities"

local apTest = require("AP.scripts.test.apTest")

-- apItemGeneration mirrors each vanilla pool by prefixing its component name.
local AP_PREFIX = "AP_"

local PAWNBROKER_PRICED_ITEMS = {
    "Sync_SpellCharm",
    "Sync_WeaponLantern",
    "FeetBootsLunging",
}

local function vanillaPoolComponents()
    local pools = {}

    for _, name in ipairs(ecs.listComponentNames()) do
        if name:match("^itemPool") then pools[#pools + 1] = name end
    end

    return pools
end

apTest.define({
    name = "everyVanillaItemPoolHasAnAPMirror",
    run = function(t)
        local pools = vanillaPoolComponents()
        t.ok(pools[1], "no vanilla itemPool components found")

        for _, name in ipairs(pools) do
            t.ok(ecs.isValidComponent(AP_PREFIX .. name),
                ("%s has no %s%s, so AP items never enter that pool")
                    :format(name, AP_PREFIX, name))
        end
    end,
})

apTest.define({
    name = "itemPoolWeightsAreNumeric",
    run = function(t)
        for _, name in ipairs(vanillaPoolComponents()) do
            local apName = AP_PREFIX .. name

            if ecs.isValidComponent(apName) then
                for _, proto in ecs.prototypesWithComponents({ apName }) do
                    local weights = proto[apName].weights

                    if t.eq(type(weights), "table",
                        ("%s on %s has no weights table"):format(apName, proto.name)) then
                        t.ok(weights[1] ~= nil,
                            ("%s on %s has an empty weights table"):format(apName, proto.name))

                        for tier, weight in ipairs(weights) do
                            t.ok(type(weight) == "number" and weight >= 0,
                                ("%s on %s has a bad weight at tier %d: %s")
                                    :format(apName, proto.name, tier, tostring(weight)))
                        end
                    end
                end
            end
        end
    end,
})

apTest.define({
    name = "itemPoolMembersAreItems",
    run = function(t)
        for _, name in ipairs(vanillaPoolComponents()) do
            local apName = AP_PREFIX .. name

            if ecs.isValidComponent(apName) then
                for _, proto in ecs.prototypesWithComponents({ apName }) do
                    t.ok(proto.item,
                        ("%s is in the %s pool but is not an item"):format(proto.name, apName))
                end
            end
        end
    end,
})

apTest.define({
    name = "pawnbrokerItemsCarryTheirPricing",
    run = function(t)
        for _, name in ipairs(PAWNBROKER_PRICED_ITEMS) do
            t.hasComponent(name, "AP_pawnbrokerPricing")
        end
    end,
})
