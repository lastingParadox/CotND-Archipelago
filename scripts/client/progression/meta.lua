local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")

local function attach(progression)
    function progression.getSeedName()
        if next(apStorage.saveData) == nil then return "" end
        return apStorage.seedName
    end

    function progression.getPlayerName()
        if next(apStorage.saveData) == nil then return "" end
        return apStorage.playerName
    end

    function progression.getGoal()
        if next(apStorage.saveData) == nil then return "All Zones" end
        return apStorage.saveData.goal
    end

    function progression.getGoalRequired()
        if next(apStorage.saveData) == nil then return 6 end
        return apStorage.saveData.goalRequired
    end

    -- Set of floor numbers that are checks, resolved by the client from Zone Progress Checks.
    function progression.getZoneProgressFloors()
        return apStorage.saveData.zoneProgressFloors or { [2] = true }
    end

    -- Minutes this character's All Zones run must finish within; 0 is untimed.
    function progression.getSpeedrunTime(character)
        local times = apStorage.saveData.speedrunTimes or {}
        return times[character] or 0
    end

    function progression.getEnabledDLCs()
        return apStorage.saveData.enabledDLCs
    end

    function progression.isDLCEnabled(dlc)
        local dlcs = apStorage.saveData.enabledDLCs or {}
        return dlcs[dlc] == true
    end

    function progression.getDeathlink()
        return apStorage.saveData.deathlink
    end

    function progression.getShrineChecks()
        return apStorage.saveData.shrineChecks == true
    end

    -- Ordered {id, category} list of everything this slot can receive.
    function progression.getItemRoom()
        return apStorage.saveData.itemRoom or {}
    end

    function progression.getItemChecks()
        return apStorage.saveData.itemChecks == true
    end

    function progression.getFlawlessChestChecks()
        return apStorage.saveData.flawlessChestChecks == true
    end

    -- Percent chance an acquisition carries its zone's check rather than its own loot.
    function progression.getItemChance()
        return apStorage.saveData.itemChance or 50
    end

    function progression.getDeathlinkTrigger()
        return apStorage.saveData.deathlinkTrigger or "Game Over"
    end

    -- 0 disables the conversion; nil means a save from before the option existed.
    function progression.getGoldToDiamondRate()
        local rate = apStorage.saveData.goldToDiamondRate
        if rate == nil then return 50 end
        return rate
    end

    function progression.getExtraModes(mode)
        local modes = apStorage.saveData.extraModes or {}
        if mode then
            return modes[mode]
        end
        return modes
    end

    function progression.enableExtraMode(mode)
        if not mode then return end

        apLog("Extra mode enabled: " .. mode)
        apStorage.saveData.extraModes[mode] = true
    end

    function progression.getVictoryTrigger()
        if next(apStorage.saveData) == nil then return "Ensemble" end
        return apStorage.saveData.victoryTrigger or "Ensemble"
    end

    function progression.getExpensivePurchasePrice()
        return apStorage.saveData.expensivePurchasePrice or 150
    end

    function progression.unlockBuffItem(charName)
        if not charName or charName == "" then return end
        apStorage.saveData.unlockedBuffItems = apStorage.saveData.unlockedBuffItems or {}
        apStorage.saveData.unlockedBuffItems[charName] = true
    end

    -- Whether the buff item is held, not whether the buff is switched on at the shrine.
    function progression.hasBuffItem(charName)
        local unlocked = apStorage.saveData.unlockedBuffItems or {}
        return unlocked[charName] == true
    end
end

return {
    attach = attach,
}
