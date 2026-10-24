local ecs    = require "system.game.Entities"

local apTest = require("AP.scripts.test.apTest")

apTest.define({
    name = "maryStillDeclaresMarvAsHerFollower",
    run = function(t)
        if not ecs.isValidEntityType("Mary") then return end

        t.hasComponent("Mary", "characterWithFollower")
        t.eq(ecs.getEntityPrototype("Mary").characterWithFollower.followerType, "Marv")
    end,
})

apTest.define({
    name = "marvCarriesTheChainWalkComponent",
    run = function(t)
        if not ecs.isValidEntityType("Marv") then return end

        -- apFollowerChain walks the chain by this component; without it clearChain no-ops.
        t.hasComponent("Marv", "AP_followerDamageParentWhileDead")
        t.hasComponent("Marv", "inventory")
    end,
})

apTest.define({
    name = "noFollowerOutlivesItsCharacter",
    level = true,
    run = function(t)
        for entity in ecs.entitiesWithComponents({ "follower", "item" }) do
            local holder = ecs.getEntityByID(entity.item.holder)

            if holder and holder.playableCharacter then
                t.ok(holder.characterWithFollower,
                    ("%s is following %s, which declares no follower of its own")
                        :format(tostring(entity.name), tostring(holder.name)))
            end
        end
    end,
})
