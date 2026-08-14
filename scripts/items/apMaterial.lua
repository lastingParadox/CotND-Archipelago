local apItemFactory = require("AP.scripts.items.apItemFactory")

-- Six prototypes rather than one entity with a type field: each needs its own
-- sprite in the item room, and progression/items.lua and apShopSlot.lua both
-- address them by the AP_Material<Name> name.
local MATERIALS = { "Titanium", "Obsidian", "Glass", "Blood", "Gold", "Onyx" }

for _, material in ipairs(MATERIALS) do
    local lower = material:lower()

    apItemFactory.define({
        name = "AP_Material" .. material,
        texture = "materials/Material" .. material .. ".png",
        destructible = false,
        data = {
            flyaway = material .. " Material",
            hint = "Unlock " .. lower .. " weapons",
        },
        components = {
            AP_material = {},
        },
    })
end
