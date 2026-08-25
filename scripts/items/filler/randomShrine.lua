local collision = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local object = require "necro.game.object.Object"
local rng = require "necro.game.system.RNG"
local turn = require "necro.cycles.Turn"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local apShrines = require("AP.scripts.entities.apShrines")
local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local trapHandler = require("AP.scripts.traps.trapHandler")

local function spawnShrine(entity, ctx)
    local tiles = collision.getVacantTiles(
        entity, 2, 4, 6, false,
        collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
    )
    if #tiles == 0 then return false end

    local name = rng.choice(ctx.unlocked, ctx.channel)
    local tile = tiles[1]

    if not object.spawn(name, tile[1], tile[2]) then return false end
end

trapHandler.register("APRandomShrine", makeSimpleTrap({
    sound = "spellGeneral",
    -- Only shrines already unlocked, so this offers nothing the floor could not have
    -- generated on its own, including the check the shrine pays out.
    setup = function()
        local unlocked = apShrines.unlockedShrines()
        if #unlocked == 0 then return false end

        return {
            unlocked = unlocked,
            channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID()),
        }
    end,
    action = spawnShrine,
}))

apItemFactory.define({
    name = "AP_RandomShrine",
    rawTexture = "ext/level/shrine_chance.png",
    -- A shrine sheet frame, not an item icon: at the 24x24 default it draws as a crop of
    -- the top-left corner. The geometry is CommonShrine's own.
    width = 35,
    height = 52,
    components = {
        spriteSheet = {},
        positionalSprite = { offsetX = -6, offsetY = -19 },
    },
    hint = "Random Shrine",
    flyaway = "Random Shrine!",
    grant = {
        item = "APRandomShrine",
        carrier = false,
        apply = function() trapHandler.deliver("APRandomShrine") end,
    },
})
