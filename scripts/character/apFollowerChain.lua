local damage = require("necro.game.system.Damage")
local ecs = require "system.game.Entities"
local follower = require "necro.game.character.Follower"
local health = require("necro.game.character.Health")
local object = require "necro.game.object.Object"
local voice = require("necro.audio.Voice")

local apFollowerChain = {}

local function ensureChainRoot(entity)
    if not entity.AP_followerChain.root or entity.AP_followerChain.root == 0 then
        entity.AP_followerChain.root = entity
    end
    return ecs.getEntityByID(entity.AP_followerChain.root) or entity
end

local function linkChainNodes(parent, child, root)
    parent.AP_followerChain.child = child
    child.AP_followerChain.root = root
    child.AP_followerChain.parent = parent
end

local function getChainTail(root)
    local tail = root
    local visited = {}

    while tail and tail.AP_followerChain and tail.AP_followerChain.child and not visited[tail.id] do
        visited[tail] = true

        local nextTail = ecs.getEntityByID(tail.AP_followerChain.child)
        if not nextTail then
            break
        end

        tail = nextTail
    end

    return tail or root
end

function apFollowerChain.createChainFollower(entity, followerType, dx, dy)
    dx = dx or 0
    dy = dy or 0

    local root = ensureChainRoot(entity)
    local chain = follower.create(entity, followerType, dx, dy)

    linkChainNodes(entity, chain, root)

    return chain
end

function apFollowerChain.appendChainFollower(rootEntity, followerType, dx, dy)
    local root = ensureChainRoot(rootEntity)
    local tail = getChainTail(root)
    return apFollowerChain.createChainFollower(tail, followerType, dx, dy)
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
        local isDeathlink = apComp and apComp.killerName and apComp.killerName ~= ""

        if entity.killable.dead and parent and parent.gameObject.active and (not parent.descent or not parent.descent.active) then
            local killerName = (isDeathlink and apComp.killerName) or vanillaComp.killerName
            local sounds     = (isDeathlink and apComp.sounds and #apComp.sounds > 0 and apComp.sounds) or vanillaComp.sounds

            damage.inflict({
                silentHitVoice = true,
                attacker   = entity,
                victim     = parent,
                damage     = math.ceil(health.getMaxHealth(parent) * vanillaComp.damageRatio),
                type       = (isDeathlink and apComp.type) or vanillaComp.type,
                killerName = killerName,
            })

            vanillaComp.stage = vanillaComp.stage + 1
            voice.play(parent, sounds[math.min(vanillaComp.stage, #sounds)])
        else
            vanillaComp.stage = 0
        end
    end
end)

-- Remove deathlink Marvs at level/zone transitions (also covers ensemble character
-- switches, which only happen at floor boundaries).
local function clearDeathlinkChain(entity)
    local childID = entity.AP_followerChain and entity.AP_followerChain.child
    if childID and childID ~= 0 then
        local child = ecs.getEntityByID(childID)
        if child then object.delete(child) end
        entity.AP_followerChain = { child = 0, parent = 0, root = 0 }
    end
end

event.gameStateLevel.add("apRemoveDeathlinkChain", "damageCountdown", function()
    for entity in ecs.entitiesWithComponents({ "playableCharacter", "AP_followerChain" }) do
        clearDeathlinkChain(entity)
    end
end)

return apFollowerChain
