local damage = require("necro.game.system.Damage")
local player = require("necro.game.character.Player")

local apTrapStatus   = require("AP.scripts.ui.apTrapStatus")
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local doubleDamageActive = false
doubleDamageActive = script.persist(function()
    return doubleDamageActive
end)

apTrapStatus.register("DoubleDamageTrap", function()
    return doubleDamageActive and "Frail" or nil
end)

event.objectDealDamage.add("APDoubleDamageTrap", { order = "applyDamage", sequence = -1 }, function(ev)
    if not doubleDamageActive then return end
    if ev.suppressed then return end
    if ev.victim == nil then return end
    if not ev.victim.playableCharacter then return end
    if damage.Flag.check(ev.type, damage.Flag.SELF_DAMAGE) then return end
    ev.damage = ev.damage * 2
end)

event.gameStateLevel.add("APDoubleDamageTrapReset", { order = "resetLevelVariables" }, function()
    doubleDamageActive = false
end)

event.gameStateReset.add("APDoubleDamageTrapRunReset", { order = "resetRunVariables" }, function()
    doubleDamageActive = false
end)

TrapHandler.register("DoubleDamageTrap", makeSimpleTrap({
    flyawayText = "Double Damage!",
    setup = function()
        if doubleDamageActive then return false end
        doubleDamageActive = true
    end,
}))
