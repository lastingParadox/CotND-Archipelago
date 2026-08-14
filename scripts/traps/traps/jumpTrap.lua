local action    = require "necro.game.system.Action"
local character = require "necro.game.character.Character"

local apFlyaways        = require "AP.scripts.ui.apFlyaways"
local makeBeatStateTrap = (require "AP.scripts.traps.factories.makeBeatStateTrap").makeBeatStateTrap
local TrapHandler       = require "AP.scripts.traps.trapHandler"

local JUMP_BEATS = 10

TrapHandler.register("JumpTrap", makeBeatStateTrap({
    name        = "JumpTrap",
    flyawayText = "Jump Trap!",

    initState = function(entity, channel)
        return { beatsRemaining = JUMP_BEATS }
    end,

    onTick = function(entity, entityState, stateTable, ev, channel)
        local found = false
        for _, entry in ipairs(ev.actionQueue) do
            if entry.entity and entry.entity.id == entity.id then
                entry.action = action.Special.IDLE
                found = true
                break
            end
        end
        if not found then
            ev.actionQueue[#ev.actionQueue + 1] = { entity = entity, action = action.Special.IDLE }
        end

        character.hopInPlace(entity)

        entityState.beatsRemaining = entityState.beatsRemaining - 1
        if entityState.beatsRemaining <= 0 then
            stateTable[entity.id] = nil
        end
    end,
}))
