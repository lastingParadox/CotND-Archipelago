local apCharacters = require("AP.scripts.utils.apCharacters")

local CHARACTER_BUFFS = {
    ["Aria"]          = require("AP.scripts.buffs.characters.aria"),
    ["Bard"]          = require("AP.scripts.buffs.characters.bard"),
    ["Bolt"]          = require("AP.scripts.buffs.characters.bolt"),
    ["Cadence"]       = require("AP.scripts.buffs.characters.cadence"),
    ["Chaunter"]      = require("AP.scripts.buffs.characters.chaunter"),
    ["Coda"]          = require("AP.scripts.buffs.characters.coda"),
    ["Diamond"]       = require("AP.scripts.buffs.characters.diamond"),
    ["Dorian"]        = require("AP.scripts.buffs.characters.dorian"),
    ["Dove"]          = require("AP.scripts.buffs.characters.dove"),
    ["Eli"]           = require("AP.scripts.buffs.characters.eli"),
    ["Hatsune Miku"]  = require("AP.scripts.buffs.characters.coldsteel"),
    ["Klarinetta"]    = require("AP.scripts.buffs.characters.klarinetta"),
    ["Mary"]          = require("AP.scripts.buffs.characters.mary"),
    ["Melody"]        = require("AP.scripts.buffs.characters.melody"),
    ["Monk"]          = require("AP.scripts.buffs.characters.monk"),
    ["Nocturna"]      = require("AP.scripts.buffs.characters.nocturna"),
    ["Reaper"]        = require("AP.scripts.buffs.characters.reaper"),
    ["Shovel Knight"] = require("AP.scripts.buffs.characters.goldman"),
    ["Suzu"]          = require("AP.scripts.buffs.characters.suzu"),
    ["Tempo"]         = require("AP.scripts.buffs.characters.tempo"),
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
