local currency = require "necro.game.item.Currency"
local damage = require "necro.game.system.Damage"

local APFlags = {}

local deathLinkBit = damage.Flag.extend("AP_DEATH_LINK")
APFlags.DAMAGE_DEATH_LINK = damage.Flag.mask(
    deathLinkBit,
    damage.Flag.BYPASS_ARMOR,
    damage.Flag.BYPASS_INVINCIBILITY
)

APFlags.DAMAGE_AP_TRAP = damage.Flag.mask(
    damage.Flag.extend("AP_TRAP"),
    damage.Flag.BYPASS_ARMOR
)

APFlags.CURRENCY_AP_DIAMOND = currency.Type.extend("AP_diamond")

return APFlags
