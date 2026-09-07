local affectorItem = require "necro.game.item.AffectorItem"
local beatmap      = require "necro.audio.Beatmap"
local rhythm       = require "necro.game.character.Rhythm"
local timeScale    = require "necro.audio.TimeScale"
local turn         = require "necro.cycles.Turn"

local trapSystem = require "AP.scripts.traps.trapSystem"

local DURATION_BEATS = 32
local FADE_IN        = 2
local FADE_OUT       = 0.5

---Fast and Slow carry no weight, so only TrapLink can name them through args.variant.
local VARIANTS = {
    Fast      = { weight = 0, factor = 1.25,  flyaway = "Fast!" },
    Slow      = { weight = 0, factor = 0.75,  flyaway = "Slow!" },
    TempoUp   = { factor = 1.125, flyaway = "Tempo Up!" },
    TempoDown = { factor = 0.875, flyaway = "Tempo Down!" },
}

local function regionEnded(handle)
    local region  = timeScale.getRegion(handle)
    local endTime = region and region.startTime + region.duration or 0

    return endTime < turn.getRawTimestamp()
end

trapSystem.define({
    name     = "TempoTrap",
    variants = VARIANTS,
    -- The trap holds the region handle so a second arrival waits instead of stacking.
    clock    = trapSystem.Clock.REAL,
    storage  = trapSystem.Storage.VOLATILE,
    stateful = true,
    flyaway  = function(ctx)
        return affectorItem.getItem(ctx.entity, "itemMusicChangeImmunity")
            and "Tempo Trap Negated!"
            or  ctx.variant.flyaway
    end,
    start    = function(ctx)
        local affected = {}
        for _, entry in ipairs(ctx.players) do
            if not affectorItem.getItem(entry.entity, "itemMusicChangeImmunity") then
                affected[#affected + 1] = entry.entity
            end
        end

        -- Everyone is immune: the flyaways still land, but nothing is scheduled.
        if #affected == 0 then return end

        local factor = ctx.variant.factor
        local map    = beatmap.getOriginal()
        local speed  = rhythm.getEffectiveSpeed(affected[1].id) or 1
        local start  = turn.getRawTimestamp()

        -- Covers the same perceived duration regardless of direction.
        local realBeats = math.floor(
            DURATION_BEATS * math.max(factor, 1.0 / factor) / speed
        )

        ctx.state.region = timeScale.addRegion(
            start, map.getBeatAt(realBeats), factor, FADE_IN, FADE_OUT)
    end,
    -- Once the region lapses the slot is free again, so a queued tempo trap can go.
    tick     = function(ctx)
        if not ctx.state.region or regionEnded(ctx.state.region) then
            trapSystem.stop("TempoTrap")
        end
    end,
})
