local freezeFrame  = require "necro.render.FreezeFrame"
local gameState    = require "necro.client.GameState"
local player       = require "necro.game.character.Player"
local rng          = require "necro.game.system.RNG"
local timer        = require "system.utils.Timer"
local voice        = require "necro.audio.Voice"
local currentLevel = require "necro.game.level.CurrentLevel"
local turn         = require "necro.cycles.Turn"

local apFlyaways   = require "AP.scripts.ui.apFlyaways"
local apReplay     = require "AP.scripts.utils.apReplay"

---Creates a timed camera-transform (or window-effect) trap and returns its trigger function.
---
---The calling module must define its own `trapTimestamp` (and any extra state)
---using `script.persist` at the module level, then pass accessor callbacks here.
---
---@param opts table
---  Required:
---    name         string    Unique identifier; used as the event registration name suffix.
---    flyawayText  string    Text shown to each affected player on trigger.
---    isActive     function()->bool    Returns true while the trap is running.
---    getTimestamp function()->number  Returns the stored unix timestamp.
---    setTimestamp function(number)    Writes the stored unix timestamp.
---  Optional (at least one of applyEffect / tickEffect should usually be set):
---    applyEffect  function()  Called every render frame while the trap is active.
---    tickEffect   function()  Called every game tick while the trap is active.
---                             Use instead of applyEffect for non-render effects (e.g. window settings).
---    duration    number    Active seconds (default 20).
---    voice       string    playableCharacter voice key played on trigger (e.g. "voiceConfused").
---    sequence    number    event.render / event.tick sequence (default 2).
---    eventOrder  string    event.render order group (default "camera"). Ignored for tickEffect.
---    onTrigger   function(channel) -> bool?
---                                   Extra setup called once after a successful trigger.
---                                   Receives a pre-built RNG channel.  Return false to abort
---                                   (cancels the timestamp set and reverts trapSuccess).
---    onExpire    function()         Cleanup called when the duration elapses.
---    onExit      function()         Cleanup called on game exit if the trap is still active.
---                                   Note: expire() (which calls onExpire) runs first; use this
---                                   for any additional teardown beyond what onExpire covers.
---@return function trapFn  Pass to TrapHandler.register.
local function makeCameraTrap(opts)
    assert(type(opts.name)         == "string",   "makeCameraTrap: opts.name must be a string")
    assert(type(opts.flyawayText)  == "string",   "makeCameraTrap: opts.flyawayText must be a string")
    assert(type(opts.isActive)     == "function", "makeCameraTrap: opts.isActive must be a function")
    assert(type(opts.getTimestamp) == "function", "makeCameraTrap: opts.getTimestamp must be a function")
    assert(type(opts.setTimestamp) == "function", "makeCameraTrap: opts.setTimestamp must be a function")

    local duration   = opts.duration   or 20
    local eventOrder = opts.eventOrder or "camera"
    local sequence   = opts.sequence   or 2

    local function expire()
        opts.setTimestamp(0)
        if opts.onExpire then opts.onExpire() end
    end

    -- Per-frame effect listener: applies the render transform while the trap is active.
    if opts.applyEffect then
        event.render.add("AP" .. opts.name, { order = eventOrder, sequence = sequence }, function()
            if freezeFrame.isActive() or gameState.isPaused() or not opts.isActive() then return end
            if timer.unixTimestamp() - opts.getTimestamp() > duration then
                expire()
                return
            end
            opts.applyEffect()
        end)
    end

    -- Per-tick effect listener: applies a non-render effect (e.g. window settings) each game tick.
    if opts.tickEffect then
        event.tick.add("AP" .. opts.name .. "Tick", { order = "lobby", sequence = 1 }, function()
            if not opts.isActive() then return end
            if timer.unixTimestamp() - opts.getTimestamp() > duration then
                expire()
                return
            end
            opts.tickEffect()
        end)
    end

    -- Optional game-exit cleanup.
    if opts.onExit then
        event.exit.add("AP" .. opts.name .. "Exit", { order = "externalLibraries", sequence = 2 }, function()
            if opts.isActive() then
                expire()
                opts.onExit()
            end
        end)
    end

    ---Trigger function registered with TrapHandler.
    ---Returns true on success, false to stay queued.
    return function(ev)
        local replayKey = "cameraTrap:" .. opts.name

        if opts.isActive() then
            -- Wall-clock timestamp outlives a rollback the queue entry does not,
            -- so a replay must report the same success to consume the entry.
            return apReplay.seen(replayKey)
        end

        local trapSuccess = false

        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end

            apFlyaways.addToFlyawayQueue({ entity = entity, text = opts.flyawayText })
            if opts.voice then voice.tryPlay(entity, opts.voice) end

            trapSuccess = true
            ::continue::
        end

        if trapSuccess then
            if opts.onTrigger then
                local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
                if opts.onTrigger(channel) == false then
                    return false
                end
            end
            opts.setTimestamp(timer.unixTimestamp())
            apReplay.mark(replayKey)
        end

        return trapSuccess
    end
end

return { makeCameraTrap = makeCameraTrap }
