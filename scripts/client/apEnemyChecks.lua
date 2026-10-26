local ecs = require "system.game.Entities"
local instantReplay = require "necro.client.replay.InstantReplay"
local player = require "necro.game.character.Player"
local replayPlayer = require "necro.client.replay.ReplayPlayer"
local snapshot = require "necro.game.system.Snapshot"

local apClient = require("AP.scripts.client.client")
local apFlyaways = require("AP.scripts.ui.apFlyaways")
local apStorage = require("AP.scripts.client.storage")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

-- The check each converted enemy spawned as, so a dismounted knight still dies as a knight.
apEnemyOrigin = snapshot.levelVariable({})

-- A beheaded skeleton dies as Skeleton3Headless, so the lookup walks the variant chain home.
local function locationOfType(name)
    for _ = 1, 4 do
        local location = name and progression.getEnemyLocation(name)
        if location then return location end

        local prototype = name and ecs.getEntityPrototype(name)
        local variant = prototype and prototype.variant or nil

        name = variant and variant.base
        if not name then return nil end
    end
end

local function enemyChecksActive()
    return not (instantReplay.isActive()
        or replayPlayer.isActive()
        or not apUtils.isAPContext()
        or not apClient.isSessionConnected()
        or not progression.getEnemyChecks())
end

event.objectPostConvert.add("apEnemyOrigin", { order = "resetFields", sequence = 1 }, function(ev)
    if not enemyChecksActive() or apEnemyOrigin[ev.entity.id] then return end

    apEnemyOrigin[ev.entity.id] = locationOfType(ev.oldType)
end)

local function sendEnemyCheck(entity, killer)
    local location = apEnemyOrigin[entity.id] or locationOfType(entity.name)
    if not location then return end

    local defeated = apStorage.saveData.characterLocations["Enemies"] or {}
    if defeated[location] then return end

    defeated[location] = true
    apStorage.saveData.characterLocations["Enemies"] = defeated

    progression.sendLocationChecks({ location })

    local name = location:gsub("^Defeat ", "")
    apFlyaways.addToFlyawayQueue({ entity = killer, text = name .. " " .. L("defeated", "ap.defeated") })
end

-- Only kills credited to a player count, including ones the engine forwards from a bomb or summon.
event.objectDeath.add("apEnemyCheck", { order = "statistics", sequence = 1 }, function(ev)
    if enemyChecksActive() and player.isPlayerEntity(ev.killer) then
        sendEnemyCheck(ev.entity, ev.killer)
    end
end)

-- A player's blocked hit that makes an enemy despawn itself, as a pixie's explosion does, is a kill.
event.objectTakeDamage.add("apEnemyShieldHitCheck", { filter = "castOnShieldHit", order = "spellLate", sequence = 1 },
    function(ev)
        if ev.shielded and ev.entity.gameObject.despawned and player.isPlayerEntity(ev.attacker)
            and enemyChecksActive() then
            sendEnemyCheck(ev.entity, ev.attacker)
        end
    end)
