local action    = require "necro.game.system.Action"
local inventory = require "necro.game.item.Inventory"
local rng       = require "necro.game.system.RNG"

local apFlyaways        = require "AP.scripts.ui.apFlyaways"
local makeBeatStateTrap = (require "AP.scripts.traps.factories.makeBeatStateTrap").makeBeatStateTrap
local TrapHandler       = require "AP.scripts.traps.trapHandler"

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

TrapHandler.register("MyTurnTrap", makeBeatStateTrap({
    name        = "MyTurnTrap",
    flyawayText = "My Turn!",
    statusText  = "My Turn!",

    initState = function(entity, channel)
        return { beatsRemaining = rng.range(MY_TURN_BEATS_MIN, MY_TURN_BEATS_MAX, channel) }
    end,

    onTick = function(entity, entityState, stateTable, ev, channel)
        local chosenAction = rng.choice(buildActions(entity, channel), channel)
        local found = false
        for _, entry in ipairs(ev.actionQueue) do
            if entry.entity and entry.entity.id == entity.id then
                entry.action = chosenAction
                found = true
                break
            end
        end
        if not found then
            ev.actionQueue[#ev.actionQueue + 1] = { entity = entity, action = chosenAction }
        end

        entityState.beatsRemaining = entityState.beatsRemaining - 1
        if entityState.beatsRemaining <= 0 then
            stateTable[entity.id] = nil
            apFlyaways.addToFlyawayQueue({ entity = entity, text = "Your turn!" })
        end
    end,
}))
