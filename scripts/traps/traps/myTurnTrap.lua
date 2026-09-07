local action    = require "necro.game.system.Action"
local inventory = require "necro.game.item.Inventory"
local rng       = require "necro.game.system.RNG"

local apFlyaways = require "AP.scripts.ui.apFlyaways"
local trapSystem = require "AP.scripts.traps.trapSystem"

local MY_TURN_BEATS_MIN = 10
local MY_TURN_BEATS_MAX = 15

local BASE_DIRECTIONS = {
    action.Direction.RIGHT,
    action.Direction.UP,
    action.Direction.LEFT,
    action.Direction.DOWN,
}

local function buildActions(entity, channel)
    local actions = {}
    for _, a in ipairs(BASE_DIRECTIONS) do actions[#actions + 1] = a end
    if entity.inputContextLayerDiagonal then
        actions[#actions + 1] = action.Direction.UP_LEFT
        actions[#actions + 1] = action.Direction.UP_RIGHT
        actions[#actions + 1] = action.Direction.DOWN_LEFT
        actions[#actions + 1] = action.Direction.DOWN_RIGHT
    end
    if inventory.getItemInSlot(entity, "bomb")        then actions[#actions + 1] = action.Special.BOMB   end
    if inventory.getItemInSlot(entity, "action", 1)   then actions[#actions + 1] = action.Special.ITEM_1  end
    if inventory.getItemInSlot(entity, "action", 2)   then actions[#actions + 1] = action.Special.ITEM_2  end
    if inventory.getItemInSlot(entity, "spell",  1)   then actions[#actions + 1] = action.Special.SPELL_1 end
    if inventory.getItemInSlot(entity, "spell",  2)   then actions[#actions + 1] = action.Special.SPELL_2 end
    local weapon = inventory.getItemInSlot(entity, "weapon")
    if weapon and weapon.weaponThrowable and rng.range(1, 100, channel) == 1 then
        actions[#actions + 1] = action.Special.THROW
    end
    return actions
end

trapSystem.define({
    name      = "MyTurnTrap",
    flyaway   = "My Turn!",
    status    = "My Turn!",
    perPlayer = true,
    -- Rolled per player at trigger, so two people do not lose the same beats.
    duration  = function(ctx)
        return rng.range(MY_TURN_BEATS_MIN, MY_TURN_BEATS_MAX, ctx.channel)
    end,
    tick      = function(ctx)
        local entity       = ctx.entity
        local chosenAction = rng.choice(buildActions(entity, ctx.channel), ctx.channel)

        for _, entry in ipairs(ctx.ev.actionQueue) do
            if entry.entity and entry.entity.id == entity.id then
                entry.action = chosenAction
                return
            end
        end

        ctx.ev.actionQueue[#ctx.ev.actionQueue + 1] = { entity = entity, action = chosenAction }
    end,
    expire    = function(ctx)
        if ctx.entity then
            apFlyaways.addToFlyawayQueue({ entity = ctx.entity, text = "Your turn!" })
        end
    end,
})
