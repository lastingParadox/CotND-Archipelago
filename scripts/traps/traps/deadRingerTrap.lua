local collision = require "necro.game.tile.Collision"
local currentLevel = require("necro.game.level.CurrentLevel")
local object = require "necro.game.object.Object"
local rng = require "necro.game.system.RNG"
local turn = require "necro.cycles.Turn"
local sound = require "necro.audio.Sound"

local apFlyaways = require("AP.scripts.ui.apFlyaways")
local TrapHandler = require("AP.scripts.traps.trapHandler")


local function deadRingerTrap(ev)
    local trapSuccess = false

    local affectedPlayers = {}

    -- Collect all valid affected players
    for _, entry in ipairs(TrapHandler.actingEntries(ev)) do
        if not entry.entity or
            not entry.entity.playableCharacter or
            (entry.entity.confusable and entry.entity.confusable.remainingTurns > 0) then
            goto continue
        end

        table.insert(affectedPlayers, entry.entity)

        ::continue::
    end

    if #affectedPlayers == 0 then return trapSuccess end

    local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())

    -- Spawn one Dead Ringer for each affected player
    for _, playerEntity in ipairs(affectedPlayers) do
        local tiles = collision.getVacantTiles(
            playerEntity, 2, 4, 6, false,
            collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
        )

        if #tiles > 0 then
            local tile = rng.shuffle(tiles, channel)[1]
            object.spawn("DeadRinger", tile[1], tile[2])

            apFlyaways.addToFlyawayQueue({
                entity = playerEntity,
                text = "Dead Ringer!",
            })

            trapSuccess = true
        end
    end

    if trapSuccess then
        sound.playUI("announceDeadRinger", { channel = 0 })
    end

    return trapSuccess
end

TrapHandler.register("DeadRingerTrap", deadRingerTrap)

return deadRingerTrap
