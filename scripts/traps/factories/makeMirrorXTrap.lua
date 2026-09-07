local ecs = require "system.game.Entities"

local trapSystem = require "AP.scripts.traps.trapSystem"

---Defines a floor-persistent trap that scales entities on the mirrorX and ev.scale axes.
---@param opts table
---  Required:
---    name         string  Trap id, also used for the event handler name.
---    flyaway      string  Shown to each affected player.
---    mirrorXScale number  Multiplier applied to the mirrorX axis (e.g. 4 = wide).
---  Optional:
---    sound       string   Played per affected player at their position.
---    scaleY      number   Multiplier applied to ev.scale (omit or nil = unchanged).
---    eventOrder  string   Order slot for objectUpdateScale (default "multiply").
---    targetAll   bool     Affect all "character" entities, not just players.
---    guard       function(entity) -> bool   Skip the entity when false.
---    onApply     function(entity)           Run after tracking, before the flyaway.
---@return table spec
local function makeMirrorXTrap(opts)
    assert(opts.name,         "makeMirrorXTrap: opts.name is required")
    assert(opts.flyaway,      "makeMirrorXTrap: opts.flyaway is required")
    assert(opts.mirrorXScale, "makeMirrorXTrap: opts.mirrorXScale is required")

    local eventOrder = opts.eventOrder or "multiply"

    local function tracked(entity)
        local state = trapSystem.stateOf(opts.name)

        return state and state.entities[entity.id] or false
    end

    -- Apply scale each render frame for tracked entities.
    event.objectUpdateScale.add("AP" .. opts.name .. "Scale", { order = eventOrder }, function(ev)
        local entity = ev.entity
        if not tracked(entity) then return end

        if opts.scaleY then
            ev.scale = ev.scale * opts.scaleY
        end

        local facingSign = entity.sprite.mirrorX > 0 and 1 or -1
        entity.sprite.mirrorX = facingSign * opts.mirrorXScale
    end)

    return trapSystem.define({
        name     = opts.name,
        flyaway  = opts.flyaway,
        sound    = opts.sound,
        -- Sprite scale only, so it must not rewind mid-frame.
        storage  = trapSystem.Storage.VOLATILE,
        stateful = true,
        start    = function(ctx)
            ctx.state.entities = {}

            -- Squashing everything on the floor is the whole effect, so it counts as landed.
            if not opts.targetAll then return end

            for entity in ecs.entitiesWithComponents({ "character" }) do
                if not (opts.guard and not opts.guard(entity)) then
                    ctx.state.entities[entity.id] = true
                    if opts.onApply then opts.onApply(entity) end
                end
            end

            return true
        end,
        apply    = function(ctx)
            local entity = ctx.entity

            -- targetAll already swept this player in; announce without re-applying.
            if ctx.state.entities[entity.id] then return end
            if opts.guard and not opts.guard(entity) then return false end

            ctx.state.entities[entity.id] = true
            if opts.onApply then opts.onApply(entity) end
        end,
        -- Put every stretched sprite back to its plain facing sign.
        expire   = function(ctx)
            for id in pairs(ctx.state.entities or {}) do
                local entity = ecs.getEntityByID(id)
                if entity and entity.sprite then
                    entity.sprite.mirrorX = entity.sprite.mirrorX > 0 and 1 or -1
                end
            end
        end,
    })
end

return { makeMirrorXTrap = makeMirrorXTrap }
