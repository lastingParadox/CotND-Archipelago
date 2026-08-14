local collision      = require "necro.game.tile.Collision"
local currency       = require "necro.game.item.Currency"
local currentLevel   = require "necro.game.level.CurrentLevel"
local moveAnimations = require "necro.render.level.MoveAnimations"
local object         = require "necro.game.object.Object"
local player         = require "necro.game.character.Player"
local rng            = require "necro.game.system.RNG"
local sound          = require "necro.audio.Sound"
local turn           = require "necro.cycles.Turn"
local voice          = require "necro.audio.Voice"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

-- Highest values first so we always try the biggest pile that fits.
local COIN_TYPES = {
    { 50, "ResourceHoardGold"      },
    { 30, "ResourceCoin30"         },
    { 25, "ResourceHoardGoldSmall" },
    { 10, "ResourceCoin10"         },
    {  9, "ResourceCoin9"          },
    {  8, "ResourceCoin8"          },
    {  7, "ResourceCoin7"          },
    {  6, "ResourceCoin6"          },
    {  5, "ResourceCoin5"          },
    {  4, "ResourceCoin4"          },
    {  3, "ResourceCoin3"          },
    {  2, "ResourceCoin2"          },
    {  1, "ResourceCoin1"          },
}

local function calculateLoss(gold, channel)
    if gold <= 100 then
        return math.floor(gold * rng.range(80, 100, channel) / 100)
    elseif gold <= 300 then
        return math.floor(gold * rng.range(70, 95,  channel) / 100)
    else
        return math.floor(gold * rng.range(60, 90,  channel) / 100)
    end
end

local MAX_LEPRECHAUNS     = 3
local GOLD_PER_LEPRECHAUN = 100

---Greedy denomination breakdown; emitted largest-first.
local function buildPiles(amount)
    local piles = {}
    for _, c in ipairs(COIN_TYPES) do
        while amount >= c[1] do
            piles[#piles + 1] = { value = c[1], name = c[2] }
            amount = amount - c[1]
        end
    end
    return piles
end

local function spawnCoins(amount, tiles, origin, channel)
    local piles = buildPiles(amount)
    -- One leprechaun per 100 gold scattered (max 3), always taking the
    -- largest piles so their bounty is worth chasing.
    local leprechauns = math.min(MAX_LEPRECHAUNS, math.floor(amount / GOLD_PER_LEPRECHAUN), #piles)
    local spawned = 0
    for i, pile in ipairs(piles) do
        if #tiles == 0 then break end
        local t = table.remove(tiles, rng.range(1, #tiles, channel))
        local coin
        if i <= leprechauns then
            coin = object.spawn("Leprechaun", t[1], t[2], {
                goldCounter = { amount = pile.value },
            })
            spawned = spawned + 1
        else
            coin = object.spawn(pile.name, t[1], t[2])
            coin.itemStack.quantity = pile.value
        end
        moveAnimations.play(coin, moveAnimations.Type.HOP, origin.x, origin.y)
    end
    return spawned
end

TrapHandler.register("GoldScatterTrap", makeSimpleTrap({
    flyawayText = function(entity, ctx)
        local leps = ctx.entityLeprechauns and ctx.entityLeprechauns[entity.id] or 0
        return leps > 0
            and ("Darn Leprechaun" .. (leps > 1 and "s!" or "!"))
            or  "Butterfingers!"
    end,
    setup = function()
        local targets = {}
        for _, e in ipairs(player.getPlayerEntities()) do
            if e and e.playableCharacter then targets[#targets + 1] = e end
        end
        if #targets == 0 then return false end

        local sharedGold = currency.get(targets[1], currency.Type.GOLD)
        if sharedGold <= 0 then return false end

        local channel   = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        local totalLoss = calculateLoss(sharedGold, channel)
        if totalLoss <= 0 then return false end

        currency.subtract(targets[1], currency.Type.GOLD, totalLoss)

        local perPlayer = math.floor(totalLoss / #targets)
        local remainder = totalLoss % #targets
        return {
            channel          = channel,
            perPlayer        = perPlayer,
            remainder        = remainder,
            index            = 0,
            entityLeprechauns = {},
        }
    end,
    action = function(entity, ctx)
        ctx.index = ctx.index + 1
        local share = ctx.perPlayer + (ctx.index <= ctx.remainder and 1 or 0)
        local leps  = 0
        if share > 0 then
            local tiles = collision.getVacantTiles(
                entity, 1, 6, 6, false,
                collision.mask(collision.Group.SOLID, collision.Type.TRAP)
            )
            if #tiles > 0 then
                leps = spawnCoins(share, tiles, entity.position, ctx.channel)
            end
        end
        ctx.entityLeprechauns[entity.id] = leps
        voice.play(entity, entity.voiceSlideStart)
        sound.playFromEntity("iceSlip", entity, { volume = 20, pitch = 1.5 })
    end,
}))
