local perspective = require("necro.game.system.Perspective")
local sound       = require("necro.audio.Sound")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local SPOTLIGHT_RADIUS = 2

local spotlightedEntities = {}
spotlightedEntities = script.persist(function()
    return spotlightedEntities
end)

local Attribute = perspective.Attribute
event.objectUpdatePerspective.add("APSpotlightTrapClamp", { order = "label" }, function(ev)
    if not spotlightedEntities[ev.entity.id] then return end
    ev.perspective[Attribute.TILE_VISION_RADIUS]   = math.min(SPOTLIGHT_RADIUS, ev.perspective[Attribute.TILE_VISION_RADIUS])
    ev.perspective[Attribute.OBJECT_VISION_RADIUS] = math.min(SPOTLIGHT_RADIUS, ev.perspective[Attribute.OBJECT_VISION_RADIUS])
end)

event.gameStateLevel.add("APSpotlightTrapClearOnLevel", { order = "splitScreen" }, function()
    spotlightedEntities = {}
    perspective.update(nil)
end)

event.gameStateReset.add("APSpotlightTrapClearOnReset", { order = "resetRunVariables" }, function()
    spotlightedEntities = {}
end)

TrapHandler.register("SpotlightTrap", makeSimpleTrap({
    flyawayText = "Spotlight!",
    guard  = function(entity) return not spotlightedEntities[entity.id] end,
    sound  = "trapDice",
    action = function(entity)
        spotlightedEntities[entity.id] = true
        perspective.update(nil)
    end,
}))
