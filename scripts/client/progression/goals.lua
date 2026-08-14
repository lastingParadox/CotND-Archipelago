local EXTRA_MODES = {
    [8] = "No Return",
    [9] = "Hard",
    [10] = "Phasing",
    [11] = "Randomizer",
    [12] = "Mystery",
    [13] = "No Beat",
    [20] = "Double Tempo",
    [23] = "Low Percent"
}

local apLog = require("AP.scripts.utils.log").apLog
local apClient = require("AP.scripts.client.client")
local apStorage = require("AP.scripts.client.storage")

local function attach(progression)
    function progression.addLevelCompleteChecks(checksList, character, collected)
        if apStorage.saveData.characterLocations[character] == nil then
            apStorage.saveData.characterLocations[character] = {}
        end
        local charData = apStorage.saveData.characterLocations[character]
        local locations = collected or {}

        for _, level in ipairs(checksList) do
            if level.zone and not charData[level.zone] then
                charData[level.zone] = true
            end

            table.insert(locations, character .. " - " .. level.name)
        end

        if collected then return end

        if #locations > 0 then
            progression.sendLocationChecks(locations)
        end

        progression.calculateGoalCompletion(true)
    end

    function progression.calculateGoalCompletion(sendGoal)
        if sendGoal == nil then sendGoal = true end

        local goalType = progression.getGoal()
        local goalAmount = progression.getGoalRequired() or 0
        local characterLocations = progression.getCharacterLocations() or {}

        local victoryTrigger = progression.getVictoryTrigger()
        local catalystComplete
        if victoryTrigger == "Boss Rush" then
            catalystComplete = (characterLocations["BossRush"] or {})["Completed"] == true
        elseif victoryTrigger == "Expensive Purchase" then
            catalystComplete = (characterLocations["ExpensivePurchase"] or {})["Completed"] == true
        elseif victoryTrigger == "Disabled" then
            -- No catalyst: meeting the goal alone triggers the victory packet.
            catalystComplete = true
        else
            catalystComplete = (characterLocations["Ensemble"] or {})["Completed"] == true
        end

        if goalType == "Golden Lute Shards" then
            local shardCount = apStorage.saveData.goldenLuteShards or 0
            local shardsGoalMet = shardCount >= goalAmount
            if sendGoal and shardsGoalMet and catalystComplete then
                apLog("GOAL ACHIEVED! " .. shardCount .. " / " .. goalAmount .. " (" .. goalType .. ")")
                apClient.sendPacket({ datatype = "Victory" })
            elseif sendGoal then
                apLog("Goal progress: " .. shardCount .. " / " .. goalAmount .. " (" .. goalType .. ") | " .. victoryTrigger .. ": " .. tostring(catalystComplete))
            end
            return shardCount, shardsGoalMet
        end

        if goalType == "Story" then
            local beaten = 0

            -- Same table the boss-check sender uses, so the two cannot drift.
            for _, entry in pairs(progression.specialBosses or {}) do
                for character in pairs(entry.characters) do
                    local locations = characterLocations[character]
                    if locations and locations[entry.name] == true then
                        beaten = beaten + 1
                    end
                end
            end

            local storyGoalMet = beaten >= goalAmount
            if sendGoal and storyGoalMet and catalystComplete then
                apLog("GOAL ACHIEVED! " .. beaten .. " / " .. goalAmount .. " (" .. goalType .. ")")
                apClient.sendPacket({ datatype = "Victory" })
            elseif sendGoal then
                apLog("Goal progress: " .. beaten .. " / " .. goalAmount .. " (" .. goalType .. ") | " .. victoryTrigger .. ": " .. tostring(catalystComplete))
            end
            return beaten, storyGoalMet
        end

        local completedSum = 0

        for _, characterLocation in pairs(characterLocations) do
            for key, value in pairs(characterLocation) do
                if value == true and (
                        (goalType == "Zones" and key:match("^Zone %d+$")) or
                        (goalType == "All Zones" and key == "All Zones")
                    ) then
                    completedSum = completedSum + 1
                end
            end
        end

        local zoneGoalMet = completedSum >= goalAmount

        if sendGoal and zoneGoalMet and catalystComplete then
            apLog("GOAL ACHIEVED! " .. completedSum .. " / " .. goalAmount .. " (" .. goalType .. ")")
            apClient.sendPacket({ datatype = "Victory" })
        elseif sendGoal then
            apLog("Goal progress: " .. completedSum .. " / " .. goalAmount .. " (" .. goalType .. ") | " .. victoryTrigger .. ": " .. tostring(catalystComplete))
        end

        return completedSum, zoneGoalMet
    end
end

return {
    EXTRA_MODES = EXTRA_MODES,
    attach = attach,
}
