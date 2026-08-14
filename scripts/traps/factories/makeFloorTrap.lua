local currentLevel = require "necro.game.level.CurrentLevel"
local player       = require "necro.game.character.Player"
local rng          = require "necro.game.system.RNG"
local snapshot     = require "necro.game.system.Snapshot"
local tile         = require "necro.game.tile.Tile"
local turn         = require "necro.cycles.Turn"
local voice        = require "necro.audio.Voice"

local apFlyaways   = require "AP.scripts.ui.apFlyaways"

-- Rollback-managed with the tile map. Keyed by name: snapshot variables must be
-- script globals, but this factory runs once per trap.
apFloorTrapState = snapshot.variable({}, true)

local function getFloorState(name)
    local state = apFloorTrapState[name]
    if not state then
        state = { savedTiles = {}, beatsRemaining = 0 }
        apFloorTrapState[name] = state
    end
    return state
end

---Creates a whole-floor modification trap and returns its trigger function.
---
---The trap iterates every non-immutable floor tile in the level and transforms it,
---then notifies each player with a flyaway (and optional voice line).
---
---@param opts table
---  Required (choose one):
---    tileType  string                   Named tile type applied via tile.setType to every floor tile.
---    setTile   function(x,y,ch,ctx)     Custom per-tile operation (use for random/complex transforms).
---  Required:
---    flyawayText string
---  Optional:
---    name     string    Required when duration > 0; used for event handler names.
---    voice    string    Voice key played per player (default "voiceConfused"). Pass false to skip.
---    sound    string    Sound key played per player (unused slot; add sound.play call in setTile or onSuccess).
---    isActive function()->bool  If provided, returns false (blocking re-entry) while active.
---    prepare  function(channel)->any  Called once before the floor pass; return value passed as .
---    duration number    If set, tiles are automatically restored after this many beats.
---                       Requires opts.name. Uses tile.get / tile.set to save and restore tile IDs.
---@return function trapFn
local function makeFloorTrap(opts)
    assert(opts.flyawayText, "makeFloorTrap: opts.flyawayText is required")
    assert(opts.tileType or opts.setTile,
        "makeFloorTrap: either opts.tileType or opts.setTile is required")

    -- Only create an RNG channel when the caller actually uses one.
    local needsChannel = (opts.setTile ~= nil) or (opts.prepare ~= nil)

    if opts.duration then
        assert(opts.name, "makeFloorTrap: opts.name is required when opts.duration is set")

        local function restoreFloor()
            local state = getFloorState(opts.name)
            for _, entry in ipairs(state.savedTiles) do
                tile.set(entry.x, entry.y, entry.id)
            end
            state.savedTiles     = {}
            state.beatsRemaining = 0
        end

        event.turn.add("AP" .. opts.name .. "Tick", { order = "traps" }, function()
            local state = getFloorState(opts.name)
            if state.beatsRemaining <= 0 then return end
            state.beatsRemaining = state.beatsRemaining - 1
            if state.beatsRemaining <= 0 then restoreFloor() end
        end)

        local function clearState()
            apFloorTrapState[opts.name] = nil
        end

        event.gameStateLevel.add("AP" .. opts.name .. "ClearLevel", { order = "splitScreen" }, clearState)
        event.gameStateReset.add("AP" .. opts.name .. "ClearReset", { order = "resetRunVariables" }, clearState)
    end

    return function(ev)
        if opts.isActive and opts.isActive() then return false end

        local state = opts.duration and getFloorState(opts.name) or nil
        if state and state.beatsRemaining > 0 then return false end

        local channel = needsChannel
            and rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
            or nil

        local ctx = opts.prepare and opts.prepare(channel) or nil

        local levelX, levelY, levelW, levelH = tile.getLevelBounds()

        if state then
            state.savedTiles = {}
        end

        local anyReplaced = false
        for y = levelY, levelY + levelH - 1 do
            for x = levelX, levelX + levelW - 1 do
                local info = tile.getInfo(x, y)
                if not (info.isFloor and not info.immutable) then goto nextTile end

                -- Save original tile ID before replacing (only when duration restore is active).
                if state then
                    local originalID = tile.get(x, y)
                    if originalID ~= 0 then
                        state.savedTiles[#state.savedTiles + 1] = { x = x, y = y, id = originalID }
                    end
                end

                if opts.setTile then
                    opts.setTile(x, y, channel, ctx)
                else
                    tile.setType(x, y, opts.tileType)
                end
                anyReplaced = true

                ::nextTile::
            end
        end

        if not anyReplaced then return false end

        if state then
            state.beatsRemaining = opts.duration
        end

        local trapSuccess = false

        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end

            if opts.voice ~= false then
                voice.tryPlay(entity, opts.voice or "voiceConfused")
            end
            apFlyaways.addToFlyawayQueue({ entity = entity, text = opts.flyawayText })

            trapSuccess = true
            ::continue::
        end

        return trapSuccess
    end
end

return { makeFloorTrap = makeFloorTrap }
