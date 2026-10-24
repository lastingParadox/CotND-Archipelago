local color = require("system.utils.Color")

local apItems = require("AP.scripts.utils.apItems")

local apColors = {
    filler      = color.rgb(125, 238, 238),
    progression = color.rgb(175, 153, 239),
    useful      = color.rgb(105, 134, 223),
    trap        = color.rgb(250, 128, 114),

    player      = color.rgb(238, 125, 238),

    locked      = color.rgb(255, 87, 106),
    disabled    = color.rgb(120, 120, 120),
    requirement = color.rgb(255, 196, 87),
    silhouette  = color.rgb(114, 126, 133),

    connected   = color.rgb(95, 168, 80),
    custom      = color.rgb(170, 80, 80),
    lowPercent  = color.rgb(51, 51, 170),
    chatBadge   = color.rgb(49, 107, 132),
    trapStatus  = color.rgb(255, 96, 96),

    deathLinkCountdown  = color.rgb(120, 120, 120),
    possessionCountdown = color.rgb(89, 198, 101),
}

-- Names not defined above fall through to the engine's Color module.
setmetatable(apColors, { __index = color })

-- The palette colour for an AP item's classification bitmask.
function apColors.forClassification(classification)
    return apColors[apItems.itemClassName(classification)] or color.WHITE
end

return apColors
