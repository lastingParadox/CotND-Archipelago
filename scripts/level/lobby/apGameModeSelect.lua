local extraMode = require "necro.game.data.modifier.ExtraMode"
local gfx = require "system.gfx.GFX"
local marker = require "necro.game.tile.Marker"
local object = require("necro.game.object.Object")

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

function apGameModeSelect.generateExtraModesRoom(originX, lobbyY)
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
                AP_interactableExtraModeLobby = {
                    extraMode = mode
                },
                AP_interactableExtraModePreview = {},
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

    lobbyUtils.addDestination(originX, lobbyY, centerX, 0, "label.lobby.stair.extraModes",
        "TriggerTravelPrimaryOnly")

    local apLobbyX, apLobbyY = marker.lookUpFirst(marker.Type.AP_SPAWN)
    lobbyUtils.addDestination(centerX - 4, -1, apLobbyX, apLobbyY, "mod.AP.lobby.stairBack", "TriggerTravelPrimaryOnly")

    object.spawn("AP_ZonesStairLabel", centerX + 4, -1)
    object.spawn("AP_TriggerAPTrap", centerX + 4, -1)

    -- The top label carries the opening blurb; the bottom stays hidden until a shrine is near.
    object.spawn("AP_LabelExtraModeInfo", centerX, -1, {
        worldLabel = {
            alignY = 0
        },
        worldLabelFade = {
            falloff = 0.0001,
            maxDistance = 10000
        }
    })
    object.spawn("AP_LabelExtraModeInfo", centerX, maxY - 1, {
        worldLabelFade = {
            maxDistance = 0
        }
    })
end

return apGameModeSelect
