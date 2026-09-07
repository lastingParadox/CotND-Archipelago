local ecs          = require "system.game.Entities"
local render       = require "necro.render.Render"
local timer        = require "system.utils.Timer"
local ui           = require "necro.render.UI"
local visualExtent = require "necro.render.level.VisualExtent"

local color        = require("AP.scripts.utils.apColors")

local apTrapStatus = {}

local DEFAULT_COLOR = color.trapStatus

-- [id] = function(entity) -> text|nil, color|nil
local providers = {}
local sortedIds = {}

---Registers a status indicator, polled per player each render frame for text, color or nil.
function apTrapStatus.register(id, provider)
    providers[id] = provider
    sortedIds = {}
    for key in pairs(providers) do
        table.insert(sortedIds, key)
    end
    table.sort(sortedIds)
end

event.render.add("apTrapStatusRender", { order = "playerNames", sequence = 2 }, function()
    local pulse = 0.8 + 0.2 * math.sin(timer.unixTimestamp() * 5)
    for entity in ecs.entitiesWithComponents({ "playableCharacter" }) do
        if entity.visibility and entity.visibility.visible then
            local x, y = visualExtent.getPosition(entity, 0.5, 0)
            local line = 0
            for _, id in ipairs(sortedIds) do
                local text, textColor = providers[id](entity)
                if text then
                    ui.drawText({
                        alignX = 0.5,
                        alignY = 1,
                        font = ui.Font.SMALL,
                        size = ui.Font.SMALL.size,
                        x = x,
                        y = y - 4 - line * (ui.Font.SMALL.size + 1),
                        text = text,
                        fillColor = color.fade(textColor or DEFAULT_COLOR, pulse),
                        shadowColor = color.TRANSPARENT,
                        outlineColor = color.BLACK,
                        buffer = render.Buffer.PLAYER_NAME,
                        anim = entity.shadowPosition and entity.shadowPosition.animID or nil,
                    })
                    line = line + 1
                end
            end
        end
    end
end)

return apTrapStatus
