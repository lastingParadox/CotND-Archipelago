local customEntities = require("necro.game.data.CustomEntities")
local ecs     = require("system.game.Entities")
local gameDLC = require("necro.game.data.resource.GameDLC")
local itemBan = require("necro.game.item.ItemBan")
local object  = require("necro.game.object.Object")
local rng     = require("necro.game.system.RNG")
local utils   = require("system.utils.Utilities")

local possession = require("Sync.character.chaunter.Possession")

local trapSystem = require("AP.scripts.traps.trapSystem")

local MARV_CHANCE = 0.05
local MARV_POSSESSION_BEATS = 64

local MARV_VISUALS = {
	"sprite", "positionalSprite", "spriteSheet", "normalAnimation", "visualExtent",
	"shadow", "shadowPosition", "facingMirrorX", "setFacingOnMove", "tween",
}

local SLIME_EXTRAS = {
	"parityAnimation", "tellAnimation", "blinkAnimation", "innateAttack",
	"dropCurrencyOnDeath", "enemyUnlockOnDeath", "bloodColor", "setFacingFromPattern",
}

customEntities.extend({
	name       = "TrapMarv",
	template   = customEntities.template.enemy("slime", 3),
	components = {
		friendlyName = { name = "Marv" },
		editorHidden = {},
	},
})

-- Dresses the possessable slime body as a harmless Marv.
event.entitySchemaGenerate.add("apDressTrapMarv", { order = "customEntities", sequence = 101 }, function(ev)
	local marv, body
	for _, entity in ipairs(ev.entityTypes) do
		if entity.name == "Marv" then
			marv = entity
		elseif entity.name == "AP_TrapMarv" then
			body = entity
		end
	end
	if not (marv and body) then return end

	for _, component in ipairs(MARV_VISUALS) do
		body[component] = marv[component] and utils.fastCopy(marv[component]) or nil
	end
	for _, component in ipairs(SLIME_EXTRAS) do
		body[component] = nil
	end
	utils.mergeTablesRecursive(body, { inventoryBannedItems = { components = { weapon = itemBan.Type.FULL } } })
	body.Sync_possessableTimer = { remainingBeats = MARV_POSSESSION_BEATS, beatsAfterDamage = 0 }

	for key in pairs(body) do
		if key:sub(1, 5) == "voice" then body[key] = nil end
	end
	for key, value in pairs(marv) do
		if key:sub(1, 5) == "voice" then body[key] = utils.fastCopy(value) end
	end
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
		if animal and not animal.gameObject.despawned and possession.attach(playerEntity, animal) then
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
	guard     = function(ctx)
		for _, entry in ipairs(ctx.players) do
			if possession.getPossessor(entry.entity) then return false end
		end
	end,
	apply     = function(ctx)
		local pool = getAnimalPool()
		if #pool == 0 then return false end

		local transformed = rng.roll(MARV_CHANCE, ctx.channel)
			and tryTransformPlayer(ctx.entity, ctx.channel, { "AP_TrapMarv" })

		transformed = transformed or tryTransformPlayer(ctx.entity, ctx.channel, pool)

		if not transformed then return false end
	end,
})
