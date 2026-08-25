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

-- Straight away, not just once a session starts: connecting moves the players before the
-- State packet lands, and anything that fires in between -- a level completing, a check
-- being recorded -- reads these tables and would otherwise find nil.
apStorage.ensureSaveDataTables()

function apStorage.initSession(seedName, playerName, slot)
    apStorage.saveData = {}
    trapHandler.clearTraps()
    apStorage.seedName = seedName
    apStorage.playerName = playerName
    apStorage.slot = slot
    apStorage.ensureSaveDataTables()
end

-- Non-hosts have no socket of their own; the host's replicated state lands here.
-- A setter because requiring modules hands out a read-only proxy.
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
