local ecs    = require "system.game.Entities"
local player = require "necro.game.character.Player"
local sound  = require "necro.audio.Sound"

local apFlyaways = require "AP.scripts.ui.apFlyaways"

---Creates a floor-persistent sprite-squash trap and returns its trigger function.
---
---The factory persists a table of entity IDs, registers an `objectUpdateScale`
---handler to apply the scale while active, and clears the table (restoring
---`mirrorX` to its facing-direction sign) on floor transition and run reset.
---
---Works for traps that stretch or squash entities by manipulating `ev.scale` (Y)
---and `entity.sprite.mirrorX` magnitude (X) independently.
---
---@param opts table
---  Required:
---    name         string  Unique key used for event handler names.
---    flyawayText  string  Shown to each affected player.
---    mirrorXScale number  Multiplier applied to the mirrorX axis (e.g. 4 = wide).
---  Optional:
---    sound       string   Played per affected player at their position.
---    scaleY      number   Multiplier applied to ev.scale (omit or nil = unchanged).
---    eventOrder  string   Order slot for objectUpdateScale (default "multiply").
---    targetAll   bool     If true, affects all "character" entities, not just
---                         players (flyaway is still only shown to playable ones).
---    guard       function(entity) -> bool
---                         Called before adding an entity; skip if false.
---    onApply     function(entity)
---                         Called after adding entity to the tracked set but before
---                         the flyaway; use for extra effects (e.g. inflict confusion).
---@return function trapFn
local function makeMirrorXTrap(opts)
    assert(opts.name,         "makeMirrorXTrap: opts.name is required")
    assert(opts.flyawayText,  "makeMirrorXTrap: opts.flyawayText is required")
    assert(opts.mirrorXScale, "makeMirrorXTrap: opts.mirrorXScale is required")

    local eventOrder = opts.eventOrder or "multiply"

    -- Per-floor entity set (entity ID -> true).
    local entities = {}
    entities = script.persist(function() return entities end)

    -- Apply scale each render frame for tracked entities.
    event.objectUpdateScale.add("AP" .. opts.name .. "Scale", { order = eventOrder }, function(ev)
        local entity = ev.entity
        if not entities[entity.id] then return end

        if opts.scaleY then
            ev.scale = ev.scale * opts.scaleY
        end

        local facingSign = entity.sprite.mirrorX > 0 and 1 or -1
        entity.sprite.mirrorX = facingSign * opts.mirrorXScale
    end)

    -- Restore mirrorX and clear on floor transition.
    event.gameStateLevel.add("AP" .. opts.name .. "ClearLevel", { order = "splitScreen" }, function()
        for id, _ in pairs(entities) do
            local entity = ecs.getEntityByID(id)
            if entity and entity.sprite then
                entity.sprite.mirrorX = entity.sprite.mirrorX > 0 and 1 or -1
            end
        end
        entities = {}
    end)

    -- Clear on run reset.
    event.gameStateReset.add("AP" .. opts.name .. "ClearReset", { order = "resetRunVariables" }, function()
        entities = {}
    end)

    return function(ev)
        local trapSuccess = false

        local function processEntity(entity)
            if entities[entity.id] then return end
            if opts.guard and not opts.guard(entity) then return end

            entities[entity.id] = true

            if opts.onApply then opts.onApply(entity) end

            trapSuccess = true

            if entity.playableCharacter then
                if opts.sound then
                    sound.play(opts.sound, entity.position.x, entity.position.y)
                end
                apFlyaways.addToFlyawayQueue({ entity = entity, text = opts.flyawayText })
            end
        end

        if opts.targetAll then
            for entity in ecs.entitiesWithComponents({ "character" }) do
                processEntity(entity)
            end
        else
            for _, entity in ipairs(player.getPlayerEntities()) do
                if entity and entity.playableCharacter then
                    processEntity(entity)
                end
            end
        end

        return trapSuccess
    end
end

return { makeMirrorXTrap = makeMirrorXTrap }
