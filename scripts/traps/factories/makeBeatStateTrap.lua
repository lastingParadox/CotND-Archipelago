local currentLevel   = require "necro.game.level.CurrentLevel"
local ecs            = require "system.game.Entities"
local player         = require "necro.game.character.Player"
local rng            = require "necro.game.system.RNG"
local turn           = require "necro.cycles.Turn"

local apTrapStatus   = require "AP.scripts.ui.apTrapStatus"
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap

---Creates a beat-driven per-player state trap and returns its trigger function.
---
---Manages a persistent, per-player state table (keyed by entity ID).  The trigger
---function adds a state entry for each player; every beat, `opts.onTick` is called
---for all players that have an entry so they can advance their effect and, when
---finished, remove themselves via `stateTable[entity.id] = nil`.
---
---Because `script.persist` is called inside this function, the factory must be
---called at module top-level (i.e. not inside another function).
---
---@param opts table
---  Required:
---    name         string    Unique identifier used as the event name suffix.
---    flyawayText  string    Shown to each player on trigger.
---    onTick       function(entity, entityState, stateTable, ev, channel)
---                           Called every beat for each player that has state.
---                           `entityState` = stateTable[entity.id].
---                           `stateTable`  = the full state table (mutate to remove).
---                           `ev`          = the turn event (has ev.actionQueue).
---                           `channel`     = RNG channel for this beat.
---  Optional:
---    statusText   string    Persistent above-player indicator shown while the
---                           entity has an active state entry.
---    initState    function(entity, channel) -> table|false
---                           Called once per player on trigger to build their initial
---                           state.  Return false to skip that player.
---                           Defaults to returning an empty table `{}`.
---    guard        function(entity) -> bool
---                           Extra per-entity guard (beyond "not already in state").
---    onLevelClear function(entity, entityState)
---                           Called per active entity when the level changes.
---                           Run before the state table is cleared.
---    sound        string    Played per entity at their position on trigger.
---    voice        string    Played per entity via voice.tryPlay on trigger.
---@return function trapFn  Pass to TrapHandler.register.
local function makeBeatStateTrap(opts)
    assert(type(opts.name)        == "string",   "makeBeatStateTrap: opts.name is required")
    assert(type(opts.flyawayText) == "string",   "makeBeatStateTrap: opts.flyawayText is required")
    assert(type(opts.onTick)      == "function", "makeBeatStateTrap: opts.onTick is required")

    local state = {}
    state = script.persist(function() return state end)

    if opts.statusText then
        apTrapStatus.register(opts.name, function(entity)
            return state[entity.id] and opts.statusText or nil
        end)
    end

    -- Beat-driven tick: run onTick for every player with an active state entry.
    event.turn.add("AP" .. opts.name .. "Tick", {
        order    = "playerActions",
        sequence = -2,
    }, function(ev)
        if not ev.actionQueue then return end
        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end
            local entityState = state[entity.id]
            if not entityState then goto continue end
            opts.onTick(entity, entityState, state, ev, channel)
            ::continue::
        end
    end)

    -- Floor transition: optional per-entity cleanup, then wipe the state table.
    event.gameStateLevel.add("AP" .. opts.name .. "Clear", { order = "splitScreen" }, function()
        if opts.onLevelClear then
            for id, s in pairs(state) do
                local entity = ecs.getEntityByID(id)
                if entity then opts.onLevelClear(entity, s) end
            end
        end
        state = {}
    end)

    -- Trigger: standard per-player loop via makeSimpleTrap.
    return makeSimpleTrap({
        flyawayText = opts.flyawayText,
        sound       = opts.sound,
        voice       = opts.voice,
        guard = function(entity)
            return not state[entity.id] and (not opts.guard or opts.guard(entity))
        end,
        action = function(entity)
            local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
            local s = opts.initState and opts.initState(entity, channel) or {}
            if s == false then return false end
            state[entity.id] = s
        end,
    })
end

return { makeBeatStateTrap = makeBeatStateTrap }
