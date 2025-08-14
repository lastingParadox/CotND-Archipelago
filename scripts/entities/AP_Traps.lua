local attack = require "necro.game.character.Attack"
local components = require("necro.game.data.Components")
local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local flyaway = require "necro.game.system.Flyaway"
local focus = require "necro.game.character.Focus"
local playerList = require "necro.client.PlayerList"
local player = require "necro.game.character.Player"
local sound = require "necro.audio.Sound"
local tile = require("necro.game.tile.Tile")

local apConnection = require("AP.scripts.ap_handlers.APConnection")
local apUtils = require("AP.scripts.ap_handlers.APUtils")

-- Component definition
components.register({
  AP_trapUnlock = {
    components.field.string("lockedText", "Complete zone %d to unlock!"),
    components.constant.string("apConnectionText", "AP Disconnected!"),
    components.constant.string("lockedTileType", "LobbyLockedStairs")
  },
})

-- Entity definition
customEntities.register({
  name = "TriggerAPTrap",
  position = {},
  trap = { targetFlags = attack.Flag.PLAYER_CONTROLLED },
  AP_trapUnlock = {},
  trapStartRun = { mode = "AP_APAllZones" },
})

local function errorNotification(entity, text, positionEntity)
	if text then
		if focus.check(entity, focus.Flag.FLYAWAY) then
			flyaway.create({
				offsetY = -7,
				entity = positionEntity or entity,
				text = text
			})
		end

		if focus.check(entity, focus.Flag.SOUND_PLAYBACK) then
			sound.playFromEntity("error", positionEntity or entity, {
				deduplicationID = entity.id,
				port = sound.Port.PERSONAL
			})
		end
	end
end

-- Helper to determine if a trap is unlocked
local function isUnlocked(entity)
  if not apConnection.connected then return false end
  if entity.trapStartRun.mode == "AP_APAllZones" then return true end

  local zone = entity.trapStartRun.zone
  local variance = -1
  if zone <= 0 then return false end

  local playerID = playerList.getLocalPlayerID()
  local playerEntity = player.getPlayerEntity(playerID)
  local character = apUtils.cotNDCharToAPLocation(playerEntity.name)

  if character == "Aria" and zone == 5 then
    return true
  elseif zone == 1 and character ~= "Aria" then
    return true
  else
    return apConnection.saveData.characterLocations[character]["Zone " .. tostring(zone + variance)]
  end
end

-- Spawn event
event.objectSpawn.add("apCheckTriggerUnlock", { filter = "AP_trapUnlock", order = "unlock" }, function(ev)
  local unlocked = isUnlocked(ev.entity)
  tile.setType(ev.x, ev.y, unlocked and "LobbyStairs" or ev.entity.AP_trapUnlock.lockedTileType)
end)

-- Visual update event
event.updateVisuals.add("apTrapVisuals", { order = "trapVisuals" }, function(ev)
  for entity in ecs.entitiesWithComponents({ "AP_trapUnlock" }) do
    local unlocked = isUnlocked(entity)
    local desiredTile = unlocked and "LobbyStairs" or entity.AP_trapUnlock.lockedTileType
    if tile.get(entity.position.x, entity.position.y) ~= desiredTile then
      tile.setType(entity.position.x, entity.position.y, desiredTile)
    end
  end
end)

event.trapTrigger.add("handleAPTrapUnlock", {
	filter = "AP_trapUnlock",
	order = "unlock"
}, function (ev)
	if ev.success and not isUnlocked(ev.trap) then
		ev.success = false

        local character = ev.victim.name
        local variance = character ~= "Aria" and -1 or 1

		local text = L.format(ev.trap.AP_trapUnlock.lockedText, (ev.trap.trapStartRun.zone or 0) + variance)

        if not apConnection.connected then text = L("AP Disconnected!") end

        errorNotification(ev.victim, text)
    end
end)
