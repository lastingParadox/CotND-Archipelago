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

    -- Required here rather than at module scope: the cycle through apCharacters must stay run-time.
    function progression.isCharacterPlayable(character)
        local apCharacters = require("AP.scripts.utils.apCharacters")
        local startingCharacter = progression.getStartingCharacter()

        if startingCharacter and not progression.hasCharacterRoomKey() and character ~= startingCharacter then
            return false
        end

        return apCharacters.isCharacterPlayable(apCharacters.apLocationToCotNDChar(character))
    end

    function progression.getPlayableCharacters()
        local result = {}

        for character in pairs(characterCache) do
            if progression.isCharacterPlayable(character) then
                result[#result + 1] = character
            end
        end

        table.sort(result)

        return result
    end

    function progression.getCharacterBlacklist(character)
        local blacklist = apStorage.saveData.characterBlacklist or {}
        if character then
            return blacklist[character]
        end
        return blacklist
    end

    -- "item_only", "required_items_soft", or "required_items_hard".
    function progression.getCharacterUnlocks()
        return apStorage.saveData.characterUnlocks or "item_only"
    end

    function progression.requiresCharacterItems()
        return progression.getCharacterUnlocks() ~= "item_only"
    end

    function progression.getIncludeUniqueItems()
        return apStorage.saveData.includeUniqueItems
    end

    -- { normal = { "CharmNazar", ... }, unique = { ... } } for one CotND character.
    function progression.getCharacterRequirements(name)
        local requirements = apStorage.saveData.characterRequirements or {}
        return requirements[name] or {}
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

    function progression.getCagedNPCs(npc)
        local npcs = apStorage.saveData.cagedNPCs or {}
        if npc then
            return npcs[npc]
        end
        return npcs
    end

    function progression.addFreedNpcCheck(npc)
        if not npc or npc == "" then return end

        apLog("NPC freed: " .. npc)
        apStorage.saveData.cagedNPCs[npc] = apStorage.saveData.cagedNPCs[npc] or {}
        apStorage.saveData.cagedNPCs[npc].freed = true

        progression.sendLocationChecks("Caged " .. npc)
    end
end

return {
    attach = attach,
}
