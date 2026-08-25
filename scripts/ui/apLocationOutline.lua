local ecs = require "system.game.Entities"
local itemStorage = require "necro.game.item.ItemStorage"
local objectRenderer = require "necro.render.level.ObjectRenderer"
local outlineFilter = require "necro.render.filter.OutlineFilter"
local perspective = require "necro.game.system.Perspective"
local render = require "necro.render.Render"
local vision = require "necro.game.vision.Vision"

local apColors = require("AP.scripts.utils.apColors")
local apPreview = require("AP.scripts.utils.apPreview")

-- Matches the fade getContentVisual applies to the item it is tracing.
local CONTENTS_ALPHA = 0.6

-- True once an AP location has actually been placed on the item.
local function isZoneCheck(item)
    return item.AP_locationItem.locationName ~= ""
end

-- `source` supplies the sprite, which for a character carrier is the character itself.
local function drawOutline(draw, item, source, visual, fade)
    local outline = apPreview.checkOutline(item)
    if not outline then return end

    visual = outlineFilter.getEntityVisual(source, visual, outlineFilter.Mode.BASIC)
    visual.color = apColors.fade(outline, fade or 1)
    visual.z = visual.z - 0.01

    draw(visual)
end

event.render.add("apLocationItemOutlines", "outlines", function()
    if not apPreview.outlinesEnabled() then return end

    local draw = render.getBuffer(render.Buffer.ATTACHMENT).draw

    for item in ecs.entitiesWithComponents({ "AP_locationItem", "visibility", "position", "sprite" }) do
        if isZoneCheck(item)
            and item.visibility.visible
            and item.sprite.visible
            and not vision.isPerspectiveShadowed(item.position.x, item.position.y)
        then
            drawOutline(draw, item, item)
        end
    end
end)

-- Mirrors "renderContents", which is what draws stored items under a monocle or the editor.
event.render.add("apLocationContentOutlines", { order = "contents", sequence = 1 }, function()
    if not apPreview.outlinesEnabled() then return end

    local draw = render.getBuffer(render.Buffer.OBJECT).draw

    for _, component in ipairs(perspective.getListAttribute(perspective.Attribute.CONTENTS_VISIBILITY_GROUPS)) do
        for container in ecs.entitiesWithComponents({ "storage", "visibility", "sprite", "positionalSprite", component }) do
            if container.visibility.visible and container.sprite.visible then
                local items = itemStorage.getItems(container)

                for i, item in ipairs(items) do
                    if item and item.sprite and item.AP_locationItem and isZoneCheck(item) then
                        local source = apPreview.spriteSource(item)
                        local visual = objectRenderer.getContentVisual(item, container)
                        visual.rect[1] = visual.rect[1] + (i - (#items + 1) * 0.5) * 12

                        drawOutline(draw, item, source,
                            apPreview.retextureContent(visual, item, source), CONTENTS_ALPHA)
                    end
                end
            end
        end
    end
end)
