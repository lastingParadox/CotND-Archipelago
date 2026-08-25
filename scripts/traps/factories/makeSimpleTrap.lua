local player = require "necro.game.character.Player"
local sound  = require "necro.audio.Sound"
local voice  = require "necro.audio.Voice"

local apFlyaways = require "AP.scripts.ui.apFlyaways"

---Creates a single-loop player trap and returns its trigger function.
---
---Handles the standard boilerplate: iterate playable-character entities, apply an
---optional guard, play an optional sound/voice, call an optional per-entity action,
---show a flyaway, then run an optional post-loop callback.
---
---All callbacks receive a `ctx` value (the return of `opts.setup`, if provided),
---allowing shared pre-computed state (e.g. a spawn tile) to be threaded through.
---
---@param opts table
---  Required:
---    flyawayText  string
---  Optional:
---    guard   function(entity, ctx) -> bool
---                     Skip entity if false.
---    sound   string   Played per entity at its world position.
---    voice   string   Played per entity via voice.tryPlay.
---    action  function(entity, ctx)
---                     Called per entity after guard/sound/voice (before flyaway).
---    setup   function() -> ctx
---                     Called once before the player loop; return value is threaded
---                     to guard/action/after as `ctx`.  Return false to abort (trap
---                     returns false without showing flyaways).
---    before  function()
---                     Called before setup and the player loop (e.g. play a UI sound).
---    after   function(ctx)
---                     Called after the player loop when trapSuccess is true.
---    alwaysSucceed bool
---                     If true, the trap returns true even if no entities matched.
---@return function trapFn
local function makeSimpleTrap(opts)
    return function(ev)
        if opts.before then opts.before() end

        local ctx = nil
        if opts.setup then
            ctx = opts.setup()
            if ctx == false then return false end
        end

        local trapSuccess = false

        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end
            if opts.guard and not opts.guard(entity, ctx) then goto continue end

            if opts.voice then voice.tryPlay(entity, opts.voice) end
            if opts.sound then sound.play(opts.sound, entity.position.x, entity.position.y) end

            -- If action returns explicit false, skip this entity (no flyaway, no success).
            if opts.action and opts.action(entity, ctx) == false then goto continue end

            local flyawayText = type(opts.flyawayText) == "function"
                and opts.flyawayText(entity, ctx)
                or opts.flyawayText
            if flyawayText then
                apFlyaways.addToFlyawayQueue({ entity = entity, text = flyawayText })
            end
            trapSuccess = true

            ::continue::
        end

        if (trapSuccess or opts.alwaysSucceed) and opts.after then
            opts.after(ctx)
        end

        return trapSuccess or (opts.alwaysSucceed == true)
    end
end

return { makeSimpleTrap = makeSimpleTrap }
