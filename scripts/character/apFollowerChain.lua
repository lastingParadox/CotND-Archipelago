local damage = require("necro.game.system.Damage")
local ecs = require "system.game.Entities"
local follower = require "necro.game.character.Follower"
local health = require("necro.game.character.Health")
local object = require "necro.game.object.Object"
local voice = require("necro.audio.Voice")

local apFollowerChain = {}

-- Marvs hang off one another, so the line is already recorded
local function nextLink(entity)
    for _, entry in ipairs(follower.getFollowers(entity)) do
        if entry.AP_followerDamageParentWhileDead then return entry end
    end
end

local function chainTail(entity)
    local visited = {}

    while entity and not visited[entity.id] do
        visited[entity.id] = true

        local link = nextLink(entity)
        if not link then break end

        entity = link
    end

    return entity
end

function apFollowerChain.appendChainFollower(rootEntity, followerType, dx, dy)
    return follower.create(chainTail(rootEntity), followerType, dx or 0, dy or 0)
end

event.turn.override("followerDamageParentWhileDead", function(func)
    for entity in ecs.entitiesWithComponents({
        "follower",
        "followerDamageParentWhileDead",
        "killable"
    }) do
        local parent = ecs.getEntityByID(entity.item.holder)
        local vanillaComp = entity.followerDamageParentWhileDead
        local apComp = entity.AP_followerDamageParentWhileDead

        local overridden = apComp and apComp.killerName and apComp.killerName ~= ""

        if entity.killable.dead and parent and parent.gameObject.active and (not parent.descent or not parent.descent.active) then
            local killerName = (overridden and apComp.killerName) or vanillaComp.killerName
            local sounds     = (overridden and apComp.sounds and #apComp.sounds > 0 and apComp.sounds) or vanillaComp.sounds

            damage.inflict({
                silentHitVoice = true,
                attacker   = entity,
                victim     = parent,
                damage     = math.ceil(health.getMaxHealth(parent) * vanillaComp.damageRatio),
                type       = (overridden and apComp.type) or vanillaComp.type,
                killerName = killerName,
            })

            vanillaComp.stage = vanillaComp.stage + 1
            voice.play(parent, sounds[math.min(vanillaComp.stage, #sounds)])
        else
            vanillaComp.stage = 0
        end
    end
end)

-- Remove Marvs at level/zone transitions
function apFollowerChain.clearChain(entity)
    local link = nextLink(entity)

    while link do
        local following = nextLink(link)
        object.delete(link)
        link = following
    end
end

event.gameStateLevel.add("apRemoveDeathlinkChain", "damageCountdown", function()
    for entity in ecs.entitiesWithComponents({ "AP_followerDamageParentWhileDead" }) do
        local comp = entity.AP_followerDamageParentWhileDead

        if comp.killerName and comp.killerName ~= "" then
            object.delete(entity)
        end
    end
end)

return apFollowerChain
