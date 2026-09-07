local collision      = require "necro.game.tile.Collision"
local currency       = require "necro.game.item.Currency"
local moveAnimations = require "necro.render.level.MoveAnimations"
local object         = require "necro.game.object.Object"
local rng            = require "necro.game.system.RNG"
local sound          = require "necro.audio.Sound"
local voice          = require "necro.audio.Voice"

local trapSystem = require "AP.scripts.traps.trapSystem"

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

-- The reach inventory.scatter uses: nearest ring first, widening outward.
local SCATTER_OFFSETS = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
    { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
    { -2, -1 }, { 2, -1 }, { -2, 1 }, { 2, 1 },
    { -1, -2 }, { 1, -2 }, { -1, 2 }, { 1, 2 },
    { -3, 0 }, { 3, 0 }, { 0, -3 }, { 0, 3 },
}

local SCATTER_MASK = collision.mask(collision.Group.SOLID, collision.Type.ITEM, collision.Type.TRAP)

---One tile per pile, walked outward and collision-checked; overflow piles onto the first.
local function scatterTiles(origin, count)
    local tiles = {}

    for i = 1, #SCATTER_OFFSETS do
        if #tiles >= count then break end

        local offset = SCATTER_OFFSETS[i]
        local x, y = origin.x + offset[1], origin.y + offset[2]

        if not collision.check(x, y, SCATTER_MASK) then
            tiles[#tiles + 1] = { x, y }
        end
    end

    local fallback = SCATTER_OFFSETS[1]
    while #tiles < count do
        tiles[#tiles + 1] = { origin.x + fallback[1], origin.y + fallback[2] }
    end

    return tiles
end

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

local function spawnCoins(amount, origin)
    local piles = buildPiles(amount)
    -- One leprechaun per 100 gold scattered (max 3), taking the largest piles.
    local leprechauns = math.min(MAX_LEPRECHAUNS, math.floor(amount / GOLD_PER_LEPRECHAUN), #piles)
    local tiles = scatterTiles(origin, #piles)

    for i, pile in ipairs(piles) do
        local t = tiles[i]
        local coin

        if i <= leprechauns then
            coin = object.spawn("Leprechaun", t[1], t[2], {
                goldCounter = { amount = pile.value },
            })
        else
            coin = object.spawn(pile.name, t[1], t[2])
            coin.itemStack.quantity = pile.value
        end

        moveAnimations.play(coin, moveAnimations.Type.HOP, origin.x, origin.y)
    end

    return leprechauns
end

trapSystem.define({
    name    = "GoldScatterTrap",
    flyaway = function(ctx)
        local leps = ctx.state.leprechauns[ctx.entity.id] or 0
        return leps > 0
            and ("Darn Leprechaun" .. (leps > 1 and "s!" or "!"))
            or  "Butterfingers!"
    end,
    start   = function(ctx)
        local targets = ctx.players
        local sharedGold = currency.get(targets[1].entity, currency.Type.GOLD)
        if sharedGold <= 0 then return false end

        local totalLoss = calculateLoss(sharedGold, ctx.channel)
        if totalLoss <= 0 then return false end

        currency.subtract(targets[1].entity, currency.Type.GOLD, totalLoss)

        ctx.state.perPlayer   = math.floor(totalLoss / #targets)
        ctx.state.remainder   = totalLoss % #targets
        ctx.state.index       = 0
        ctx.state.leprechauns = {}
    end,
    apply   = function(ctx)
        local entity = ctx.entity
        local state  = ctx.state

        state.index = state.index + 1
        local share = state.perPlayer + (state.index <= state.remainder and 1 or 0)
        local leps  = 0

        if share > 0 then
            leps = spawnCoins(share, entity.position)
        end

        state.leprechauns[entity.id] = leps
        voice.play(entity, entity.voiceSlideStart)
        sound.playFromEntity("iceSlip", entity, { volume = 20, pitch = 1.5 })
    end,
})
