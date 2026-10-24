local ecs = require("system.game.Entities")
local grayscaleFilter = require("necro.render.filter.GrayscaleFilter")
local objectPreview = require("necro.render.level.ObjectPreview")
local playerList = require("necro.client.PlayerList")
local render = require("necro.render.Render")
local settings = require("necro.config.Settings")
local ui = require("necro.render.UI")
local utils = require("system.utils.Utilities")

local color = require("AP.scripts.utils.apColors")

local apPreview = {}

local OUTLINE_ALPHA = 0.85

-- Declared here, since a settings global is bound to the script that assigns it.
apShowLocationOutlines = settings.user.bool({
    id = "AP.video.locationOutlines",
    name = "Outline location checks",
    default = true,
})

function apPreview.outlinesEnabled()
    return apShowLocationOutlines
end

function apPreview.indicatorColor(disabled, missingRequirement)
    if disabled then return color.disabled end
    if missingRequirement then return color.requirement end
    return color.locked
end

-- The prototype whose sprite stands in for an item; a character carrier draws its character.
function apPreview.spriteSource(item)
    if not item.AP_character then return item end

    local name = item.AP_character.name
    if name == "" then return item end

    return ecs.getEntityPrototype(name) or item
end

-- Points a content visual at `source`'s sprite, anchored bottom-centre on the item's own.
function apPreview.retextureContent(visual, item, source)
    if source == item or not source.sprite then return visual end

    local sprite = source.sprite

    visual.texture = sprite.texture
    visual.texRect[1] = sprite.textureShiftX
    visual.texRect[2] = sprite.textureShiftY
    visual.texRect[3] = sprite.width
    visual.texRect[4] = sprite.height

    visual.rect[1] = visual.rect[1] - (sprite.width - item.sprite.width) / 2
    visual.rect[2] = visual.rect[2] - (sprite.height - item.sprite.height)
    visual.rect[3] = sprite.width
    visual.rect[4] = sprite.height

    return visual
end

-- The colour a mid-run check outlines in, or nil when it is not one.
function apPreview.checkOutline(item)
    if not (item.AP_locationItem and item.AP_locationItem.locationName ~= "") then return nil end
    if not apShowLocationOutlines then return nil end

    return color.fade(
        color.forClassification(item.AP_locationItem.classification), OUTLINE_ALPHA)
end

-- Forces a sprite frame on the preview, for prototypes without a normalAnimation to pick one.
event.objectPreview.add("apPreviewFrame", { filter = "sprite", order = "animation", sequence = 1 }, function(ev)
    if ev.AP_frameX and ev.visual then
        ev.visual.texRect[1] = (ev.AP_frameX - 1) * ev.entity.sprite.width
    end
end)

local function scaleFromBottom(rect, scale)
    rect[1] = rect[1] + rect[3] * (1 - scale) / 2
    rect[2] = rect[2] + rect[4] * (1 - scale)
    rect[3] = rect[3] * scale
    rect[4] = rect[4] * scale
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
        outline = silhouette and color.silhouette
            or (component.outlineColor and component.outlineColor ~= color.TRANSPARENT and component.outlineColor)
            or nil,
        shadowCopyZ = component.shadowCopyZ,
        playerID = opts.playerID or playerList.getLocalPlayerID(),
        AP_frameX = opts.frameX,
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
                outline = silhouette and color.silhouette or nil,
                animationSpeed = 0,
                AP_noHover = true,
                shadow = false,
                playerID = args.playerID,
            })
        end
    end

    if opts.grayscale or opts.scale then
        local buffer = render.getBuffer(render.Buffer.OBJECT)
        for _, visual in ipairs(objectPreview.getVisuals(proto, args)) do
            if opts.grayscale and visual.texture then
                visual.texture = grayscaleFilter.getPath(visual.texture)
            end
            if opts.scale then
                scaleFromBottom(visual.rect, opts.scale)
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
            z = baseY + offsetZ + hoverY + (overlay.z or 0),
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
                fillColor = opts.indicatorColor or color.locked,
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
