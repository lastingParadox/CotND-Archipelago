local customEntities = require("necro.game.data.CustomEntities")
local utils = require("system.utils.Utilities")

local apItemFactory = {}

local GFX = "mods/AP/gfx/"

local function spriteComponent(spec)
    return {
        texture = spec.texture and (GFX .. spec.texture) or spec.rawTexture,
        width = spec.width or 24,
        height = spec.height or 24,
    }
end

-- Depth 2 so a spec can override single sprite fields without restating the rest.
local function withDefaults(defaults, overrides)
    return utils.mergeTablesRecursive(defaults, overrides or {}, 2)
end

-- An AP carrier: an item that exists only to be bought or picked up, and whose
-- effect is driven by whichever marker component the spec adds.
function apItemFactory.define(spec)
    local components = {
        sprite = spriteComponent(spec),
        AP_editorCategory = {},
    }

    if spec.destructible ~= false then components.itemDestructible = {} end
    if spec.hint then components.AP_hintLabel = { text = spec.hint } end
    if spec.flyaway then components.AP_flyaway = { text = spec.flyaway } end

    return customEntities.extend({
        name = spec.name,
        template = customEntities.template.item(spec.xmlItem),
        data = withDefaults({ slot = "misc" }, spec.data),
        components = withDefaults(components, spec.components),
    })
end

-- A prototype that is only ever drawn, never carried. Previews read the
-- prototype's own sprite, so anything needing its own look needs its own entity
-- even when nothing picks it up.
function apItemFactory.defineDisplay(spec)
    return customEntities.register(withDefaults({
        name = spec.name,
        sprite = spriteComponent(spec),
        editorHidden = {},
    }, spec.components))
end

return apItemFactory
