local extraMode = require "necro.game.data.modifier.ExtraMode"
local gfx = require "system.gfx.GFX"
local object = require("necro.game.object.Object")
local tile = require("necro.game.tile.Tile")

local apGameModeSelect = {}
local lobbyUtils = require("AP.scripts.utils.lobbyUtils")

local supportedModes = {
    8,
    9,
    10,
    11,
    12,
    13,
    20,
    23
}

function apGameModeSelect.generateExtraModesRoom(lobbyX, lobbyY)
    local columns = #supportedModes > 15 and 6 or 5
    local width = 2 * columns + 3
    local height = 2 * math.ceil(#supportedModes / columns) + 9
    local minX, maxX, minY, maxY = lobbyUtils.addRoom(width, height, -4, "Zone2")
    local centerX = math.floor((minX + maxX) / 2)

    for i, mode in ipairs(supportedModes) do
        local y = 2 * math.ceil(i / columns)
        local x = minX + 2 * ((i - 1) % columns + 1)
        local modeShrine = extraMode.Type.data[mode].shrine
        local i18nKey = extraMode.getStaircaseI18nKey(mode)

        if modeShrine then
            local textureWidth, textureHeight = gfx.getImageSize(modeShrine.texture)

            object.spawn("ShrineOfConfiguration", x, y, {
                AP_interactable = { ap = true },
                interactableToggleExtraMode = {
                    extraModeID = mode
                },
                sprite = {
                    texture = modeShrine.texture,
                    width = math.floor(textureWidth / 2),
                    height = math.floor(textureHeight / 2)
                },
                positionalSprite = {
                    offsetX = modeShrine.offsetX,
                    offsetY = modeShrine.offsetY
                },
                rowOrder = {
                    z = modeShrine.offsetZ
                },
                worldLabelTextPool = {
                    key = extraMode.isUnlocked(mode) and i18nKey or "label.lobby.stair.unknown"
                },
                worldLabelMaxWidth = {
                    width = 72
                },
                worldLabelTextColor = {
                    color = modeShrine.color
                },
                virtualItemShowWinStreakHUD = {
                    active = modeShrine.winStreak or false
                }
            })
        else
            lobbyUtils.addLabel(x, y, i18nKey)
            object.spawn(extraMode.Type.data[mode].triggerType or "TriggerAllZones", x, y, {
                trapStartRun = {
                    mode = extraMode.getGameModeID(mode),
                    options = {
                        extraMode = mode
                    }
                },
                trapRequireModeUnlock = {
                    mode = mode
                }
            })
        end
    end

    lobbyUtils.addDestination(lobbyX + 2, lobbyY + 2, centerX, 0, "label.lobby.stair.extraModes",
        "TriggerTravelPrimaryOnly")

    lobbyUtils.addDestination(centerX - 4, -1, lobbyX, lobbyY, "mod.AP.lobby.stairBack", "TriggerTravelPrimaryOnly")

    tile.setType(centerX + 4, -1, "LobbyStairs")
    local trap = object.spawn("TriggerStartRun", centerX + 4, -1)
    trap.trapStartRun.mode = "AP_APAllZones"
    lobbyUtils.addLabel(centerX + 4, -1, "label.lobby.stair.allZones")

    -- Interferes with vanilla lobby LabelExtraModeInfos, need to find a way to not override them
    -- object.spawn("LabelExtraModeInfo", centerX, -1, {
    --     worldLabel = {
    --         alignY = 0
    --     }
    -- })
    -- object.spawn("LabelExtraModeInfo", centerX, maxY - 1)
end

return apGameModeSelect
