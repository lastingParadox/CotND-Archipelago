local action    = require "necro.game.system.Action"
local character = require "necro.game.character.Character"

local trapSystem = require "AP.scripts.traps.trapSystem"

local JUMP_BEATS = 10

---Forces `entity` to idle this beat, replacing whatever it queued.
local function forceIdle(ev, entity)
    for _, entry in ipairs(ev.actionQueue) do
        if entry.entity and entry.entity.id == entity.id then
            entry.action = action.Special.IDLE
            return
        end
    end

    ev.actionQueue[#ev.actionQueue + 1] = { entity = entity, action = action.Special.IDLE }
end

trapSystem.define({
    name      = "JumpTrap",
    flyaway   = "Jump Trap!",
    perPlayer = true,
    duration  = JUMP_BEATS,
    tick      = function(ctx)
        forceIdle(ctx.ev, ctx.entity)
        character.hopInPlace(ctx.entity)
    end,
})
