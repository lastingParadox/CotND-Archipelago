local currency = require "necro.game.item.Currency"
local currentLevel = require "necro.game.level.CurrentLevel"
local player = require "necro.game.character.Player"

local apFlags = require("AP.scripts.utils.flags")
local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")

-- The balance sits on every player entity, since PriceTag checks the buyer's own currency.
local function syncDiamondCurrency()
    local amount = apStorage.saveData.diamonds or 0
    currency.setShared(apFlags.CURRENCY_AP_DIAMOND, amount)
    for _, entity in ipairs(player.getPlayerEntities()) do
        currency.set(entity, apFlags.CURRENCY_AP_DIAMOND, amount)
    end
end

local function attach(progression)
    function progression.grantGold(amount)
        -- A shared pool ignores the entity, so paying per player pays once per head.
        if currency.isShared(currency.Type.GOLD) then
            currency.add(nil, currency.Type.GOLD, amount)
            return
        end

        local entities = player.getPlayerEntities()
        if currentLevel.isLobby() then
            entities = { entities[1] }
        end

        for _, entity in ipairs(entities) do
            if entity then currency.add(entity, currency.Type.GOLD, amount) end
        end
    end

    function progression.getDiamonds()
        return apStorage.saveData.diamonds or 0
    end

    -- Replaces the balance outright (AP told us the authoritative value).
    function progression.setDiamonds(amount)
        apStorage.saveData.diamonds = math.max(0, math.floor(amount or 0))
        syncDiamondCurrency()
    end

    function progression.changeDiamonds(amount)
        if not amount then return end

        apStorage.saveData.diamonds = math.max(0, (apStorage.saveData.diamonds or 0) + amount)
        apLog("Saved diamonds changed by " .. amount .. ", new total: " .. apStorage.saveData.diamonds)
        apStorage.sendChangeDiamonds()
        syncDiamondCurrency()
    end

    function progression.getPotionTiers()
        return math.min(progression.getReceivedCount("APProgressivePotions"), 3)
    end

    function progression.getCoinMultiplierTier()
        return math.min(progression.getReceivedCount("APProgressiveCoinMultiplier"), 2)
    end

    function progression.getPotionMode()
        if not apStorage.saveData.buffs then
            apStorage.saveData.buffs = {}
        end
        if apStorage.saveData.buffs.potionMode == nil then
            apStorage.saveData.buffs.potionMode = progression.getPotionTiers()
        end
        return math.min(apStorage.saveData.buffs.potionMode, progression.getPotionTiers())
    end

    function progression.setPotionMode(mode)
        if not apStorage.saveData.buffs then
            apStorage.saveData.buffs = {}
        end
        apStorage.saveData.buffs.potionMode = math.max(0, math.min(mode, progression.getPotionTiers()))
        apStorage.sendChangeBuffs()
    end

    -- Raises an explicitly configured count alongside a newly received tier.
    function progression.addPotionTier()
        local buffs = apStorage.saveData.buffs
        if not buffs or buffs.potionMode == nil then return end
        buffs.potionMode = math.max(0, math.min(buffs.potionMode + 1, progression.getPotionTiers()))
        apStorage.sendChangeBuffs()
    end

    function progression.getHealth()
        return apStorage.saveData.health or 0
    end

    function progression.addHealth(amount)
        local originalAmount = apStorage.saveData.health or 0
        apStorage.saveData.health = originalAmount + amount

        if apStorage.saveData.health < 0 then
            apStorage.saveData.health = 0
        end

        -- If buffs.health has been explicitly configured, shift it by the same delta
        if apStorage.saveData.buffs and apStorage.saveData.buffs.health ~= nil then
            if amount > 0 then
                apStorage.saveData.buffs.health = apStorage.saveData.buffs.health + amount
            end
            -- Always clamp to [0, new health total] in case health was reduced.
            apStorage.saveData.buffs.health = math.max(0, math.min(
                apStorage.saveData.buffs.health,
                apStorage.saveData.health
            ))
        end

        apLog("Saved health changed by " .. amount .. ", new total: " .. apStorage.saveData.health)
        apStorage.sendChangeBuffs()
    end

    function progression.getBuffHealth()
        -- Lazily default to the current AP-earned health if not explicitly configured.
        if not apStorage.saveData.buffs then
            apStorage.saveData.buffs = {}
        end
        if apStorage.saveData.buffs.health == nil then
            apStorage.saveData.buffs.health = apStorage.saveData.health or 0
        end
        return apStorage.saveData.buffs.health
    end

    function progression.setBuffHealth(value)
        if not apStorage.saveData.buffs then
            apStorage.saveData.buffs = {}
        end
        apStorage.saveData.buffs.health = value
        apStorage.sendChangeBuffs()
    end

    function progression.getCharacterBuff(character)
        local buffs = apStorage.saveData.buffs
        if not buffs or not buffs.characterBuffs then return false end
        return buffs.characterBuffs[character] == true
    end

    function progression.setCharacterBuff(character, value)
        if not apStorage.saveData.buffs then
            apStorage.saveData.buffs = {}
        end
        if not apStorage.saveData.buffs.characterBuffs then
            apStorage.saveData.buffs.characterBuffs = {}
        end
        if value then
            apStorage.saveData.buffs.characterBuffs[character] = true
        else
            apStorage.saveData.buffs.characterBuffs[character] = nil
        end
        apStorage.sendChangeBuffs()
    end
end

return {
    attach = attach,
}
