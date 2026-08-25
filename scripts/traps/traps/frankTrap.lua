local collision    = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local gameDLC      = require "necro.game.data.resource.GameDLC"
local object       = require "necro.game.object.Object"
local rng          = require "necro.game.system.RNG"
local sound        = require "necro.audio.Sound"
local turn         = require "necro.cycles.Turn"

local apFlyaways  = require("AP.scripts.ui.apFlyaways")
local TrapHandler = require("AP.scripts.traps.trapHandler")

-- Frankensteinway stands 2x2, unlike the Dead Ringer this is otherwise modelled on, so a
-- candidate tile only works if the three tiles he extends into are clear as well.
local FOOTPRINT = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }

local function fitsAt(x, y, mask)
    for _, offset in ipairs(FOOTPRINT) do
        if collision.check(x + offset[1], y + offset[2], mask) then return false end
    end

    return true
end

local function frankTrap(ev)
    -- Zone 5's boss does not exist without Amplified. Nothing to wait for, so the trap is
    -- spent rather than left in the queue forever.
    if not gameDLC.isAmplifiedLoaded() then return true end

    local affectedPlayers = {}

    for _, entry in ipairs(TrapHandler.actingEntries(ev)) do
        if not entry.entity or
            not entry.entity.playableCharacter or
            (entry.entity.confusable and entry.entity.confusable.remainingTurns > 0) then
            goto continue
        end

        table.insert(affectedPlayers, entry.entity)

        ::continue::
    end

    if #affectedPlayers == 0 then return false end

    local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
    local mask = collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
    local trapSuccess = false

    for _, playerEntity in ipairs(affectedPlayers) do
        local tiles = rng.shuffle(
            collision.getVacantTiles(playerEntity, 2, 4, 6, false, mask), channel)

        for _, tile in ipairs(tiles) do
            if fitsAt(tile[1], tile[2], mask) then
                object.spawn("Frankensteinway", tile[1], tile[2])

                apFlyaways.addToFlyawayQueue({
                    entity = playerEntity,
                    text = "Frank Trap!",
                })

                trapSuccess = true
                break
            end
        end
    end

    if trapSuccess then
        sound.playUI("announceFrankensteinway", { channel = 0 })
    end

    return trapSuccess
end

TrapHandler.register("FrankTrap", frankTrap)

return frankTrap
