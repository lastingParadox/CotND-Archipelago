local colorUtil = require "system.utils.Color"
local player    = require "necro.game.character.Player"

local trapSystem = require "AP.scripts.traps.trapSystem"

event.renderEffects.add("APInvisibleTrapRender", { order = "spriteCorrection", sequence = 99 }, function()
    for _, entity in ipairs(player.getPlayerEntities()) do
        if not (entity and entity.playableCharacter) then goto continue end
        if not trapSystem.isActive("InvisibleTrap", entity) then goto continue end

        if entity.sprite then
            entity.sprite.color = colorUtil.setA(entity.sprite.color, 0)
        end
        if entity.shadow then
            entity.shadow.visible = false
        end

        ::continue::
    end
end)

trapSystem.define({
    name      = "InvisibleTrap",
    flyaway   = "Invisible!",
    perPlayer = true,
    -- Sprite alpha only: rewinding this mid-frame would flicker the player.
    storage   = trapSystem.Storage.VOLATILE,
    stateful  = true,
})
