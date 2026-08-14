local freeze     = require "necro.game.character.Freeze"
local player     = require "necro.game.character.Player"
local sound      = require "necro.audio.Sound"

local apFlyaways = require "AP.scripts.ui.apFlyaways"

---Creates a freeze-type status trap (ice or stone) and returns its trigger function.
---
---@param opts table
---  Required:
---    turns       number       Duration in game turns.
---    freezeType  freeze.Type  freeze.Type.ICE or freeze.Type.STONE.
---    sound       string       Sound key played per player at entity position.
---    flyawayText string       Flyaway text shown to each affected player.
---@return function trapFn
local function makeFreezeTrap(opts)
    assert(opts.turns,       "makeFreezeTrap: opts.turns is required")
    assert(opts.freezeType,  "makeFreezeTrap: opts.freezeType is required")
    assert(opts.sound,       "makeFreezeTrap: opts.sound is required")
    assert(opts.flyawayText, "makeFreezeTrap: opts.flyawayText is required")

    return function(ev)
        local trapSuccess = false

        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end
            if not entity.freezable then goto continue end
            if freeze.isFrozen(entity) then goto continue end

            sound.play(opts.sound, entity.position.x, entity.position.y)
            freeze.inflict(entity, opts.turns, opts.freezeType)
            apFlyaways.addToFlyawayQueue({ entity = entity, text = opts.flyawayText })

            trapSuccess = true
            ::continue::
        end

        return trapSuccess
    end
end

return { makeFreezeTrap = makeFreezeTrap }
