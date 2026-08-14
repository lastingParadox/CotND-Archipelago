local apCharacters = require("AP.scripts.utils.apCharacters")

local CHARACTER_BUFFS = {
    ["Bard"]    = require("AP.scripts.character.buffs.bard"),
    ["Bolt"]    = require("AP.scripts.character.buffs.bolt"),
    ["Coda"]    = require("AP.scripts.character.buffs.coda"),
    ["Diamond"] = require("AP.scripts.character.buffs.diamond"),
    ["Cadence"] = require("AP.scripts.character.buffs.cadence"),
    ["Dorian"]  = require("AP.scripts.character.buffs.dorian"),
    ["Dove"]    = require("AP.scripts.character.buffs.dove"),
    ["Eli"]     = require("AP.scripts.character.buffs.eli"),    ["Mary"]    = require("AP.scripts.character.buffs.mary"),    ["Melody"]   = require("AP.scripts.character.buffs.melody"),
    ["Aria"]     = require("AP.scripts.character.buffs.aria"),
    ["Monk"]     = require("AP.scripts.character.buffs.monk"),
    ["Nocturna"] = require("AP.scripts.character.buffs.nocturna"),
    ["Reaper"]      = require("AP.scripts.character.buffs.reaper"),
    ["Tempo"]       = require("AP.scripts.character.buffs.tempo"),
    ["Klarinetta"]  = require("AP.scripts.character.buffs.klarinetta"),
    ["Chaunter"]    = require("AP.scripts.character.buffs.chaunter"),
    ["Suzu"]        = require("AP.scripts.character.buffs.suzu"),
    ["Hatsune Miku"]  = require("AP.scripts.character.buffs.coldsteel"),
    ["Shovel Knight"] = require("AP.scripts.character.buffs.goldman"),
}

local characterBuffs = {}

function characterBuffs.apply(entity, progression)
    if not entity or not progression then return end

    local apName = apCharacters.cotNDCharToAPLocation(entity.name)
    if not apName then return end

    local buff = CHARACTER_BUFFS[apName]
    if not buff then return end

    if buff.revoke then
        buff.revoke(entity)
    end

    if not progression.getCharacterBuff(apName) then return end

    buff.apply(entity, progression)
end

return characterBuffs
