local boss         = require "necro.game.level.Boss"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs          = require "system.game.Entities"
local enum         = require "system.utils.Enum"
local freezeFrame  = require "necro.render.FreezeFrame"
local gameState    = require "necro.client.GameState"
local player       = require "necro.game.character.Player"
local rng          = require "necro.game.system.RNG"
local snapshot     = require "necro.game.system.Snapshot"
local sound        = require "necro.audio.Sound"
local tile         = require "necro.game.tile.Tile"
local timer        = require "system.utils.Timer"
local voice        = require "necro.audio.Voice"

local apFlyaways   = require "AP.scripts.ui.apFlyaways"
local apTrapStatus = require "AP.scripts.ui.apTrapStatus"
local TrapHandler  = require "AP.scripts.traps.trapHandler"

local trapSystem = {}

trapSystem.Announce = enum.immutable({ EACH = 1, FIRST = 2, NONE = 3 })
trapSystem.Clock    = enum.immutable({ BEAT = 1, REAL = 2 })
trapSystem.Scope    = enum.immutable({ LEVEL = 1, RUN = 2 })
-- QUEUE waits out the first, REFRESH restarts its clock, IGNORE is spent, STACK tops it up.
trapSystem.Stacking = enum.immutable({ QUEUE = 1, REFRESH = 2, IGNORE = 3, STACK = 4 })
trapSystem.Storage  = enum.immutable({ SNAPSHOT = 1, VOLATILE = 2 })

local Announce, Clock, Scope, Stacking, Storage =
    trapSystem.Announce, trapSystem.Clock, trapSystem.Scope, trapSystem.Stacking, trapSystem.Storage

-- Simulated trap state, rewound with the turns that produced it.
apTrapState = snapshot.variable({}, true)

-- Render, window, UI and audio state, which must not rewind mid-frame.
local volatileState = {}
volatileState = script.persist(function() return volatileState end)

-- [name] = spec, with `names` as the sorted view every instance walk iterates.
local specs = {}
local names = {}

local function store(spec)
    return spec.storage == Storage.VOLATILE and volatileState or apTrapState
end

local function memberOf(enumTable, value)
    for _, entry in pairs(enumTable) do
        if entry == value then return true end
    end
    return false
end

local function checkEnum(spec, field, enumTable, label)
    local value = spec[field]
    assert(value == nil or memberOf(enumTable, value),
        ("trapSystem.define(%s): %s must come from trapSystem.%s"):format(spec.name, field, label))
end

-- A stable per-trap number standing in for a ticket, offset clear of the ticket counter.
local function channelKey(name)
    local key = 0
    for i = 1, #name do
        key = (key * 31 + name:byte(i)) % 1000000
    end

    return key + 1000000
end

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------

-- One live effect; `state` is the trap's own scratch and `duration` may be a function.
local function newInstance(spec, ctx)
    local instance = { state = {} }
    local duration = spec.duration

    if type(duration) == "function" then duration = duration(ctx) end

    if duration then
        if spec.clock == Clock.REAL then
            instance.endsAt = timer.unixTimestamp() + duration
        else
            instance.remaining = duration
        end
    end

    return instance
end

local function getInstance(spec, entity)
    local bucket = store(spec)[spec.name]
    if not bucket then return nil end
    if not spec.perPlayer then return bucket end

    return entity and bucket[entity.id] or nil
end

-- Keyed by entity id, so an instance whose player is already deleted can still be cleared.
local function setInstanceByID(spec, id, instance)
    local root = store(spec)

    if not spec.perPlayer then
        root[spec.name] = instance
        return
    end

    root[spec.name] = root[spec.name] or {}
    root[spec.name][id] = instance

    if instance == nil and next(root[spec.name]) == nil then
        root[spec.name] = nil
    end
end

local function setInstance(spec, entity, instance)
    return setInstanceByID(spec, entity and entity.id or nil, instance)
end

-- True while any instance of this trap is live, which is what Stacking reads.
local function isActive(spec, entity)
    if spec.perPlayer then return getInstance(spec, entity) ~= nil end

    return store(spec)[spec.name] ~= nil
end

---------------------------------------------------------------------------
-- Context
---------------------------------------------------------------------------

