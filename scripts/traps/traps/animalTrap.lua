local currentLevel = require("necro.game.level.CurrentLevel")
local gameDLC = require("necro.game.data.resource.GameDLC")
local player = require("necro.game.character.Player")
local rng = require("necro.game.system.RNG")
local turn = require("necro.cycles.Turn")
local object = require("necro.game.object.Object")

local ecs = require("system.game.Entities")

local possession = require("Sync.character.chaunter.Possession")

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local TrapHandler = require("AP.scripts.traps.trapHandler")

local animalTrapPossessors = {}
animalTrapPossessors = script.persist(function()
	return animalTrapPossessors
end)

local baseAnimals = {
	"Bat",
	"Bat2",
	"Bat3",
	"Monkey",
	"Monkey2",
	"Armadillo",
	"Armadillo2",
	"Mole",
	"Beetle",
	"Beetle2",
	"Hellhound",
	"Armadillo3",
	"Bat4",
	"Harpy",
	"Monkey3",
	"Monkey4",
	"Spider",
}

local amplifiedAnimals = {
	"Devil",
	"Devil2",
	"Gorgon",
	"Sync_ShockMonkey",
}

local function getAnimalPool()
	local pool = {}

	for i = 1, #baseAnimals do
		pool[#pool + 1] = baseAnimals[i]
	end

	if gameDLC.isAmplifiedLoaded() then
		for i = 1, #amplifiedAnimals do
			pool[#pool + 1] = amplifiedAnimals[i]
		end
	end

	return pool
end

local function removeValue(t, value)
	for i = 1, #t do
		if t[i] == value then
			table.remove(t, i)
			return
		end
	end
end

local function tryTransformPlayer(playerEntity, channel, pool)
	local remaining = {}
	for i = 1, #pool do
		remaining[#remaining + 1] = pool[i]
	end

	while #remaining > 0 do
		local animalType = rng.choice(remaining, channel)
		removeValue(remaining, animalType)

		local animal = object.spawn(animalType, playerEntity.position.x, playerEntity.position.y)
		if animal and possession.attach(playerEntity, animal) then
			animalTrapPossessors[playerEntity.id] = true
			return true
		end

		if animal and ecs.entityExists(animal.id) then
			object.delete(animal)
		end
	end

	return false
end

local function animalTrap(ev)
	local pool = getAnimalPool()
	if #pool == 0 then
		return false
	end

	local channel = rng.makeChannel(
		"AP-AnimalTrap",
		tostring(currentLevel.getSeed()),
		tostring(turn.getCurrentTurnID())
	)

	local transformedAny = false

	for _, entity in ipairs(player.getPlayerEntities()) do
		if entity and entity.playableCharacter then
			local transformed = tryTransformPlayer(entity, channel, pool)
			if transformed then
				transformedAny = true
				apFlyaways.addToFlyawayQueue({
					entity = entity,
					text = "Animal Trap!",
				})
			end
		end
	end

	return transformedAny
end

event.holderGetActionItem.add("APAnimalTrapSuppressEject", { order = "holster", sequence = 1, filter = "Sync_possessableAbility" },
	possession.wrapHandler(function(ev, possessor)
		if not possessor or not animalTrapPossessors[possessor.id] then
			return
		end

		if ev.action == ev.entity.Sync_possessableAbility.action then
			ev.item = nil
			ev.slotLabel = nil
		end
	end)
)

event.Sync_possessionDetach.add("APAnimalTrapClearPossessorFlag", { order = "possessorTarget" }, function(ev)
	if ev and ev.possessor then
		animalTrapPossessors[ev.possessor.id] = nil
	end
end)

event.gameStateLevel.add("APAnimalTrapClearPossessorFlags", "splitScreen", function(ev)
	for possessorID in pairs(animalTrapPossessors) do
		animalTrapPossessors[possessorID] = nil
	end
end)

TrapHandler.register("AnimalTrap", animalTrap)

return animalTrap
