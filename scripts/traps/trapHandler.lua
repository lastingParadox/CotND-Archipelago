local gameState = require "necro.client.GameState"
local gameSession = require "necro.client.GameSession"
local snapshot = require "necro.game.system.Snapshot"

local apLog = require("AP.scripts.utils.log").apLog
local apUtils = require("AP.scripts.utils.apUtils")

-- Rollback-managed: otherwise the removal outlives the effects it caused.
apTrapQueue = snapshot.variable({}, true) -- { { name = "MonkeyTrap", args = { ... } }, ... }

local TrapHandler = {
    traps = {}, -- [string] = trapFunction(ev, args)
}
TrapHandler = script.persist(function()
    return TrapHandler
end)

-- Called by each trap file during `require`
function TrapHandler.register(name, fn)
    TrapHandler.traps[name] = fn
end

-- Called by outside code to schedule a trap by name, with optional
-- handler-specific args (e.g. { variant = "Beetle" } for SummonTrap)
function TrapHandler.queueTrap(name, args)
    table.insert(apTrapQueue, { name = name, args = args })
end

function TrapHandler.clearTraps()
    for key in pairs(apTrapQueue) do
        apTrapQueue[key] = nil
    end
end

-- Master turn event
event.turn.add("TrapHandlerRunner", { order = "playerActions", sequence = -1 }, function(ev)
    if gameState.isInLobby() or not apUtils.isAPContext() then return end
    if not ev.actionQueue or #ev.actionQueue == 0 then return end

    for i = #apTrapQueue, 1, -1 do
        local entry = apTrapQueue[i]
        -- Queue entries persist across script reloads; tolerate the old string form.
        if type(entry) == "string" then entry = { name = entry } end
        local trapFn = TrapHandler.traps[entry.name]

        if trapFn and trapFn(ev, entry.args) then
            apLog("Handling ".. entry.name .. " trap!")
            table.remove(apTrapQueue, i)
        elseif not trapFn then
            table.remove(apTrapQueue, i)
        end
    end
end
)

return TrapHandler
