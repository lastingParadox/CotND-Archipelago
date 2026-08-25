local ecs = require "system.game.Entities"
local spellCharm = require "Sync.item.SpellCharm"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap
local trapHandler = require("AP.scripts.traps.trapHandler")

local ESCORT_SIZE = 3

---The floor's own residents, so the escort scales with the zone without a weight table.
local function localEnemies()
    local names = {}
    local seen = {}

    for entity in ecs.entitiesWithComponents({ "enemy", "position" }) do
        if not entity.boss and not seen[entity.name] and entity.Sync_charmable then
            seen[entity.name] = true
            names[#names + 1] = entity.name
        end
    end

    table.sort(names)

    return names
end

trapHandler.register("APCharmedEscort", makeSummonTrap({
    sound = "spellGeneral",
    min = ESCORT_SIZE,
    max = ESCORT_SIZE,
    spawnProps = false,
    checkGrabbed = false,
    requireSpawns = true,
    getVariants = localEnemies,
    onSpawn = function(spawned, _, playerEntity)
        spellCharm.charm(spawned, playerEntity)
    end,
}))

apItemFactory.define({
    name = "AP_CharmedEscort",
    texture = "items/charmed_escorts.png",
    hint = "Charmed Escort",
    flyaway = "Charmed Escort!",
    grant = {
        item = "APCharmedEscort",
        carrier = false,
        apply = function() trapHandler.deliver("APCharmedEscort") end,
    },
})
