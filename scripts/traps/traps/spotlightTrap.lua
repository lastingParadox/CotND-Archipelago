local perspective = require("necro.game.system.Perspective")

local trapSystem = require("AP.scripts.traps.trapSystem")

local SPOTLIGHT_RADIUS = 2

local Attribute = perspective.Attribute
event.objectUpdatePerspective.add("APSpotlightTrapClamp", { order = "label" }, function(ev)
    if not trapSystem.isActive("SpotlightTrap", ev.entity) then return end

    ev.perspective[Attribute.TILE_VISION_RADIUS]   = math.min(SPOTLIGHT_RADIUS, ev.perspective[Attribute.TILE_VISION_RADIUS])
    ev.perspective[Attribute.OBJECT_VISION_RADIUS] = math.min(SPOTLIGHT_RADIUS, ev.perspective[Attribute.OBJECT_VISION_RADIUS])
end)

trapSystem.define({
    name      = "SpotlightTrap",
    flyaway   = "Spotlight!",
    sound     = "trapDice",
    perPlayer = true,
    -- Vision radius is drawn, not simulated.
    storage   = trapSystem.Storage.VOLATILE,
    stateful  = true,
    apply     = function() perspective.update(nil) end,
    expire    = function() perspective.update(nil) end,
})
