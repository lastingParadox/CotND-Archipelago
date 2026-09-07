local damage = require("necro.game.system.Damage")

local trapSystem = require("AP.scripts.traps.trapSystem")

event.objectDealDamage.add("APDoubleDamageTrap", { order = "applyDamage", sequence = -1 }, function(ev)
    if not trapSystem.isActive("DoubleDamageTrap") then return end
    if ev.suppressed then return end
    if ev.victim == nil then return end
    if not ev.victim.playableCharacter then return end
    if damage.Flag.check(ev.type, damage.Flag.SELF_DAMAGE) then return end

    ev.damage = ev.damage * 2
end)

trapSystem.define({
    name     = "DoubleDamageTrap",
    flyaway  = "Double Damage!",
    status   = "Frail",
    -- The flag is the whole effect, so it has to outlive the trigger.
    stateful = true,
    start    = function() return true end,
})