-- Everyone a trap landing this instant should reach, with the action each queued this beat.
local function actingPlayers(ev)
    local players = {}

    for _, entry in ipairs(TrapHandler.actingEntries(ev)) do
        local entity = entry.entity
        -- Whoever the player is currently driving, not just their own character.
        if player.isPlayerEntity(entity) then
            players[#players + 1] = { entity = entity, action = entry.action }
        end
    end

    return players
end

-- `players` is resolved on first use and memoised.
local contextMeta = {
    __index = function(ctx, key)
        if key ~= "players" then return nil end

        -- Plain field access, since the sandbox has no rawget/rawset.
        local value = actingPlayers(ctx.ev)
        ctx.players = value

        return value
    end,
}

local function makeContext(spec, ev, args, ticket, players)
    return setmetatable({
        spec    = spec,
        name    = spec.name,
        ev      = ev,
        args    = args,
        ticket  = ticket,
        channel = TrapHandler.channel(ticket),
        players = players,
    }, contextMeta)
end

-- Points the context at one player and their instance, reusing the same context table.
local function focus(ctx, entry, instance)
    ctx.entity    = entry and entry.entity or nil
    ctx.action    = entry and entry.action or nil
    ctx.state     = instance and instance.state or nil
    ctx.remaining = instance and instance.remaining or nil

    return ctx
end

---------------------------------------------------------------------------
-- Announcing
---------------------------------------------------------------------------

-- Reads a presentation field, letting the chosen variant override the trap's own.
local function field(spec, ctx, key)
    if ctx.variant and ctx.variant[key] ~= nil then return ctx.variant[key] end

    return spec[key]
end

local function announceTo(spec, ctx, entry)
    local entity = entry.entity

    local voiceKey = field(spec, ctx, "voice")
    local soundKey = field(spec, ctx, "sound")

    if voiceKey then voice.tryPlay(entity, voiceKey) end
    if soundKey then sound.play(soundKey, entity.position.x, entity.position.y) end

    local text = field(spec, ctx, "flyaway")
    if type(text) == "function" then text = text(ctx) end
    if text then apFlyaways.addToFlyawayQueue({ entity = entity, text = text }) end
end

---------------------------------------------------------------------------
-- Floor pass
---------------------------------------------------------------------------

-- Level bounds, minus the sealed approach corridor on a boss floor.
local function sweepBounds()
    local x, y, w, h = tile.getLevelBounds()

    if currentLevel.isBoss() then
        local borderY = boss.getTopBorderY()

        if borderY and borderY >= y then
            h = h - (borderY + 1 - y)
            y = borderY + 1
        end
    end

    return x, y, w, h
end

-- Rewrites every non-immutable floor tile, recording originals on the instance when `restore`.
local function sweepFloor(spec, ctx, instance)
    local floor = spec.floor
    local levelX, levelY, levelW, levelH = sweepBounds()
    local touched = false

    if floor.restore then instance.savedTiles = {} end

    for y = levelY, levelY + levelH - 1 do
        for x = levelX, levelX + levelW - 1 do
            local info = tile.getInfo(x, y)

            if info.isFloor and not info.immutable then
                if floor.restore then
                    local originalID = tile.get(x, y)
                    if originalID ~= 0 then
                        instance.savedTiles[#instance.savedTiles + 1] = { x = x, y = y, id = originalID }
                    end
                end

                if floor.setTile then
                    floor.setTile(x, y, ctx)
                else
                    tile.setType(x, y, floor.tileType)
                end

                touched = true
            end
        end
    end

    return touched
end

local function restoreFloor(instance)
    for _, entry in ipairs(instance.savedTiles or {}) do
        tile.set(entry.x, entry.y, entry.id)
    end

    instance.savedTiles = nil
end

-- Picks the variant, either named through args or drawn on the trap's own channel.
local function chooseVariant(spec, ctx, args)
    if not spec.variants then return end

    local name = args and args.variant
    if not (name and spec.variants[name]) then
        name = rng.choice(spec.variantPool, ctx.channel)
    end

    ctx.variantName = name
    ctx.variant     = spec.variants[name]
end

---------------------------------------------------------------------------
-- Trigger
---------------------------------------------------------------------------

-- What an already-running trap does about a second arrival; nil means nothing is running.
local function restack(spec, ctx, entity)
    if not isActive(spec, entity) then return nil end

    -- STACK reuses what is already running, so the caller carries on with it.
    if spec.stacking == Stacking.STACK then return nil end

    if spec.stacking == Stacking.REFRESH then
        setInstance(spec, entity, newInstance(spec, focus(ctx, entity and { entity = entity } or nil, nil)))
        return true
    end

    if spec.stacking == Stacking.IGNORE then return true end

    -- Stacking.QUEUE: the second of a kind waits out the first.
    return false
end

---@return table instance
---@return boolean isNew false when an existing instance was reused
local function open(spec, ctx, entity)
    -- STACK keeps the running instance and its state; everything else starts fresh.
    if spec.stacking == Stacking.STACK then
        local existing = getInstance(spec, entity)
        if existing then return existing, false end
    end

    local instance = newInstance(spec, focus(ctx, entity and { entity = entity } or nil, nil))
    if spec.stateful then setInstance(spec, entity, instance) end

    return instance, true
end

local function trigger(spec, ev, args, ticket)
    local players = actingPlayers(ev)

    if #players == 0 then return false end

    local ctx = makeContext(spec, ev, args, ticket, players)

    chooseVariant(spec, ctx, args)

    -- Whole-trap veto, run before anything is opened or announced.
    if spec.guard and spec.guard(focus(ctx, nil, nil)) == false then return false end

    local shared    = nil
    local sharedNew = false
    local didStart  = false

    -- Backs out an instance this trigger opened, leaving one it merely joined alone.
    local function discard(entity, isNew)
        if isNew then setInstance(spec, entity, nil) end
    end

    if not spec.perPlayer then
        local stacked = restack(spec, ctx, nil)
        if stacked ~= nil then return stacked end

        shared, sharedNew = open(spec, ctx, nil)
        focus(ctx, players[1], shared)

        if spec.start then
            -- false aborts, true counts as landed, anything else leaves it to the loop below.
            local result = spec.start(ctx)
            if result == false then
                discard(nil, sharedNew)
                return false
            end
            didStart = result == true
        end

        -- A floor with nothing rewritable on it has nothing to show for the trap.
        if spec.floor then
            if not sweepFloor(spec, ctx, shared) then
                discard(nil, sharedNew)
                return false
            end
            didStart = true
        end
    end

    local reached   = false
    local announced = false

    for _, entry in ipairs(players) do
        local instance, isNew = shared, sharedNew

        if spec.perPlayer then
            local stacked = restack(spec, ctx, entry.entity)
            if stacked ~= nil then
                -- A refresh still counts as landing on this player.
                reached = reached or stacked
                goto continue
            end

            instance, isNew = open(spec, ctx, entry.entity)
        end

        focus(ctx, entry, instance)

        if spec.apply and spec.apply(ctx) == false then
            if spec.perPlayer then discard(entry.entity, isNew) end
            goto continue
        end

        -- FIRST limits the announcement to one player, not the effect.
        if spec.announce ~= Announce.NONE
            and not (announced and spec.announce == Announce.FIRST) then
            announceTo(spec, ctx, entry)
            announced = true
        end

        reached = true

        ::continue::
    end

    if not (reached or didStart) then
        if not spec.perPlayer then discard(nil, sharedNew) end
        return false
    end

    if spec.finish then spec.finish(focus(ctx, nil, shared)) end

    return true
end

---------------------------------------------------------------------------
-- Expiry
---------------------------------------------------------------------------

local function expire(spec, id, entity, instance, ctx)
    if instance.savedTiles then restoreFloor(instance) end

    if spec.expire then
        spec.expire(focus(ctx or makeContext(spec, nil, nil, spec.channelKey),
            entity and { entity = entity } or nil, instance))
    end

    setInstanceByID(spec, id, nil)
end

-- Walks every live instance of one trap in id order, passing the id beside the entity.
local function forEachInstance(spec, fn)
    local bucket = store(spec)[spec.name]
    if not bucket then return end

    if not spec.perPlayer then
        fn(nil, nil, bucket)
        return
    end

    local ids = {}
    for id in pairs(bucket) do ids[#ids + 1] = id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local instance = bucket[id]
        if instance then fn(id, ecs.getEntityByID(id), instance) end
    end
end

---------------------------------------------------------------------------
-- Clocks
---------------------------------------------------------------------------

local function tickOne(spec, ev)
    if store(spec)[spec.name] == nil then return end

    local ctx = makeContext(spec, ev, nil, spec.channelKey)

    forEachInstance(spec, function(id, entity, instance)
        -- The player this instance belonged to is gone; so is the instance.
        if spec.perPlayer and not (entity and entity.playableCharacter) then
            setInstanceByID(spec, id, nil)
            return
        end

        local entry = entity and { entity = entity } or ctx.players[1]

        if spec.tick then spec.tick(focus(ctx, entry, instance)) end

        -- The tick may have ended the instance itself.
        if instance.remaining and getInstance(spec, entity) == instance then
            instance.remaining = instance.remaining - 1
            if instance.remaining <= 0 then expire(spec, id, entity, instance, ctx) end
        end
    end)
end

-- One handler per turn slot actually in use, rather than one per trap.
local tickSlots = {}

-- Handler names must be alphanumeric, so the slot is spelled out: "N"/"P" then digits.
local function slotHandlerName(order, sequence)
    return "apTrapSystemTick"
        .. order:sub(1, 1):upper() .. order:sub(2)
        .. (sequence < 0 and "N" or "P")
        .. string.format("%d", math.abs(sequence))
end

local function ensureTickSlot(order, sequence)
    local key = order .. ":" .. tostring(sequence)
    if tickSlots[key] then return tickSlots[key] end

    local slot = {}
    tickSlots[key] = slot

    event.turn.add(slotHandlerName(order, sequence),
        { order = order, sequence = sequence }, function(ev)
            if not ev.actionQueue then return end

            for _, spec in ipairs(slot) do
                if spec.clock ~= Clock.REAL then tickOne(spec, ev) end
            end
        end)

    return slot
end

event.tick.add("apTrapSystemRealTick", { order = "lobby", sequence = 1 }, function()
    local now = timer.unixTimestamp()

    for _, name in ipairs(names) do
        local spec = specs[name]

        if spec.clock == Clock.REAL and store(spec)[spec.name] then
            local ctx = makeContext(spec, nil, nil, spec.channelKey)

            forEachInstance(spec, function(id, entity, instance)
                if instance.endsAt and now >= instance.endsAt then
                    expire(spec, id, entity, instance, ctx)
                    return
                end

                if spec.tick then spec.tick(focus(ctx, entity and { entity = entity } or nil, instance)) end
            end)
        end
    end
end)

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------

local function clearAll(runReset)
    for _, name in ipairs(names) do
        local spec = specs[name]

        if runReset or (spec.scope or Scope.LEVEL) == Scope.LEVEL then
            local ctx = makeContext(spec, nil, nil, spec.channelKey)
            forEachInstance(spec, function(id, entity, instance)
                expire(spec, id, entity, instance, ctx)
            end)
            store(spec)[spec.name] = nil
        end
    end
end

event.gameStateLevel.add("apTrapSystemClearLevel", { order = "splitScreen" }, function()
    clearAll(false)
end)

event.gameStateReset.add("apTrapSystemClearRun", { order = "resetRunVariables" }, function()
    clearAll(true)
end)

-- Clears every effect on exit, including the ones that changed state outside the game.
event.exit.add("apTrapSystemClearExit", { order = "externalLibraries", sequence = 2 }, function()
    clearAll(true)
end)

---------------------------------------------------------------------------
-- Definition
---------------------------------------------------------------------------

-- Drops a spec's registry entries so a reload's define() replaces it instead of doubling it.
local function forgetSpec(name)
    for i = #names, 1, -1 do
        if names[i] == name then table.remove(names, i) end
    end

    for _, slot in pairs(tickSlots) do
        for i = #slot, 1, -1 do
            if slot[i].name == name then table.remove(slot, i) end
        end
    end
end

---Declares one trap; the spec says what it does, the system owns everything else.
---@param spec table
---@return table spec
function trapSystem.define(spec)
    assert(type(spec.name) == "string", "trapSystem.define: spec.name is required")

    if specs[spec.name] then forgetSpec(spec.name) end

    checkEnum(spec, "announce", Announce, "Announce")
    checkEnum(spec, "clock",    Clock,    "Clock")
    checkEnum(spec, "scope",    Scope,    "Scope")
    checkEnum(spec, "stacking", Stacking, "Stacking")
    checkEnum(spec, "storage",  Storage,  "Storage")

    spec.announce = spec.announce or Announce.EACH
    spec.clock    = spec.clock    or Clock.BEAT
    spec.scope    = spec.scope    or Scope.LEVEL
    spec.stacking = spec.stacking or Stacking.QUEUE
    spec.storage  = spec.storage  or Storage.SNAPSHOT

    -- Whether an instance outlives the trigger; anything that reads state later implies it.
    spec.stateful = spec.stateful
        or spec.duration ~= nil
        or spec.status ~= nil
        or spec.tick ~= nil
        or spec.render ~= nil
        or spec.expire ~= nil
        or (spec.floor ~= nil and spec.floor.restore == true)

    spec.channelKey = channelKey(spec.name)

    -- Sorted, then expanded by weight, so every client draws from an identical list.
    if spec.variants then
        local variantNames = {}
        for variantName in pairs(spec.variants) do
            variantNames[#variantNames + 1] = variantName
        end
        table.sort(variantNames)

        spec.variantPool = {}
        for _, variantName in ipairs(variantNames) do
            for _ = 1, spec.variants[variantName].weight or 1 do
                spec.variantPool[#spec.variantPool + 1] = variantName
            end
        end
    end

    specs[spec.name] = spec

    names[#names + 1] = spec.name
    table.sort(names)

    if spec.status then
        apTrapStatus.register(spec.name, function(entity)
            local instance = getInstance(spec, entity)
            if not instance then return nil end
            if type(spec.status) ~= "function" then return spec.status end

            return spec.status({ state = instance.state, entity = entity, remaining = instance.remaining })
        end)
    end

    if spec.render then
        event.render.add("apTrapRender" .. spec.name, {
            order    = spec.renderOrder    or "camera",
            sequence = spec.renderSequence or 2,
        }, function()
            if freezeFrame.isActive() or gameState.isPaused() then return end

            local ctx = makeContext(spec, nil, nil, spec.channelKey)
            forEachInstance(spec, function(_id, entity, instance)
                spec.render(focus(ctx, entity and { entity = entity } or nil, instance))
            end)
        end)
    end

    -- Only traps that have something to count or run each beat join a turn slot.
    if spec.clock ~= Clock.REAL and (spec.tick or spec.duration) then
        -- The default slot sits just ahead of the queue runner.
        local slot = ensureTickSlot(
            spec.tickOrder or "playerActions",
            spec.tickSequence or (spec.tickOrder and 0 or -2))
        slot[#slot + 1] = spec
        table.sort(slot, function(a, b) return a.name < b.name end)
    end

    TrapHandler.register(spec.name, function(ev, args, ticket)
        return trigger(spec, ev, args, ticket)
    end)

    return spec
end

---Ends one running instance early, running `expire` as the clock would have.
---@param name string
---@param entity table|nil Required for a perPlayer trap.
function trapSystem.stop(name, entity)
    local spec = specs[name]
    if not spec then return end

    local instance = getInstance(spec, entity)
    if not instance then return end

    expire(spec, entity and entity.id or nil, entity, instance, nil)
end

---Reads one trap's live state from outside its own callbacks.
---@param name string
---@param entity table|nil Required for a perPlayer trap.
---@return table|nil state
function trapSystem.stateOf(name, entity)
    local spec = specs[name]
    if not spec then return nil end

    local instance = getInstance(spec, entity)

    return instance and instance.state or nil
end

---True while the named trap is running.
function trapSystem.isActive(name, entity)
    local spec = specs[name]

    return spec ~= nil and isActive(spec, entity)
end

---Visits every live instance of a trap; `fn` returning true stops the walk and is returned.
---@param name string
---@param fn function(state, entity) -> boolean|nil
---@return boolean
function trapSystem.eachState(name, fn)
    local spec = specs[name]
    if not spec then return false end

    local found = false

    forEachInstance(spec, function(_id, entity, instance)
        if not found and fn(instance.state, entity) then found = true end
    end)

    return found
end

return trapSystem
