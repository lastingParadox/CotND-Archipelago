local customEntities = require("necro.game.data.CustomEntities")
local utils = require("system.utils.Utilities")

local apGrants = require("AP.scripts.items.apGrants")

local apItemFactory = {}

local GFX = "mods/AP/gfx/"

local function spriteComponent(spec)
    return {
        texture = spec.texture and (GFX .. spec.texture) or spec.rawTexture,
        width = spec.width or 24,
        height = spec.height or 24,
    }
end

local function withDefaults(defaults, overrides)
    return utils.mergeTablesRecursive(defaults, overrides or {}, 2)
end

-- One grant or several: a carrier that stands in for a whole family declares each.
local function grantList(spec)
    if not spec.grant then return {} end
    if spec.grant[1] then return spec.grant end

    return { spec.grant }
end

---`grant` declares how the item takes effect, alongside the carrier it arrives on --
---one apGrants spec or an array of them, with `carrier` defaulting to this entity.
function apItemFactory.define(spec)
    local components = {
        sprite = spriteComponent(spec),
        AP_editorCategory = {},
    }

    if spec.destructible ~= false then components.itemDestructible = {} end
    if spec.hint then components.AP_hintLabel = { text = spec.hint } end
    if spec.flyaway then components.AP_flyaway = { text = spec.flyaway } end

    for _, grant in ipairs(grantList(spec)) do
        -- carrier = false for an item whose pickup must not claim it: marking the location
        -- consumed there would suppress the grant that carries the effect.
        if grant.carrier == nil then grant.carrier = spec.name end
        if grant.carrier == false then grant.carrier = nil end

        apGrants.define(grant)
    end

    return customEntities.extend({
        name = spec.name,
        template = customEntities.template.item(spec.xmlItem),
        data = withDefaults({ slot = "misc" }, spec.data),
        components = withDefaults(components, spec.components),
    })
end

-- Only what the disguise looks like
local DISGUISE_SPRITE_FIELDS = {
    "texture", "width", "height", "textureShiftX", "textureShiftY", "scale", "color",
}

local function firstNonEmpty(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "string" and value ~= "" then return value end
    end
end

---Makes a carrier wear another item's sprite, for the carriers that stand in for an item
---@return string|nil label The item's own name, for the caller to label the disguise with.
function apItemFactory.disguise(entity, prototype)
    if not (entity and entity.sprite and prototype and prototype.sprite) then return nil end

    for _, field in ipairs(DISGUISE_SPRITE_FIELDS) do
        entity.sprite[field] = prototype.sprite[field]
    end

    return firstNonEmpty(
        prototype.itemHintLabel and prototype.itemHintLabel.text,
        prototype.friendlyName and prototype.friendlyName.name,
        prototype.name
    )
end

function apItemFactory.defineDisplay(spec)
    return customEntities.register(withDefaults({
        name = spec.name,
        sprite = spriteComponent(spec),
        editorHidden = {},
    }, spec.components))
end

return apItemFactory
