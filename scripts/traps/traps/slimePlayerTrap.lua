local collision      = require "necro.game.tile.Collision"
local customEntities = require "necro.game.data.CustomEntities"
local damage         = require "necro.game.system.Damage"
local ecs            = require "system.game.Entities"
local health         = require "necro.game.character.Health"
local object         = require "necro.game.object.Object"
local soulLink       = require "necro.game.character.SoulLink"

local trapSystem = require "AP.scripts.traps.trapSystem"

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

-- The slime itself takes no damage; its whole job is to be dragged around.
event.objectTakeDamage.add("APSlimeTrapInvincible", {
    order = "invincibility",
    sequence = 1,
}, function(ev)
    if not ev.victim then return end

    local isTrapSlime = trapSystem.eachState("SlimePlayerTrap", function(state)
        return state.slime == ev.victim.id
    end)

    if isTrapSlime then
        ev.damage = 0
        ev.suppressed = true
    end
end)

trapSystem.define({
    name      = "SlimePlayerTrap",
    flyaway   = "Gooey!",
    perPlayer = true,
    stateful  = true,
    apply     = function(ctx)
        local playerEntity = ctx.entity

        -- Preferred spawn: two tiles to the right.
        local x = playerEntity.position.x + 2
        local y = playerEntity.position.y

        if collision.check(x, y, collision.Group.SOLID) or collision.check(x, y, collision.Type.EXIT) then
            local tiles = collision.getVacantTiles(
                playerEntity, 0, 100, 2, false,
                collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP, collision.Type.EXIT)
            )
            if #tiles == 0 then return false end

            x, y = tiles[1][1], tiles[1][2]
        end

        local link  = soulLink.create("AP_SoulLinkSlime")
        local slime = object.spawn("AP_APSlime", x, y)
        if not (slime and link) then return false end

        soulLink.attach(link, playerEntity)
        soulLink.attach(link, slime)

        ctx.state.slime = slime.id

        -- Two damage (one heart), capped so it cannot kill.
        local dmg = math.min(2, math.max(0, health.getCurrentHealth(playerEntity) - 1))
        if dmg > 0 then
            damage.inflict({
                victim = playerEntity,
                damage = dmg,
                type   = damage.Type.PHYSICAL,
            })
        end
    end,
    expire    = function(ctx)
        local slime = ctx.state.slime and ecs.getEntityByID(ctx.state.slime)
        if slime then object.delete(slime) end
    end,
})
