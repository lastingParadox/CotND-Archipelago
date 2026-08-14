local turn = require "necro.cycles.Turn"

-- Deliberately not snapshot-managed: outliving the rollback is what lets a
-- replayed turn recognise work it already did.
local applied = {}

local apReplay = {}

local function entryFor(key)
    local turnID = turn.getActiveTurnID()
    return turnID and (turnID .. "\0" .. tostring(key)) or nil
end

---True the first time it is called with `key` during the current turn, false for
---every replay of that turn. Always true outside a turn, where nothing replays.
function apReplay.firstThisTurn(key)
    local entry = entryFor(key)
    if not entry then return true end
    if applied[entry] then return false end

    applied[entry] = true
    return true
end

---Record `key` as done for this turn without testing it first.
function apReplay.mark(key)
    local entry = entryFor(key)
    if entry then applied[entry] = true end
end

---True if `key` was already marked during this turn, i.e. we are in a replay of
---the turn that did the work.
function apReplay.seen(key)
    local entry = entryFor(key)
    return entry ~= nil and applied[entry] == true
end

local function reset()
    applied = {}
end

event.gameStateLevel.add("apResetReplayGuards", { order = "resetLevelVariables" }, reset)
event.gameStateReset.add("apResetReplayGuards", { order = "resetRunVariables" }, reset)

return apReplay
