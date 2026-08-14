local affectorItem = require("necro.game.item.AffectorItem")
local character    = require "necro.game.character.Character"
local collision    = require "necro.game.tile.Collision"
local ecs          = require "system.game.Entities"
local rng          = require "necro.game.system.RNG"
local targeting    = require "necro.game.enemy.Targeting"

local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local function getMonkeyVariants()
    local entities = ecs.getEntityTypesWithComponents({ "monkeyLike", "grab" })
    local result   = {}
    for _, e in ipairs(entities) do
        if string.find(e, "Monkey") and not string.find(e, "Coop") then
            result[#result + 1] = e
        end
    end
    return result
end

TrapHandler.register("MonkeyTrap", makeSummonTrap({
    flyawayText  = "Have a Monkey!",
    min          = 1,
    max          = 1,
    radius       = 3,
    minRadius    = 0,
    spawnProps   = false,
    getTiles     = function(entity, minDist, maxDist, channel)
        local px, py = entity.position.x, entity.position.y
        local mask   = collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        local minSq  = minDist * minDist
        local maxSq  = maxDist * maxDist
        local byDist = {}
        for dx = -maxDist, maxDist do
            for dy = -maxDist, maxDist do
                local dsq = dx * dx + dy * dy
                if dsq > minSq and dsq < maxSq then
                    local tx, ty = px + dx, py + dy
                    if not collision.check(tx, ty, mask) then
                        byDist[dsq] = byDist[dsq] or {}
                        local g = byDist[dsq]
                        g[#g + 1] = { tx, ty }
                    end
                end
            end
        end
        local dists = {}
        for dsq in pairs(byDist) do dists[#dists + 1] = dsq end
        table.sort(dists)
        local tiles = {}
        for _, dsq in ipairs(dists) do
            local group = byDist[dsq]
            rng.shuffle(group, channel)
            for _, t in ipairs(group) do
                tiles[#tiles + 1] = t
            end
        end
        return tiles
    end,
    checkGrabbed = true,
    perPlayerSetup = function(entity, zone, channel)
        -- Coda and Aria: monkey spawning is pointless for them.
        if entity.name == "Coda" or entity.name == "Aria" then
            return { variants = {}, flyawayText = "Monkey Trap Negated!" }
        end
        -- Player has an item that freezes monkeys: the monkey won't attack.
        if affectorItem.getItem(entity, "itemFreezeMonkeyLikes") then
            return { variants = {}, flyawayText = "Monkey Trap Negated!" }
        end
        local monkeys = getMonkeyVariants()
        if #monkeys == 0 then
            return { variants = {}, flyawayText = "No Monkeys Available!" }
        end
        return { variants = monkeys, flyawayText = "Have a Monkey!" }
    end,
    onSpawn = function(monkey, t, playerEntity)
        targeting.setTarget(monkey, playerEntity)
        playerEntity.character.canAct = false
    end,
}))
