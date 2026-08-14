local color        = require "system.utils.Color"
local ecs          = require "system.game.Entities"
local render       = require "necro.render.Render"
local timer        = require "system.utils.Timer"
local ui           = require "necro.render.UI"
local visualExtent = require "necro.render.level.VisualExtent"

local apTrapStatus = {}

local DEFAULT_COLOR = color.rgb(255, 96, 96)

-- [id] = function(entity) -> text|nil, color|nil
local providers = {}
local sortedIds = {}

---Registers a persistent status indicator for a trap effect. The provider is
---polled every render frame per player: return the indicator text (and an
---optional color) while the effect is active on that player, or nil while it
---is not. Polling the trap's own state keeps the indicator in sync with the
---effect without any set/clear bookkeeping.
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
