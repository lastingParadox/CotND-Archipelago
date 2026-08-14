local color = require("system.utils.Color")
local ecs = require("system.game.Entities")
local grayscaleFilter = require("necro.render.filter.GrayscaleFilter")
local objectPreview = require("necro.render.level.ObjectPreview")
local playerList = require("necro.client.PlayerList")
local render = require("necro.render.Render")
local ui = require("necro.render.UI")
local utils = require("system.utils.Utilities")

local apPreview = {}

local SILHOUETTE_OUTLINE = color.rgb(114, 126, 133)
local INDICATOR_LOCKED = color.rgb(255, 87, 106)
local INDICATOR_DISABLED = color.rgb(120, 120, 120)
local INDICATOR_REQUIREMENT = color.rgb(255, 196, 87)

function apPreview.indicatorColor(disabled, missingRequirement)
    if disabled then return INDICATOR_DISABLED end
    if missingRequirement then return INDICATOR_REQUIREMENT end
    return INDICATOR_LOCKED
end

local function resolve(proto)
    return type(proto) == "string" and ecs.getEntityPrototype(proto) or proto
end

function apPreview.draw(proto, opts)
    proto = resolve(proto)
    if not proto then return end

    local entity = opts.entity
    local component = opts.component or (entity and entity.AP_preview) or {}
    local x = opts.x or entity.position.x
    local y = opts.y or entity.position.y

    local offsetY = (component.offsetY or 0) + (opts.offsetY or 0)
    local offsetZ = (component.offsetZ or 0) + (opts.offsetZ or 0)
    local offsetH = component.offsetH or 0
    local silhouette = opts.silhouette

    local args = {
        x = x,
        y = y,
        offsetX = component.offsetX,
        offsetY = offsetY,
        offsetZ = offsetZ,
        offsetH = offsetH,
        animationSpeed = opts.animationSpeed
            or (proto.previewAnimationSpeed and proto.previewAnimationSpeed.factor),
        color = silhouette and color.BLACK or nil,
        outline = silhouette and SILHOUETTE_OUTLINE
            or (component.outlineColor and component.outlineColor ~= color.TRANSPARENT and component.outlineColor)
            or nil,
        shadowCopyZ = component.shadowCopyZ,
        playerID = opts.playerID or playerList.getLocalPlayerID(),
    }

    if opts.previewArgs then
        utils.mergeTables(args, opts.previewArgs)
    end

    if opts.underlay then
        local underlay = resolve(opts.underlay)
        if underlay then
            objectPreview.draw(underlay, {
                x = x,
                y = y,
                color = silhouette and color.BLACK or nil,
                outline = silhouette and SILHOUETTE_OUTLINE or nil,
                animationSpeed = 0,
                AP_noHover = true,
                shadow = false,
                playerID = args.playerID,
            })
        end
    end

    if opts.grayscale then
        local buffer = render.getBuffer(render.Buffer.OBJECT)
        for _, visual in ipairs(objectPreview.getVisuals(proto, args)) do
            if visual.texture then
                visual.texture = grayscaleFilter.getPath(visual.texture)
            end
            buffer.draw(visual)
        end
    else
        objectPreview.draw(proto, args)
    end

    if opts.overlay then
        local overlay = opts.overlay
        local baseX, baseY = render.tileRenderingOrigin(x, y)
        local hoverY = args.hoverY or 0

        render.getBuffer(render.Buffer.OBJECT).draw({
            texture = overlay.texture,
            rect = { baseX + overlay.x, baseY + overlay.y + offsetY + hoverY,
                overlay.width, overlay.height },
            texRect = { 0, 0, overlay.width, overlay.height },
            z = baseY + offsetZ + hoverY,
            color = silhouette and color.BLACK or args.color,
        })
    end

    local indicator = opts.indicator
    if indicator == nil then indicator = silhouette end

    local rect = args.visual and args.visual.rect

    if indicator or opts.countText then
        local cx, cy = render.tileCenter(x, y)

        if indicator then
            local ix, iy, alignY = cx, cy + offsetH + offsetY, 1

            if proto.playableCharacterLockedIndicatorOffset then
                ix = cx + proto.playableCharacterLockedIndicatorOffset.offsetX
                iy = cy + (proto.playableCharacterLockedIndicatorOffset.offsetsY[args.frameX] or 0)
                    + (args.hoverY or 0) + offsetH + offsetY
            elseif rect then
                ix = rect[1] + rect[3] / 2
                iy = rect[2] + rect[4] / 2
                alignY = 0.5
            end

            ui.drawText({
                alignX = 0.5,
                alignY = alignY,
                text = "?",
                font = ui.Font.MEDIUM,
                fillColor = opts.indicatorColor or INDICATOR_LOCKED,
                shadowColor = color.TRANSPARENT,
                x = ix,
                y = iy,
                z = (args.visual and args.visual.z or cy + offsetZ) + 1,
                buffer = render.Buffer.OBJECT,
            })
        end

        if opts.countText then
            ui.drawText({
                alignX = -1,
                alignY = 0.5,
                text = opts.countText,
                font = ui.Font.SMALL,
                fillColor = color.WHITE,
                shadowColor = color.BLACK,
                x = rect and (rect[1] + rect[3] / 2) or cx,
                y = rect and (rect[2] + rect[4]) or (cy + offsetH + offsetY),
                z = (args.visual and args.visual.z or cy + offsetZ) + 1,
                buffer = render.Buffer.OBJECT,
            })
        end
    end

    return args
end

return apPreview
