local turn = require "necro.cycles.Turn"

-- Deliberately not snapshot-managed, so a replayed turn can recognise work it already did.
local applied = {}

local apReplay = {}

local function entryFor(key)
    local turnID = turn.getActiveTurnID()
    return turnID and (turnID .. "\0" .. tostring(key)) or nil
end

---True the first time `key` is seen this turn, false on every replay of it.
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

---True if `key` was already marked this turn.
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
