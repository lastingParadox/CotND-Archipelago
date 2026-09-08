local gameSession = require "necro.client.GameSession"
local gameState = require "necro.client.GameState"
local rng = require "necro.game.system.RNG"
local singlePlayer = require "necro.client.SinglePlayer"

local apLobby = require("AP.scripts.level.apLobby")

local apUtils = {}

-- Spawning or deleting entities off the network needs no synced delivery; on it, everything does.
apUtils.isNetworked = function()
    return not singlePlayer.isActive()
end

local AP_MODES = {
    APAllZones = true,
    APSingleZone = true,
    APHintMode = true,
    APEnsemble = true,
    APBossRush = true,
}

-- For the mode a run is being generated for, which is not yet the current one.
apUtils.isAPMode = function(modeID)
    return AP_MODES[modeID] == true
end

apUtils.isAPContext = function(entity)
    if gameState.isInLobby() then
        return entity ~= nil and apLobby.isInLobby(entity)
    end
    return apUtils.isAPMode(gameSession.getCurrentMode().id)
end

---@return userdata channel
function apUtils.hashChannel(...)
    local key = table.concat({ ... }, "-")
    local seed = 0

    for i = 1, #key do
        seed = (seed * 31 + key:byte(i)) % 2147483647
    end

    return rng.makeChannel(seed)
end

return apUtils
