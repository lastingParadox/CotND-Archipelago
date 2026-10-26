local action         = require "necro.game.system.Action"
local currentLevel   = require "necro.game.level.CurrentLevel"
local ecs            = require "system.game.Entities"
local inventory      = require "necro.game.item.Inventory"
local itemBan        = require "necro.game.item.ItemBan"
local itemGeneration = require "necro.game.item.ItemGeneration"
local itemSlot       = require "necro.game.item.ItemSlot"
local object         = require "necro.game.object.Object"
local player         = require "necro.game.character.Player"
local playerList     = require "necro.client.PlayerList"

local possession = require "Sync.character.chaunter.Possession"

local apStorage   = require("AP.scripts.client.storage")
local apTest      = require("AP.scripts.test.apTest")
local progression = require("AP.scripts.client.progression")
local TrapHandler = require("AP.scripts.traps.trapHandler")
local trapSystem  = require("AP.scripts.traps.trapSystem")

local TRAP_MARV = "AP_TrapMarv"

local function fireTrap(name)
    return TrapHandler.traps[name](nil, nil, 1)
end

local function possessedBodies()
    local bodies = {}
    for entity in ecs.entitiesWithComponents({ "Sync_possessable" }) do
        if entity.Sync_possessable.possessor ~= 0 and not entity.gameObject.despawned then
            bodies[#bodies + 1] = entity
        end
    end

    return bodies
end

apTest.define({
    name = "trapMarvIsAWalkingHarmlessLamb",
    run = function(t)
        if not t.entityType(TRAP_MARV) then return end

        for _, component in ipairs({ "Sync_possessable", "character", "movable", "Sync_possessableTimer" }) do
            t.hasComponent(TRAP_MARV, component)
        end

        for _, component in ipairs({ "innateAttack", "hoverEffectAlwaysEnabled", "dropCurrencyOnDeath", "parityAnimation" }) do
            t.ok(not ecs.typeHasComponent(TRAP_MARV, component),
                ("%s still carries %s from its slime base"):format(TRAP_MARV, component))
        end

        local body, marv = ecs.getEntityPrototype(TRAP_MARV), ecs.getEntityPrototype("Marv")
        t.eq(body.sprite.texture, marv.sprite.texture, "the trap body does not wear Marv's sprite")
        t.ok(body.Sync_possessableTimer.remainingBeats > 0, "the trap body has no possession time")
        t.banned(TRAP_MARV, "WeaponDagger", itemBan.Flag.PICKUP)

        t.ok(not ecs.typeHasComponent("Marv", "Sync_possessable"), "Mary's own Marv became possessable")
    end,
})

apTest.define({
    name = "animalTrapPossessesThePlayer",
    world = true,
    run = function(t)
        local original = t.player()
        if not t.ne(original, nil, "no player entity on the test floor") then return end

        t.ok(fireTrap("AnimalTrap"), "the Animal Trap did not land")

        local body = t.player()
        t.ne(body.id, original.id, "the player is not controlling an animal")
        t.ok(not body.gameObject.despawned, "the player controls a deleted animal")
        t.eq(body.Sync_possessable and body.Sync_possessable.possessor, original.id,
            "the animal is not possessed by the player's character")
        t.ok(trapSystem.isActive("AnimalTrap", original), "the trap is not tracked on the player's character")
        t.eq(#possessedBodies(), 1, "more than one creature is possessed")
    end,
})

apTest.define({
    name = "animalTrapWaitsForThePossessionToEnd",
    world = true,
    run = function(t)
        local original = t.player()
        if not t.ok(fireTrap("AnimalTrap"), "the first Animal Trap did not land") then return end

        local first = t.player()
        t.eq(fireTrap("AnimalTrap"), false, "a second Animal Trap landed during the possession")
        t.eq(t.player().id, first.id, "the second trap replaced the first animal")
        t.eq(#possessedBodies(), 1, "two creatures are possessed at once")

        possession.detach(original, first)
        t.ok(not trapSystem.isActive("AnimalTrap", original), "ending the possession did not end the trap")
        t.eq(t.player().id, original.id, "control did not return to the player's character")

        t.ok(fireTrap("AnimalTrap"), "the queued Animal Trap still cannot land after the possession")
        t.eq(#possessedBodies(), 1, "the follow-up trap left more than one creature possessed")
    end,
})

apTest.define({
    name = "trapMarvHopsButCannotHurtEnemies",
    world = true,
    run = function(t)
        local original = t.player()
        local x, y = original.position.x, original.position.y

        local marv = object.spawn(TRAP_MARV, x, y)
        if not t.ok(possession.attach(original, marv), "the Marv body could not be possessed") then return end
        t.eq(t.player().id, marv.id, "the player is not controlling the Marv body")

        t.act(action.Direction.RIGHT)
        t.eq(marv.position.x, x + 1, "the Marv body did not move right")

        local slime = object.spawn("Slime", x + 2, y)
        local health = slime.health.health
        t.act(action.Direction.RIGHT)

        t.ok(not slime.gameObject.despawned, "the Marv body killed an enemy")
        t.eq(slime.health.health, health, "the Marv body damaged an enemy")
        t.eq(marv.position.x, x + 1, "the Marv body walked through an enemy")
        t.ne(inventory.getItemInSlot(original, itemSlot.Type.WEAPON), nil,
            "the player's weapon left their character")
    end,
})

apTest.define({
    name = "transmuteTrapKeepsBuffedKlarinettasSlots",
    world = true,
    character = "Sync_Klarinetta",
    run = function(t)
        local contents = {}
        for key, value in pairs(apStorage.saveData) do contents[key] = value end
        contents.buffs = { characterBuffs = { Klarinetta = true } }

        apTest.withSaveData(contents, function()
            local entity = t.player()

            for _, itemType in ipairs({ "RingCourage", "HeadMinersCap", "FeetBootsLunging", "Torch1" }) do
                if t.entityType(itemType) then inventory.grant(itemType, entity) end
            end

            local slots = {}
            for _, item in ipairs(inventory.getItems(entity)) do
                slots[item.id] = item.itemSlot and item.itemSlot.name or ""
            end

            t.ok(fireTrap("TransmuteTrap"), "the Transmute Trap did not land")

            local held = {}
            for _, item in ipairs(inventory.getItems(entity)) do held[item.id] = item end

            for id, slot in pairs(slots) do
                local item = held[id]
                if t.ok(item, ("an item from the %s slot was lost"):format(slot)) then
                    t.eq(item.itemSlot and item.itemSlot.name or "", slot,
                        ("%s moved out of the %s slot"):format(item.name, slot))
                end
            end
        end)
    end,
})

local function chestWeight(proto, tier)
    local best = 0
    for _, pool in ipairs({ "itemPoolChest", "AP_itemPoolChest" }) do
        local weights = proto[pool] and proto[pool].weights
        if weights then best = math.max(best, weights[tier] or weights[#weights] or 0) end
    end

    return best
end

local function rejection(entity, proto)
    if not progression.getItems(proto.name) then return "notReceived" end
    if progression.getBannedItems(proto.name) then return "janitorBanned" end
    if itemBan.isBanned(entity, proto.name, itemBan.Flag.GENERATE_ITEM_POOL) then return "characterBanned" end

    return "eligible"
end

apTest.define({
    name = "transmuteTrapTargetsOnThisFloor",
    level = true,
    run = function(t)
        local entity = player.getPlayerEntity(playerList.getLocalPlayerID())
        if not t.ne(entity, nil, "no local player entity") then return end

        local tier = currentLevel.getFloor() + (currentLevel.getDepth() > 1 and 1 or 0) + 1

        for _, item in ipairs(inventory.getItems(entity)) do
            local slot = item.itemSlot and item.itemSlot.name

            if not item.itemTransmutable or item.itemExcludeFromTransmute then
                t.note(("%s is skipped: not transmutable"):format(item.name))
            elseif slot ~= "bomb" then
                local rolled = itemGeneration.choice({
                    levelBonus     = 1,
                    player         = entity,
                    itemPool       = itemGeneration.Pool.CHEST,
                    transmutedItem = item,
                    slot           = slot,
                    seenCounts     = {},
                })

                local counts, eligible = { notReceived = 0, janitorBanned = 0, characterBanned = 0, eligible = 0 }, {}
                for _, proto in ecs.prototypesWithComponents({ "item" }) do
                    if proto.itemSlot and proto.itemSlot.name == slot and proto.name ~= item.name
                        and chestWeight(proto, tier) > 0 then
                        local reason = rejection(entity, proto)
                        counts[reason] = counts[reason] + 1
                        if reason == "eligible" and #eligible < 5 then eligible[#eligible + 1] = proto.name end
                    end
                end

                local summary = ("%s (%s, tier %d) rolled %s: %d not received, %d janitor-banned, %d banned for %s, %d eligible [%s]")
                    :format(item.name, tostring(slot), tier, tostring(rolled), counts.notReceived, counts.janitorBanned,
                        counts.characterBanned, entity.name, counts.eligible, table.concat(eligible, ", "))
                t.note(summary)
                t.ok(rolled, summary)
            end
        end
    end,
})
