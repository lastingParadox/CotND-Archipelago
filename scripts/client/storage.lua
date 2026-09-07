local trapHandler = require("AP.scripts.traps.trapHandler")

local apStorage = {
    saveData = {},
    seedName = false,
    playerName = false,
    slot = false,
}
apStorage = script.persist(function() return apStorage end)

function apStorage.ensureSaveDataTables()
    apStorage.saveData = apStorage.saveData or {}

    local defaults = {
        receivedItems = {},
        shopConsumedLocations = {},
        bannedItems = {},
        nextRunItems = {},
        characterLocations = {},
        unlockedNPCs = {},
        locationHints = {},
        npcHintLocations = {},
        buffs = {},
        unlockedBuffItems = {},
        chestLocations = {},
        chestConsumedLocations = {},
        chestUpgrades = {},
    }

    for key, value in pairs(defaults) do
        if type(apStorage.saveData[key]) ~= "table" then
            apStorage.saveData[key] = value
        end
    end
end

-- Run at load, so nothing reads these tables as nil before the first State packet lands.
apStorage.ensureSaveDataTables()

function apStorage.initSession(seedName, playerName, slot)
    apStorage.saveData = {}
    trapHandler.clearTraps()
    apStorage.seedName = seedName
    apStorage.playerName = playerName
    apStorage.slot = slot
    apStorage.ensureSaveDataTables()
end

-- Where the host's replicated state lands on a non-host.
function apStorage.applyHostState(seedName, playerName, slot, saveData)
    apStorage.seedName = seedName
    apStorage.playerName = playerName
    apStorage.slot = slot
    apStorage.saveData = saveData
    apStorage.ensureSaveDataTables()
end

local function getClient()
    local ok, apClient = pcall(require, "AP.scripts.client.client")
    if ok and apClient.isConnected() then return apClient end
    return nil
end

function apStorage.sendChangeDiamonds()
    local c = getClient()
    if not c then return end
    c.sendPacket({
        datatype = "ChangeDiamonds",
        value = apStorage.saveData.diamonds or 0,
    })
end

function apStorage.sendChangeBuffs()
    local c = getClient()
    if not c then return end
    c.sendPacket({
        datatype = "ChangeBuffs",
        buffs = apStorage.saveData.buffs or {},
    })
end

function apStorage.sendChangeRunItems()
    local c = getClient()
    if not c then return end
    c.sendPacket({
        datatype = "ChangeRunItems",
        bannedItems = apStorage.saveData.bannedItems or {},
        nextRunItems = apStorage.saveData.nextRunItems or {},
    })
end

function apStorage.getSaveData()
    return apStorage.saveData
end

return apStorage
