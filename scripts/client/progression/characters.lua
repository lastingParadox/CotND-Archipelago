local apLog = require("AP.scripts.utils.log").apLog
local apStorage = require("AP.scripts.client.storage")

local characterCache = {}
characterCache = script.persist(function() return characterCache end)

local function attach(progression)
    function progression.getCharacters(character)
        if character then
            return characterCache[character]
        end
        return characterCache
    end

    function progression.markCharacterUnlocked(charId)
        if charId then
            characterCache[charId] = true
        end
    end

    function progression.rebuildCharacterCache(apCharacters)
        characterCache = {}
        for _, entry in pairs(apStorage.saveData.receivedItems or {}) do
            if entry.itemType == "character" and entry.charId then
                characterCache[apCharacters.cotNDCharToAPLocation(entry.charId)] = true
            elseif not entry.itemType then
                -- Fallback for entries without itemType
                local id = entry.item
                if id and apCharacters.isCharacter(id) then
                    characterCache[apCharacters.cotNDCharToAPLocation(id)] = true
                end
            end
        end
    end

    function progression.getCharacterBlacklist(character)
        local blacklist = apStorage.saveData.characterBlacklist or {}
        if character then
            return blacklist[character]
        end
        return blacklist
    end

    function progression.getCharacterUnlocks()
        return apStorage.saveData.characterUnlocks
    end

    function progression.getIncludeUniqueItems()
        return apStorage.saveData.includeUniqueItems
    end

    function progression.hasCharacterRoomKey()
        return apStorage.saveData.characterRoomKey == true
    end

    function progression.unlockCharacterRoom()
        if apStorage.saveData.characterRoomKey == true then return end

        apLog("Character room key acquired")
        apStorage.saveData.characterRoomKey = true
    end

    function progression.getStartingCharacter()
        return apStorage.saveData.startingCharacter
    end

    function progression.setStartingCharacter(character)
        if not character or character == "" then return end
        if apStorage.saveData.startingCharacter then return end

        apStorage.saveData.startingCharacter = character
    end

    function progression.getCharacterLocations(character)
        local locations = apStorage.saveData.characterLocations or {}
        if character then
            return locations[character]
        end
        return locations
    end

    function progression.getUnlockedNPCs(npc)
        local npcs = apStorage.saveData.unlockedNPCs or {}
        if npc then
            return npcs[npc]
        end
        return npcs
    end

    function progression.addFreedNpcCheck(npc)
        if not npc or npc == "" then return end

        apLog("NPC freed: " .. npc)
        apStorage.saveData.unlockedNPCs[npc] = apStorage.saveData.unlockedNPCs[npc] or {}
        apStorage.saveData.unlockedNPCs[npc].unlocked = true

        progression.sendLocationChecks("Caged " .. npc)
    end
end

return {
    attach = attach,
}
