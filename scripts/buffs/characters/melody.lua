local damage = require("necro.game.system.Damage")
local ecs = require("system.game.Entities")
local inventory = require("necro.game.item.Inventory")

local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local melody = {}

local THROWING_CHARM  = "Sync_CharmThrowing"
local BUFFED_LUTE_DAMAGE = 2

function melody.apply(entity)
    if not entity then return end
    if ecs.getEntityPrototype(THROWING_CHARM) then
        inventory.grant(THROWING_CHARM, entity)
    end
end

event.objectDealDamage.add("apMelodyLuteDamageBoost", {
    order = "baseIncrease",
}, function(ev)
    if not damage.Flag.check(ev.type, damage.Flag.GOLDEN_LUTE) then return end
    if not ev.entity or ev.entity.name ~= "Melody" then return end
    if not apUtils.isAPContext(ev.entity) then return end
    if not progression.getCharacterBuff("Melody") then return end
    ev.damage = math.max(ev.damage, BUFFED_LUTE_DAMAGE)
end)

function melody.revoke(entity) end

return melody
