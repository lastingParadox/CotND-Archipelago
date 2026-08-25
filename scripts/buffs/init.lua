local bonusPotion = require("AP.scripts.buffs.apBonusPotion")
local characterBuffs = require("AP.scripts.buffs.characters.init")

local buffs = {}

-- Every buff room setting that shapes a starting inventory.
function buffs.apply(entity, progression)
    if not entity or not progression then return end

    characterBuffs.apply(entity, progression)
    bonusPotion.apply(entity)
end

return buffs
