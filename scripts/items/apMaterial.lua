local apItemFactory = require("AP.scripts.items.apItemFactory")

local MATERIALS = { "Titanium", "Obsidian", "Glass", "Blood", "Gold", "Onyx" }

for _, material in ipairs(MATERIALS) do
    local lower = material:lower()

    apItemFactory.define({
        name = "AP_Material" .. material,
        texture = "materials/material_" .. string.lower(material) .. ".png",
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
