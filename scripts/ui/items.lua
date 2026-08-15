local collision = require("necro.game.tile.Collision")
local color = require("system.utils.Color")
local ecs = require("system.game.Entities")
local focus = require("necro.game.character.Focus")
local map = require "necro.game.object.Map"
local render = require("necro.render.Render")
local settingsStorage = require("necro.config.SettingsStorage")
local ui = require("necro.render.UI")
local utils = require("system.utils.Utilities")
local visualExtent = require("necro.render.level.VisualExtent")

local apItems = require("AP.scripts.utils.apItems")
local progression = require("AP.scripts.client.progression")

local colors = {
    filler      = color.rgb(125, 238, 238),
    progression = color.rgb(175, 153, 239),
    useful      = color.rgb(105, 134, 223),
    trap        = color.rgb(250, 128, 114),
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
    return entity.visibility and entity.visibility.visible and (not entity.silhouette or not entity.silhouette.active)
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

    -- Count how many adjacent items exist
    local adjacentItems = 0
    for dx = 1, itemNames and 5 or math.min(itemHintsDistance - 1, 5) do
        if not collision.check(entity.position.x - dx, entity.position.y, collision.Type.ITEM) then
            break
        end
        adjacentItems = adjacentItems + 1
    end

    local slotName = progression.getPlayerName()
    local hasPlayerLabel = entity.AP_player
        and entity.AP_player.name ~= ""
        and entity.AP_player.name ~= slotName

    -- Account for neighboring AP items (so full label blocks don't collide)
    for dx = 1, adjacentItems do
        local leftEntityID = map.firstWithComponent(entity.position.x - dx, entity.position.y, "AP_player")
        if leftEntityID then
            local leftEntity = ecs.getEntityByID(leftEntityID)
            if leftEntity
                and leftEntity.AP_player
                and leftEntity.AP_player.name ~= ""
                and leftEntity.AP_player.name ~= slotName
            then
                adjacentItems = adjacentItems + 1
            end
        end
    end

    local x, y = visualExtent.getTileCenter(entity)
    -- Reading a field a component lacks errors rather than returning nil, and only the
    -- AP label carries an offsetX.
    x = x + (labelField == "AP_hintLabel" and label.offsetX or 0)
    local yOffsetBase = label.offsetY - 8 * adjacentItems

    -- Player label should sit just above the item name, not an entire item height above
    local PLAYER_LABEL_GAP = 7 -- tighter spacing within same item

    if hasPlayerLabel then
        renderText({
            text = entity.AP_player.name .. "'s",
            x = x,
            y = y + yOffsetBase - PLAYER_LABEL_GAP,
            fillColor = playerColor,
            buffer = render.Buffer.TEXT_LABEL_FRONT
        })
    end
    local colorVar = entity.AP_itemClass
        and colors[apItems.itemClassName(entity.AP_itemClass.classification)]
        or color.rgb(255, 255, 255)

    if not hasPlayerLabel then
        colorVar = color.rgb(255, 255, 255)
    end

    return renderText({
        text = text,
        x = x,
        y = y + yOffsetBase,
        fillColor = colorVar,
        buffer = render.Buffer.TEXT_LABEL_FRONT
    })
end


event.render.override("renderItemHintLabels", { sequence = 1 }, function(func, ev)
    local itemHints = settingsStorage.get("video.itemHints")
    local itemHintsDistance = settingsStorage.get("video.itemHintsDistance")
    local itemNames = settingsStorage.get("video.itemNames")

    if itemHints or itemNames then
        for entity in ecs.entitiesWithComponents({
            "AP_hintLabel",
        }) do
            if hintsVisibleFor(entity) and entity.AP_hintLabel.text ~= "" then
                renderHintOrName(entity, "AP_hintLabel", itemHints, itemHintsDistance, itemNames)
            end
        end

        for entity in ecs.entitiesWithComponents({
            "itemHintLabel",
            "visibility"
        }) do
            if hintsVisibleFor(entity) and not (entity.AP_hintLabel and entity.AP_hintLabel.text and entity.AP_hintLabel.text ~= "") then
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
