local colorUtil = require "system.utils.Color"
local player    = require "necro.game.character.Player"

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local invisibleState = {}
invisibleState = script.persist(function() return invisibleState end)

event.renderEffects.add("APInvisibleTrapRender", { order = "spriteCorrection", sequence = 99 }, function(ev)
    for _, entity in ipairs(player.getPlayerEntities()) do
        if not (entity and entity.playableCharacter) then goto continue end
        if not invisibleState[entity.id] then goto continue end
        if entity.sprite then
            entity.sprite.color = colorUtil.setA(entity.sprite.color, 0)
        end
        if entity.shadow then
            entity.shadow.visible = false
        end
        ::continue::
    end
end)

event.gameStateLevel.add("APInvisibleTrapClear", { order = "splitScreen" }, function(ev)
    invisibleState = {}
end)

TrapHandler.register("InvisibleTrap", makeSimpleTrap({
    flyawayText = "Invisible!",
    action = function(entity)
        invisibleState[entity.id] = true
    end,
}))
