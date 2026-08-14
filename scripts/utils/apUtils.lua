local gameSession = require "necro.client.GameSession"
local gameState = require "necro.client.GameState"
local singlePlayer = require "necro.client.SinglePlayer"

local apLobby = require("AP.scripts.level.apLobby")

local apUtils = {}

-- Every client simulates the run in lockstep, so anything that spawns or deletes
-- entities has to be driven by synced state at a synced moment. Off the network
-- that constraint doesn't exist and AP items can land the instant they arrive.
apUtils.isNetworked = function()
    return not singlePlayer.isActive()
end

apUtils.isAPContext = function(entity)
    if gameState.isInLobby() then
        return entity ~= nil and apLobby.isInLobby(entity)
    end
    local mode = gameSession.getCurrentMode().id
    return mode == "APAllZones" or mode == "APSingleZone" or mode == "APHintMode"
        or mode == "APEnsemble" or mode == "APBossRush"
end

return apUtils
