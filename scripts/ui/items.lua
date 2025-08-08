local collision = require("necro.game.tile.Collision")
local color = require("system.utils.Color")
local ecs = require("system.game.Entities")
local focus = require("necro.game.character.Focus")
local render = require("necro.render.Render")
local settingsStorage = require("necro.config.SettingsStorage")
local ui = require("necro.render.UI")
local utils = require("system.utils.Utilities")
local visualExtent = require("necro.render.level.VisualExtent")

local apConnection = require("AP.scripts.ap_handlers.APConnection")

local colors = {
    [0] = color.rgb(125, 238, 238), -- filler
    [1] = color.rgb(175, 153, 239), -- progression
    [2] = color.rgb(105, 134, 223), -- useful
}

local playerColor = color.rgb(238, 125, 238)

local function isFocusedEntityClose(entity, itemHintsDistance)
    for _, focusedEntity in ipairs(focus.getAll(focus.Flag.TEXT_LABEL)) do
        local distance = utils.distanceL1(focusedEntity.position.x - entity.position.x,
            focusedEntity.position.y - entity.position.y)

        if distance > 0 and distance <= itemHintsDistance then
            return true
        end
    end
end

local function hintsVisibleFor(entity)
    return entity.visibility.visible and (not entity.silhouette or not entity.silhouette.active)
end

local function renderText(args)
    args.buffer = args.buffer or render.Buffer.TEXT_LABEL
    args.font = args.font or ui.Font.SMALL
    args.fillColor = args.fillColor or color.rgb(255, 255, 255)
    args.z = args.z or args.y - 48
    args.alignX = 0.5
    args.alignY = args.alignY or 1

    return ui.drawText(args)
end

local function renderHintOrName(entity, labelField, itemHints, itemHintsDistance, itemNames)
    local text = nil
    local label = entity[labelField]

    if itemHints and label.text ~= "" and isFocusedEntityClose(entity, itemHintsDistance) then
        text = label.text
    elseif itemNames then
        text = entity.friendlyName and entity.friendlyName.name or entity.name
    else
        return
    end

    local adjacentItems = 0

    for dx = 1, itemNames and 5 or math.min(itemHintsDistance - 1, 5) do
        if not collision.check(entity.position.x - dx, entity.position.y, collision.Type.ITEM) then
            break
        end

        adjacentItems = adjacentItems + 1
    end

    local x, y = visualExtent.getTileCenter(entity)

    if (entity.AP_player and entity.AP_player.name and entity.AP_player.name ~= apConnection.saveData.slotName) then
        renderText({
            text = entity.AP_player.name .. "'s",
            x = x,
            y = y + (label.offsetY - 7) - 8 * adjacentItems,
            fillColor = playerColor,
            buffer = render.Buffer.TEXT_LABEL_FRONT
        })
    end

    return renderText({
        text = text,
        x = x,
        y = y + label.offsetY - 8 * adjacentItems,
        fillColor = colors[(entity.AP_itemClass and entity.AP_itemClass.classification) or 0] or color.rgb(255, 255, 255),
        buffer = render.Buffer.TEXT_LABEL_FRONT
    })
end

event.render.override("renderItemHintLabels", { sequence = 1 }, function(func, ev)
    local itemHints = settingsStorage.get("video.itemHints")
    local itemHintsDistance = settingsStorage.get("video.itemHintsDistance")
    local itemNames = settingsStorage.get("video.itemNames")

    if itemHints or itemNames then
        for entity in ecs.entitiesWithComponents({
            "AP_itemHintLabel",
        }) do
            if hintsVisibleFor(entity) then
                renderHintOrName(entity, "AP_itemHintLabel", itemHints, itemHintsDistance, itemNames)
            end
        end

        for entity in ecs.entitiesWithComponents({
            "itemHintLabel",
            "visibility"
        }) do
            if hintsVisibleFor(entity) and not (entity.AP_itemHintLabel and entity.AP_itemHintLabel.text and entity.AP_itemHintLabel.text ~= "") then
                renderHintOrName(entity, "itemHintLabel", itemHints, itemHintsDistance, itemNames)
            end
        end

        if itemNames then
            for entity in ecs.entitiesWithComponents({
                "itemCurrencyLabel",
                "itemStack",
                "visibility"
            }) do
                local label = entity.itemCurrencyLabel

                if hintsVisibleFor(entity) and label.minimumQuantity <= entity.itemStack.quantity then
                    local x, y = visualExtent.getTileCenter(entity)

                    renderText({
                        text = entity.itemStack.quantity .. label.suffix,
                        x = x,
                        y = y - 12,
                        buffer = render.Buffer.TEXT_LABEL_FRONT
                    })
                end
            end
        end
    end
end)

event.entitySchemaLoadItem.add("addAPComponents", { order = "common" }, function(ev)
    ev.entity.AP_itemHintLabel = {}
    ev.entity.AP_player = {}
    ev.entity.AP_itemClass = {}
end)
