local apUtils    = require "AP.scripts.utils.apUtils"
local progression = require "AP.scripts.client.progression"

local chaunter = {}

local possessionSettings
do
    local ok, mod = pcall(require, "Sync.character.chaunter.PossessionSettings")
    if ok then possessionSettings = mod end
end

local function isChaunterBuff()
    return apUtils.isAPContext() and progression.getCharacterBuff("Chaunter")
end

if event.Sync_possessionAttach then
    event.Sync_possessionAttach.add("apChaunterBuffDoubleTimer", {
        order    = "possessorSprite",
        sequence = 2,
    }, function(ev)
        if not isChaunterBuff() then return end
        if not possessionSettings then return end
        if not ev.possessor or ev.possessor.name ~= "Sync_Chaunter" then return end
        local timer = ev.entity.Sync_possessableTimer
        if not timer then return end
        timer.remainingBeats = possessionSettings.getPossessionTimeLimit() * 2
    end)
end

function chaunter.apply() end
function chaunter.revoke() end
return chaunter
