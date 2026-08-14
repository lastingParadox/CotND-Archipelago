local affectorItem = require "necro.game.item.AffectorItem"
local beatmap      = require "necro.audio.Beatmap"
local currentLevel = require "necro.game.level.CurrentLevel"
local player       = require "necro.game.character.Player"
local rhythm       = require "necro.game.character.Rhythm"
local rng          = require "necro.game.system.RNG"
local timeScale    = require "necro.audio.TimeScale"
local turn         = require "necro.cycles.Turn"

local apFlyaways   = require "AP.scripts.ui.apFlyaways"

---Creates a tempo-changing trap and returns its trigger function.
---
---The trap checks `itemMusicChangeImmunity` per player; immune players receive a
---negated flyaway instead of the tempo effect.  Returns false while a region from
---a previous trigger is still active.
---
---Duration is symmetric: the region always covers `durationBeats` *perceived* beats
---regardless of whether factor speeds up or slows down playback.
---(realBeats = durationBeats * max(factor, 1/factor))
---
---@param opts table
---  Required – one of:
---    factor      number   Constant tempo factor (>1 = fast, <1 = slow).
---    getFactor   function(channel) -> factor:number, flyawayText:string
---                         Computed per-trigger (e.g. random tempo selection).
---  If using factor (not getFactor):
---    flyawayText string  Text shown to affected players.
---  Optional:
---    name         string  Used to build the persist slot key (required, aids debugging).
---    negatedText  string  Shown to immune players (default: opts.name.." Negated!").
---    durationBeats number Perceived beats of the effect (default 32).
---    fadeIn        number TimeScale fade-in beats (default 2).
---    fadeOut       number TimeScale fade-out beats (default 0.5).
---@return function trapFn
local function makeTempoTrap(opts)
    assert(opts.factor or opts.getFactor,
        "makeTempoTrap: opts.factor or opts.getFactor is required")
    if opts.factor and not opts.getFactor then
        assert(opts.flyawayText,
            "makeTempoTrap: opts.flyawayText is required when using opts.factor")
    end

    local name         = opts.name or "UnknownTempoTrap"
    local durationBeats = opts.durationBeats or 32
    local fadeIn        = opts.fadeIn  or 2
    local fadeOut       = opts.fadeOut or 0.5
    local negatedText   = opts.negatedText or (name .. " Negated!")

    -- Persisted region handle; non-zero while a region is active.
    local trapRegion = 0
    trapRegion = script.persist(function() return trapRegion end)

    return function(ev)
        -- Expire stale region.
        local region  = timeScale.getRegion(trapRegion)
        local endTime = region and region.startTime + region.duration or 0
        if endTime < turn.getRawTimestamp() then
            trapRegion = 0
        end
        if trapRegion ~= 0 then return false end

        local channel = opts.getFactor
            and rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
            or nil

        local factor, flyawayText
        if opts.getFactor then
            factor, flyawayText = opts.getFactor(channel)
        else
            factor      = opts.factor
            flyawayText = opts.flyawayText
        end

        local trapSuccess    = false
        local affectedPlayers = {}

        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end

            if affectorItem.getItem(entity, "itemMusicChangeImmunity") then
                apFlyaways.addToFlyawayQueue({ entity = entity, text = negatedText })
                trapSuccess = true
            else
                affectedPlayers[#affectedPlayers + 1] = entity
                trapSuccess = true
            end

            ::continue::
        end

        if not trapSuccess then return false end
        if #affectedPlayers == 0 then return true end  -- all immune

        local map      = beatmap.getOriginal()
        local speed    = rhythm.getEffectiveSpeed(affectedPlayers[1].id) or 1
        local start    = turn.getRawTimestamp()
        -- Cover the same perceived duration regardless of direction.
        --   factor > 1 → realBeats = durationBeats * factor
        --   factor < 1 → realBeats = durationBeats / factor
        local realBeats = math.floor(
            durationBeats * math.max(factor, 1.0 / factor) / speed
        )

        trapRegion = timeScale.addRegion(start, map.getBeatAt(realBeats), factor, fadeIn, fadeOut)

        for _, entity in ipairs(affectedPlayers) do
            apFlyaways.addToFlyawayQueue({ entity = entity, text = flyawayText })
        end

        return true
    end
end

return { makeTempoTrap = makeTempoTrap }
