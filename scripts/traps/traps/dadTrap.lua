local collision      = require "necro.game.tile.Collision"
local inventory      = require "necro.game.item.Inventory"
local itemBan        = require "necro.game.item.ItemBan"
local itemPickup     = require "necro.game.item.ItemPickup"
local moveAnimations = require "necro.render.level.MoveAnimations"
local object         = require "necro.game.object.Object"
local soulLink       = require "necro.game.character.SoulLink"
local sound          = require "necro.audio.Sound"

local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap
local trapSystem     = require "AP.scripts.traps.trapSystem"

local function scatterInventory(playerEntity, dadInventory)
    local x = playerEntity and playerEntity.position and playerEntity.position.x or 0
    local y = playerEntity and playerEntity.position and playerEntity.position.y or 0

    local radius = 1
    local dx     = -radius
    local dy     = -radius
    local mask   = collision.mask(collision.Group.SOLID, collision.Type.ITEM, collision.Type.TRAP)

    for _, itemName in ipairs(dadInventory) do
        while collision.check(x + dx, y + dy, mask) or math.abs(dx) + math.abs(dy) == 1 do
            dx = dx + 1
            if dy == radius then
                dx = dx + 1
                if dx > 6 then
                    dy   = 0
                    dx   = 0
                    mask = 0
                    break
                elseif radius < dx then
                    radius = dx
                    dx     = -radius
                end
                dy = -radius
            else
                dy = math.abs(dx) == radius and dy + 1 or radius
            end
        end
        local item = object.spawn(itemName, x + dx, y + dy)
        moveAnimations.play(item, moveAnimations.Type.HOP, x, y)
    end
end

-- Whatever Dad is holding when he takes something is what he drops when he leaves.
event.objectTryCollectItem.add("apDadItemCheck", { order = "pickupEffects", filter = "dad" }, function(ev)
    if ev.result ~= itemPickup.Result.SUCCESS then return end

    trapSystem.eachState("DadTrap", function(state)
        if not (state.dad and state.dad.id == ev.entity.id) then return end

        state.inventory = {}
        for _, item in ipairs(inventory.getItems(state.dad)) do
            if not itemBan.isBanned(ev.entity, item, itemBan.Flag.LOSS_SCATTER) then
                state.inventory[#state.inventory + 1] = item.name
            end
        end

        return true
    end)
end)

makeSummonTrap({
    name        = "DadTrap",
    flyawayText = "Dad trap!",
    variants    = { DorianDad = 1 },
    min         = 1,
    max         = 1,
    radius      = 3,
    spawnProps  = false,
    perPlayer   = true,
    stateful    = true,
    -- Dad leaves at the end of the floor, dropping what he carried by his player.
    expire      = function(ctx)
        local inv = ctx.state.inventory
        if ctx.state.owner and inv and #inv > 0 then
            scatterInventory(ctx.state.owner, inv)
        end
    end,
    onSpawn = function(dad, _tile, playerEntity, ctx)
        dad.dad.playerID = playerEntity.controllable.playerID

        local link = soulLink.create("SoulLinkDad")
        soulLink.attach(link, playerEntity)
        soulLink.attach(link, dad)

        ctx.state.dad       = dad
        ctx.state.owner     = playerEntity
        ctx.state.inventory = { "WeaponDaggerDad", "RingMight" }

        sound.playFromEntity("dorianHi", dad)
    end,
})
