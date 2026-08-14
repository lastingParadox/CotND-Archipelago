local collision = require "necro.game.tile.Collision"
local customEntities = require "necro.game.data.CustomEntities"
local damage = require("necro.game.system.Damage")
local ecs = require("system.game.Entities")
local health = require("necro.game.character.Health")
local object = require("necro.game.object.Object")
local player = require "necro.game.character.Player"
local soulLink = require "necro.game.character.SoulLink"

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local TrapHandler = require("AP.scripts.traps.trapHandler")

customEntities.register({
    name = "SoulLinkSlime",
    item = {},
    soulLinkFocus = {},  -- default flags = focus.Flag.CAMERA
})

customEntities.extend({
    name = "APSlime",
    template = customEntities.template.enemy("slime", 1),
    components = {
        inventory = {},
        equipment = {},
        soulLinkable = {},
        focusable = {},
        editorHidden = {},
    },
})

local slimeEntities = {}
slimeEntities = script.persist(function()
    return slimeEntities
end)

local function slimePlayerTrap(ev)
    local trapSuccess = false

    for _, entity in ipairs(player.getPlayerEntities()) do
        if not (entity and entity.playableCharacter) then goto continue end

        local playerEntity = entity

        -- Preferred spawn: two tiles to the right
        local x = playerEntity.position.x + 2
        local y = playerEntity.position.y

        -- Check if preferred tile is blocked or is stairs
        if collision.check(x, y, collision.Group.SOLID) or collision.check(x, y, collision.Type.EXIT) then
            local tiles = collision.getVacantTiles(
                playerEntity,
                0,
                100,
                2,
                false,
                collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP, collision.Type.EXIT)
            )

            if #tiles > 0 then
                x, y = tiles[1][1], tiles[1][2]
            else
                goto continue
            end
        end

        local link = soulLink.create("AP_SoulLinkSlime")
        local slime = object.spawn("AP_APSlime", x, y)
        if not slime or not link then goto continue end

        soulLink.attach(link, playerEntity)
        soulLink.attach(link, slime)

        slimeEntities[slime.id] = true

        -- Deal 2 damage (1 heart) to the player, capped so it cannot kill
        local dmg = math.min(2, math.max(0, health.getCurrentHealth(playerEntity) - 1))
        if dmg > 0 then
            damage.inflict({
                victim = playerEntity,
                damage = dmg,
                type = damage.Type.PHYSICAL,
            })
        end

        apFlyaways.addToFlyawayQueue({
            entity = playerEntity,
            text = "Gooey!",
        })

        trapSuccess = true
        ::continue::
    end

    return trapSuccess
end

event.objectTakeDamage.add("APSlimeTrapInvincible", {
    order = "invincibility",
    sequence = 1,
}, function(ev)
    if ev.victim and slimeEntities[ev.victim.id] then
        ev.damage = 0
        ev.suppressed = true
    end
end)

event.gameStateLevel.add("APSlimeTrapDespawn", { order = "splitScreen" }, function(ev)
    for id, _ in pairs(slimeEntities) do
        local entity = ecs.getEntityByID(id)
        if entity then
            object.delete(entity)
        end
    end
    slimeEntities = {}
end)

TrapHandler.register("SlimePlayerTrap", slimePlayerTrap)

return slimePlayerTrap
