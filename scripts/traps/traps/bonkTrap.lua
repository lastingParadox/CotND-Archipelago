local confusion = require "necro.game.character.Confusion"
local sound     = require "necro.audio.Sound"

local makeMirrorXTrap = (require "AP.scripts.traps.factories.makeMirrorXTrap").makeMirrorXTrap
local TrapHandler     = require "AP.scripts.traps.trapHandler"

local BONK_SOUND      = "mods/AP/sfx/bonk.ogg"
local CONFUSION_TURNS = 24

TrapHandler.register("BonkTrap", makeMirrorXTrap({
    name         = "BonkTrap",
    flyawayText  = "Bonk!",
    mirrorXScale = 2.5,  -- wider X
    scaleY       = 0.5,  -- squashed Y
    guard = function(entity)
        if entity.confusable and entity.confusable.remainingTurns > 0 then
            return false
        end
        return not confusion.isConfused(entity)
    end,
    onApply = function(entity)
        sound.play(BONK_SOUND, entity.position.x, entity.position.y)
        confusion.inflict(entity, CONFUSION_TURNS)
    end,
}))
