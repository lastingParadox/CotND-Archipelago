local action = require("necro.game.system.Action")
local collision = require("necro.game.tile.Collision")
local objectEvents = require("necro.game.object.ObjectEvents")
local ecs = require("system.game.Entities")

local utils = require("system.utils.Utilities")
local sign = utils.sign

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local TrapHandler = require("AP.scripts.traps.trapHandler")

local NONE_DIRECTION = action.Direction.NONE
local activeSlides = {}
activeSlides = script.persist(function()
	return activeSlides
end)

local function getSlipDirection(entity, queuedAction)
	if queuedAction then
		local dx, dy = action.getMovementOffset(queuedAction)
		if dx ~= 0 or dy ~= 0 then
			return queuedAction
		end
	end

	if entity.slide and entity.slide.direction and entity.slide.direction ~= NONE_DIRECTION then
		return entity.slide.direction
	end

	if entity.position and entity.previousPosition then
		local dx = sign(entity.position.x - entity.previousPosition.x)
		local dy = sign(entity.position.y - entity.previousPosition.y)
		if dx ~= 0 or dy ~= 0 then
			return action.move(dx, dy)
		end
	end

	if entity.facingDirection and entity.facingDirection.direction and entity.facingDirection.direction ~= NONE_DIRECTION then
		return entity.facingDirection.direction
	end

	return NONE_DIRECTION
end

local function bananaPeelTrap(ev)
	local trapSuccess = false

	for _, entry in ipairs(ev.actionQueue or {}) do
		local entity = entry.entity
		if not entity or not entity.playableCharacter then
			goto continue
		end

		if entity.grabbable and entity.grabbable.isGrabbed then
			goto continue
		end

		if not entity.slide then
			goto continue
		end

		local direction = getSlipDirection(entity, entry.action)
		if direction == NONE_DIRECTION then
			goto continue
		end

		if entity.slide.direction ~= direction then
			entity.slide.direction = direction
			objectEvents.fire("beginSlide", entity)
		end

		activeSlides[entity.id] = direction

		apFlyaways.addToFlyawayQueue({
			entity = entity,
			text = "Whoa!",
		})

		trapSuccess = true

		::continue::
	end

	return trapSuccess
end

event.turn.add("APBananaPeelSlideTick", { order = "floorHazards", sequence = 1 }, function(ev)
	for entityID, direction in pairs(activeSlides) do
		local entity = ecs.getEntityByID(entityID)
		if not entity or not entity.gameObject or not entity.gameObject.active or not entity.slide then
			activeSlides[entityID] = nil
			goto continue
		end

		entity.slide.direction = direction
		local dx, dy = action.getMovementOffset(direction)
		local collisionMask = collision.Group.SOLID
		if entity.slideOnSlipperyTile and entity.slideOnSlipperyTile.collisionMask then
			collisionMask = entity.slideOnSlipperyTile.collisionMask
		end

		if collision.check(entity.position.x + dx, entity.position.y + dy, collisionMask) then
			entity.slide.direction = NONE_DIRECTION
			objectEvents.fire("endSlide", entity)
			activeSlides[entityID] = nil
		end

		::continue::
	end
end)

event.gameStateLevel.add("APBananaPeelClearSlides", "statusEffects", function(ev)
	for entityID, _ in pairs(activeSlides) do
		local entity = ecs.getEntityByID(entityID)
		if entity and entity.slide then
			entity.slide.direction = NONE_DIRECTION
			objectEvents.fire("endSlide", entity)
		end
		activeSlides[entityID] = nil
	end
end)

TrapHandler.register("SlipTrap", bananaPeelTrap)

return bananaPeelTrap
