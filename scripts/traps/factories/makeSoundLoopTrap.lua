local currentLevel = require "necro.game.level.CurrentLevel"
local player       = require "necro.game.character.Player"
local rng          = require "necro.game.system.RNG"
local sound        = require "necro.audio.Sound"
local timer        = require "system.utils.Timer"
local turn         = require "necro.cycles.Turn"

local apFlyaways   = require "AP.scripts.ui.apFlyaways"

---Creates a tick-based sound-loop trap and returns its trigger function.
---
---On trigger the trap shows a flyaway to each player, then plays bursts of random
---sounds from `opts.soundGroups` on every engine tick until `opts.duration` real
---seconds have elapsed, at which point it returns true (success / dequeue).
---
---Calling the trigger again before the duration expires is a no-op (returns false).
---
---@param opts table
---  Required:
---    name        string   Unique name used for event handler keys.
---    flyawayText string
---    soundGroups table    List of sound-group name strings to pick from.
---  Optional:
---    duration  number  Real-time seconds the loop lasts (default 10).
---    minBurst  number  Minimum sounds fired per tick per player (default 1).
---    maxBurst  number  Maximum sounds fired per tick per player (default 3).
---@return function trapFn
local function makeSoundLoopTrap(opts)
    assert(opts.name,       "makeSoundLoopTrap: opts.name is required")
    assert(opts.flyawayText,"makeSoundLoopTrap: opts.flyawayText is required")
    assert(opts.soundGroups and #opts.soundGroups > 0,
        "makeSoundLoopTrap: opts.soundGroups must be a non-empty table")

    local duration = opts.duration or 10
    local minBurst = opts.minBurst or 1
    local maxBurst = opts.maxBurst or 3

    -- Internal state – persisted by the module that called this factory.
    local trapTimestamp  = 0
    local trapTickCounter = 0
    trapTimestamp, trapTickCounter = script.persist(function()
        return trapTimestamp, trapTickCounter
    end)

    local function playSounds()
        local seed = table.concat({
            "AP-" .. opts.name,
            tostring(currentLevel.getSeed()),
            tostring(trapTimestamp),
            tostring(turn.getCurrentTurnID()),
            tostring(trapTickCounter),
        }, "-")
        local channel = rng.makeChannel(seed)

        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto skip end

            local burst = rng.range(minBurst, maxBurst, channel)
            for _ = 1, burst do
                sound.playFromEntity(rng.choice(opts.soundGroups, channel), entity)
            end

            ::skip::
        end
    end

    event.tick.add("AP" .. opts.name .. "Tick", { order = "rhythm", sequence = 1 }, function()
        if trapTimestamp == 0 then return end
        trapTickCounter = trapTickCounter + 1
        playSounds()
    end)

    event.exit.add("AP" .. opts.name .. "Exit", { order = "externalLibraries", sequence = 2 }, function()
        trapTimestamp  = 0
        trapTickCounter = 0
    end)

    return function(ev)
        if trapTimestamp == 0 then
            -- First call: start the loop.
            trapTimestamp  = timer.unixTimestamp()
            trapTickCounter = 0

            for _, entity in ipairs(player.getPlayerEntities()) do
                if entity and entity.playableCharacter then
                    apFlyaways.addToFlyawayQueue({ entity = entity, text = opts.flyawayText })
                end
            end
        end

        -- Check if the real-time duration has elapsed.
        if timer.unixTimestamp() - trapTimestamp > duration then
            trapTimestamp  = 0
            trapTickCounter = 0
            return true
        end

        return false
    end
end

return { makeSoundLoopTrap = makeSoundLoopTrap }
