local gameState = require "necro.client.GameState"
local gameSession = require "necro.client.GameSession"
local player = require "necro.game.character.Player"
local snapshot = require "necro.game.system.Snapshot"

local apEventSync = require("AP.scripts.client.apEventSync")
local apLog = require("AP.scripts.utils.log").apLog
local apUtils = require("AP.scripts.utils.apUtils")

-- Rollback-managed: otherwise the removal outlives the effects it caused.
apTrapQueue = snapshot.variable({}, true) -- { { ticket = 4, name = "MonkeyTrap", args = { ... } }, ... }

-- Rewound with the queue, so a replayed turn re-issues the ticket it issued the first time.
apTrapTicket = snapshot.variable(0)

local TrapHandler = {
    traps = {},
}
TrapHandler = script.persist(function()
    return TrapHandler
end)

-- Called by each trap file during `require`
function TrapHandler.register(name, fn)
    TrapHandler.traps[name] = fn
end

-- Identifies one trap for as long as it is owed. A trap that has to sit out a turn is the
-- same trap next turn, and two of a kind arriving together are not each other
local function nextTicket()
    apTrapTicket = apTrapTicket + 1
    return apTrapTicket
end

function TrapHandler.queueTrap(name, args, ticket)
    table.insert(apTrapQueue, { name = name, args = args, ticket = ticket or nextTicket() })
end

apEventSync.subscribe("trap", function(data)
    TrapHandler.queueTrap(data.name, data.args)
end)

-- Runs the effect now if the run can take it, or leaves it queued for the first turn that
-- can
---@param ev table|nil The turn event, when the delivery arrived inside one.
function TrapHandler.deliver(name, args, ev)
    local effect = TrapHandler.traps[name]
    local ticket = nextTicket()

    if effect and apUtils.isAPContext() and effect(ev, args, ticket) then return end

    TrapHandler.queueTrap(name, args, ticket)
end

-- Who a trap landing this instant should hit, in the turn event's own `{ entity, action }`
-- shape.
function TrapHandler.actingEntries(ev)
    if ev and ev.actionQueue then return ev.actionQueue end

    local entries = {}
    for _, entity in ipairs(player.getPlayerEntities()) do
        entries[#entries + 1] = { entity = entity }
    end

    return entries
end

-- Host-only, for a trap that reaches one machine outside the simulation: TrapLink.
function TrapHandler.publishTrap(name, args)
    apEventSync.publish("trap", { name = name, args = args })
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

        if trapFn and trapFn(ev, entry.args, entry.ticket) then
            apLog("Handling ".. entry.name .. " trap!")
            table.remove(apTrapQueue, i)
        elseif not trapFn then
            table.remove(apTrapQueue, i)
        end
    end
end
)

return TrapHandler
