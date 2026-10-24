local action      = require "necro.game.system.Action"
local gameSession = require "necro.client.GameSession"
local gameState   = require "necro.client.GameState"
local tile        = require "necro.game.tile.Tile"

local apTest      = require("AP.scripts.test.apTest")
local apUtils     = require("AP.scripts.utils.apUtils")

apTest.define({
    name = "worldHarnessBuildsAnAPFloor",
    world = true,
    run = function(t)
        t.note(("isInLobby=%s modeID=%s"):format(
            tostring(gameState.isInLobby()), tostring(gameSession.getCurrentModeID())))

        t.eq(gameSession.getCurrentModeID(), "AP_APAllZones")
        t.eq(gameSession.getCurrentMode().id, "APAllZones")
        t.ok(apUtils.isAPContext(), "the test floor is not an AP context")
        t.ok(not tile.isSolid(0, 0), "the test floor origin is solid")
        t.ne(t.player(), nil, "no player entity on the test floor")
    end,
})

apTest.define({
    name = "worldHarnessStepsTurns",
    world = true,
    run = function(t)
        local entity = t.player()
        if not t.ne(entity, nil, "no player entity on the test floor") then return end

        local startX = entity.position.x
        t.act(action.Direction.RIGHT)

        t.eq(t.player().position.x, startX + 1, "the player did not step right")
    end,
})
