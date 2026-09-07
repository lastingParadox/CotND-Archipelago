local rng    = require "necro.game.system.RNG"
local sound  = require "necro.audio.Sound"

local trapSystem = require "AP.scripts.traps.trapSystem"

---Defines a trap that plays bursts from `opts.soundGroups` each tick for `opts.duration`.
---@param opts table
---  Required:
---    name        string   Trap id.
---    flyaway     string
---    soundGroups table    List of sound-group name strings to pick from.
---  Optional:
---    duration  number  Real-time seconds the loop lasts (default 10).
---    minBurst  number  Minimum sounds fired per tick per player (default 1).
---    maxBurst  number  Maximum sounds fired per tick per player (default 3).
---@return table spec
local function makeSoundLoopTrap(opts)
    assert(opts.name,    "makeSoundLoopTrap: opts.name is required")
    assert(opts.flyaway, "makeSoundLoopTrap: opts.flyaway is required")
    assert(opts.soundGroups and #opts.soundGroups > 0,
        "makeSoundLoopTrap: opts.soundGroups must be a non-empty table")

    local minBurst = opts.minBurst or 1
    local maxBurst = opts.maxBurst or 3

    return trapSystem.define({
        name     = opts.name,
        flyaway  = opts.flyaway,
        duration = opts.duration or 10,
        clock    = trapSystem.Clock.REAL,
        -- Audio only, and the tick counter must not rewind mid-burst.
        storage  = trapSystem.Storage.VOLATILE,
        start    = function(ctx) ctx.state.ticks = 0 end,
        tick     = function(ctx)
            ctx.state.ticks = ctx.state.ticks + 1

            -- Re-seeded off the tick count, so a burst differs from the last one.
            local channel = rng.makeChannel(ctx.spec.channelKey, ctx.state.ticks)

            for _, entry in ipairs(ctx.players) do
                local burst = rng.range(minBurst, maxBurst, channel)
                for _ = 1, burst do
                    sound.playFromEntity(rng.choice(opts.soundGroups, channel), entry.entity)
                end
            end
        end,
    })
end

return { makeSoundLoopTrap = makeSoundLoopTrap }
