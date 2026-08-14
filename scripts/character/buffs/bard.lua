local perspective  = require "necro.game.system.Perspective"

local apUtils      = require("AP.scripts.utils.apUtils")
local progression  = require("AP.scripts.client.progression")

local bard         = {}

local function isBardBuff()
    if not apUtils.isAPContext() then return false end
    if not progression.getCharacterBuff("Bard") then return false end
    return true
end

event.objectUpdatePerspective.add("apBardBuffRevealMap", {
    filter = "temporaryLevelTileVision",
    order = "tileVision",
}, function(ev)
    if ev.entity.name ~= "Bard" then return end
    if not isBardBuff() then return end
    ev.perspective[perspective.Attribute.TILE_REVEAL_ALL] = true
end)

function bard.apply(entity) end

function bard.revoke(entity) end

return bard
