local player   = require("necro.game.character.Player")
local snapshot = require "necro.game.system.Snapshot"
local tile     = require("necro.game.tile.Tile")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require("AP.scripts.traps.trapHandler")

local BURN_TURNS = 12

-- Rollback-managed: gates the trap and drives the per-turn coals.
apBurningEntities = snapshot.variable({}, true)

event.turn.add("APBurnTrapPlaceCoals", { order = "traps" }, function()
    for _, entity in ipairs(player.getPlayerEntities()) do
        if not (entity and entity.playableCharacter) then goto continue end
        local remaining = apBurningEntities[entity.id]
        if not remaining or remaining <= 0 then goto continue end
        tile.setType(entity.position.x, entity.position.y, "HotCoals")
        apBurningEntities[entity.id] = remaining - 1
        if apBurningEntities[entity.id] <= 0 then
            apBurningEntities[entity.id] = nil
        end
        ::continue::
    end
end)

event.gameStateReset.add("APBurnTrapClearOnReset", { order = "resetRunVariables" }, function()
    apBurningEntities = {}
end)

TrapHandler.register("BurnTrap", makeSimpleTrap({
    flyawayText = "Burn!",
    guard  = function(entity) return not apBurningEntities[entity.id] end,
    sound  = "dragonFire",
    action = function(entity) apBurningEntities[entity.id] = BURN_TURNS end,
}))
