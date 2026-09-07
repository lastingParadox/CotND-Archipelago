local boss         = require "necro.game.level.Boss"
local collision    = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local gameDLC      = require "necro.game.data.resource.GameDLC"
local object       = require "necro.game.object.Object"
local rng          = require "necro.game.system.RNG"
local sound        = require "necro.audio.Sound"
local tile         = require "necro.game.tile.Tile"
local vision       = require "necro.game.vision.Vision"

local apUtils    = require("AP.scripts.utils.apUtils")
local trapSystem = require("AP.scripts.traps.trapSystem")

-- Frankensteinway stands 2x2, so the three tiles he extends into must be clear too.
local FOOTPRINT = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }

local function fitsAt(x, y, mask)
    for _, offset in ipairs(FOOTPRINT) do
        if collision.check(x + offset[1], y + offset[2], mask) then return false end
    end

    return true
end

-- He charges only where more than three tiles of home area lie ahead of him.
local ARENA_RADIUS = 8

local function tilesExist(x1, y1, x2, y2)
    for x = x1, x2 do
        for y = y1, y2 do
            if not tile.exists(x, y) then return false end
        end
    end

    return true
end

-- Grown a ring at a time rather than clamped to the level's rectangle
local function centreArena(frank)
    if not (frank.homeArea and frank.position) then return end

    -- He stands 2x2, so the arena starts as the block he already occupies.
    local x, y = frank.position.x, frank.position.y
    local minX, minY, maxX, maxY = x, y, x + 1, y + 1

    for _ = 1, ARENA_RADIUS do
        if minX > x - ARENA_RADIUS and tilesExist(minX - 1, minY, minX - 1, maxY) then
            minX = minX - 1
        end
        if maxX < x + ARENA_RADIUS and tilesExist(maxX + 1, minY, maxX + 1, maxY) then
            maxX = maxX + 1
        end
        -- After the columns, so the corners they just added are checked with the rows.
        if minY > y - ARENA_RADIUS and tilesExist(minX, minY - 1, maxX, minY - 1) then
            minY = minY - 1
        end
        if maxY < y + ARENA_RADIUS and tilesExist(minX, maxY + 1, maxX, maxY + 1) then
            maxY = maxY + 1
        end
    end

    frank.homeArea.minX = minX
    frank.homeArea.minY = minY
    frank.homeArea.maxX = maxX
    frank.homeArea.maxY = maxY
end

-- His own boss level owns its arena and must keep it.
event.objectMove.add("apFrankTrapArena", { filter = "frankensteinway", order = "position", sequence = 1 }, function(ev)
    if currentLevel.getBossType() == boss.Type.FRANKENSTEINWAY then return end

    centreArena(ev.entity)
end)

local ELECTRIC_SWIPES = {
    "elecWarning", "elecFinalWarning", "elecZap",
    "elecDownWarning", "elecDownFinalWarning", "elecDownZap",
}

-- His shocks are laid over the arena rectangle, crossing walls as readily as floor.
local function hideSwipeOffFloor(ev)
    if not apUtils.isAPContext() then return end
    if not (ev.attacker and ev.attacker.frankensteinway) then return end

    -- Floor he can reach somebody on, restricted to what the player can see.
    local shown = tile.exists(ev.x, ev.y)
        and tile.getInfo(ev.x, ev.y).isFloor
        and not vision.isPerspectiveShadowed(ev.x, ev.y)

    if shown then return end

    ev.swipe.frameCount = 1
    ev.swipe.frames = { 0 }
end

for _, swipeType in ipairs(ELECTRIC_SWIPES) do
    event.swipe.add("apFrankFloorOnly" .. swipeType, { key = swipeType, sequence = 1 }, hideSwipeOffFloor)
end

trapSystem.define({
    name    = "FrankTrap",
    flyaway = "Frank Trap!",
    -- Zone 5's boss does not exist without Amplified, so the trap is spent rather than queued.
    start   = function()
        if not gameDLC.isAmplifiedLoaded() then return true end
    end,
    apply   = function(ctx)
        if not gameDLC.isAmplifiedLoaded() then return false end

        local entity = ctx.entity
        if entity.confusable and entity.confusable.remainingTurns > 0 then return false end

        local mask  = collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        local tiles = rng.shuffle(
            collision.getVacantTiles(entity, 2, 4, 6, false, mask), ctx.channel)

        for _, spot in ipairs(tiles) do
            if fitsAt(spot[1], spot[2], mask) then
                -- Awake, on the map and not waiting in ambush: he is the whole trap.
                local frank = object.spawn("Frankensteinway", spot[1], spot[2], {
                    visibility = { revealed = true },
                    aggro      = { active = true },
                    ambusher   = { pending = false },
                })
                if frank then centreArena(frank) end

                ctx.state.spawned = true
                return
            end
        end

        return false
    end,
    finish  = function(ctx)
        if ctx.state.spawned then
            sound.playUI("announceFrankensteinway", { channel = 0 })
        end
    end,
})
