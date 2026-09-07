local ecs     = require("system.game.Entities")
local gameDLC = require("necro.game.data.resource.GameDLC")
local object  = require("necro.game.object.Object")
local rng     = require("necro.game.system.RNG")

local possession = require("Sync.character.chaunter.Possession")

local trapSystem = require("AP.scripts.traps.trapSystem")

local MARV_CHANCE = 0.05

event.entitySchemaLoadNamedEntity.add("apMarvPossessable", { key = "Marv" }, function(ev)
	ev.entity.Sync_possessable = {}
	ev.entity.Sync_possessableGlow = {}
	ev.entity.Sync_possessableItemUser = {}
	ev.entity.controllable = {}
	ev.entity.inventory = {}
	ev.entity.equipment = {}
	ev.entity.invincibility = {}
	ev.entity.invincibilityBlinkEffect = {}
	ev.entity.beatDelay = {}
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
			return true
		end

		if animal and ecs.entityExists(animal.id) then
			object.delete(animal)
		end
	end

	return false
end

event.holderGetActionItem.add("APAnimalTrapSuppressEject",
	{ order = "holster", sequence = 1, filter = "Sync_possessableAbility" },
	possession.wrapHandler(function(ev, possessor)
		if not (possessor and trapSystem.isActive("AnimalTrap", possessor)) then
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
		trapSystem.stop("AnimalTrap", ev.possessor)
	end
end)

trapSystem.define({
	name      = "AnimalTrap",
	flyaway   = "Animal Trap!",
	perPlayer = true,
	stateful  = true,
	apply     = function(ctx)
		local pool = getAnimalPool()
		if #pool == 0 then return false end

		local transformed = rng.roll(MARV_CHANCE, ctx.channel)
			and tryTransformPlayer(ctx.entity, ctx.channel, { "Marv" })

		transformed = transformed or tryTransformPlayer(ctx.entity, ctx.channel, pool)

		if not transformed then return false end
	end,
})
