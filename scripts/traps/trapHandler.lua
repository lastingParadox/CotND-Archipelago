local currentLevel = require "necro.game.level.CurrentLevel"
local gameState = require "necro.client.GameState"
local player = require "necro.game.character.Player"
local rng = require "necro.game.system.RNG"
local snapshot = require "necro.game.system.Snapshot"
local turn = require "necro.cycles.Turn"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apEventSync = require("AP.scripts.client.apEventSync")
local apLog = require("AP.scripts.utils.log").apLog
local apUtils = require("AP.scripts.utils.apUtils")

-- Rollback-managed: otherwise the removal outlives the effects it caused.
apTrapQueue = snapshot.variable({}, true) -- { { ticket = 4, name = "MonkeyTrap", args = { ... } }, ... }

-- Rewound with the queue, so a replayed turn re-issues the ticket it issued the first time.
apTrapTicket = snapshot.variable(0)

-- The turn each kind of trap last landed on, so a second of a kind waits for the next beat.
apTrapLastTurn = snapshot.variable({}, true)

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

-- True from the moment any player takes the stairs until they arrive on the next floor.
local function isAnyoneDescending()
    for _, entity in ipairs(player.getPlayerEntities()) do
        if entity.descent and entity.descent.active then return true end
    end

    return false
end

local function landedThisTurn(name)
    return apTrapLastTurn[name] == turn.getCurrentTurnID()
end

-- Runs the effect, and records the turn if it landed.
local function land(name, effect, ev, args, ticket)
    if not effect(ev, args, ticket) then return false end

    apTrapLastTurn[name] = turn.getCurrentTurnID()
    return true
end

-- Identifies one trap for as long as it is owed.
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

---Delivers one trap, publishing it or running it inline depending on where it came from.
---@param name string
---@param args table|nil Forwarded to the effect, e.g. a forced variant.
---@param opts table|nil `{ ev = <turn event>, host = true }`; `host` publishes to every client.
function TrapHandler.fire(name, args, opts)
    opts = opts or {}

    if opts.host then
        apEventSync.publish("trap", { name = name, args = args })
        return
    end

    local effect = TrapHandler.traps[name]
    local ticket = nextTicket()

    -- Only inside a turn; anything arriving on a tick waits for the next one.
    if opts.ev and effect and apUtils.isAPContext() and not isAnyoneDescending()
        and not landedThisTurn(name) and land(name, effect, opts.ev, args, ticket) then
        visualUpdate.trigger()
        return
    end

    TrapHandler.queueTrap(name, args, ticket)
end

-- Runs the effect now if the run can take it, else queues it for the first turn that can.
---@param ev table|nil The turn event, when the delivery arrived inside one.
function TrapHandler.deliver(name, args, ev)
    return TrapHandler.fire(name, args, { ev = ev })
end

-- The draw a trap should make, seeded on the ticket as well as the level seed and turn.
function TrapHandler.channel(ticket)
    return rng.makeChannel(currentLevel.getSeed(), turn.getCurrentTurnID(), ticket or 0)
end

-- Who a trap landing this instant should hit, in the turn event's `{ entity, action }` shape.
function TrapHandler.actingEntries(ev)
    -- An empty queue is a turn nobody acted on, so fall back to every player entity.
    if ev and ev.actionQueue and #ev.actionQueue > 0 then return ev.actionQueue end

    local entries = {}
    for _, entity in ipairs(player.getPlayerEntities()) do
        entries[#entries + 1] = { entity = entity }
    end

    return entries
end

-- Host-only, for a trap that reaches one machine outside the simulation: TrapLink.
function TrapHandler.publishTrap(name, args)
    return TrapHandler.fire(name, args, { host = true })
end

function TrapHandler.clearTraps()
    for key in pairs(apTrapQueue) do
        apTrapQueue[key] = nil
    end
end

-- Master turn event
event.turn.add("TrapHandlerRunner", { order = "playerActions", sequence = -1 }, function(ev)
    if gameState.isInLobby() or not apUtils.isAPContext() or isAnyoneDescending() then return end

    for i = #apTrapQueue, 1, -1 do
        local entry = apTrapQueue[i]
        -- Queue entries persist across script reloads; tolerate the old string form.
        if type(entry) == "string" then entry = { name = entry } end
        local trapFn = TrapHandler.traps[entry.name]

        if not trapFn then
            table.remove(apTrapQueue, i)
        elseif not landedThisTurn(entry.name) and land(entry.name, trapFn, ev, entry.args, entry.ticket) then
            apLog("Handling ".. entry.name .. " trap!")
            table.remove(apTrapQueue, i)
        end
    end
end
)

return TrapHandler
