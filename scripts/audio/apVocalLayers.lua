local currentLevel = require "necro.game.level.CurrentLevel"
local fileio       = require "system.game.FileIO"
local musicLayers  = require "necro.audio.MusicLayers"
local soundtrack   = require "necro.game.data.Soundtrack"

local apUtils = require "AP.scripts.utils.apUtils"

local apVocalLayers = {}

local LayerType = soundtrack.LayerType
local Vocals    = soundtrack.Vocals

-- Mirrors Soundtrack's per-floor shopkeeper gain, which only reaches layers masking SHOPKEEPER.
local FLOOR_GAIN = {
    { 1.4, 1.6, 1.6 },
    { 1.6, 1.4, 1.6 },
    { 1.4, 1.5, 1.4 },
    { 1.4, 1.4, 1.6 },
    { 1.4, 1.6, 1.6 },
}

local SLOTS = {}

local function defineSlot(key, vocals)
    local slot = { key = key, vocals = vocals, layer = LayerType.extend("AP_VOCALS_" .. key) }

    SLOTS[#SLOTS + 1] = slot

    return slot
end

apVocalLayers.DAOUST    = defineSlot("DAOUST", Vocals.NICOLAS_DAOUST)
apVocalLayers.MONSTROUS = defineSlot("MONSTROUS", Vocals.MONSTROUS_SHOPKEEPER)

local active = {}
active = script.persist(function() return active end)

--- The vocalist a slot's layer streams on the current track, or nil if it has no layer.
function apVocalLayers.getActive(slot)
    return active[slot.key]
end

local function resolveSlot(slot, baseVocals)
    if slot.vocals ~= baseVocals and soundtrack.isVocalistAvailable(slot.vocals) then
        return slot.vocals
    end

    return Vocals.SHOPKEEPER
end

local function swapVocals(file, from, to)
    local head, extension = file:match("^(.-)_" .. from .. "%.(%w+)$")
    return head and (head .. "_" .. to .. "." .. extension)
end

local function buildLayers(ev, vocals, layer)
    local built = {}

    for _, base in ipairs(ev.layers) do
        if base.file and base.type and LayerType.checkAll(base.type, LayerType.SHOPKEEPER) then
            local file = swapVocals(base.file, ev.vocals, vocals)
                or swapVocals(base.file, Vocals.SHOPKEEPER, vocals)

            if file and fileio.exists(file) then
                built[#built + 1] = {
                    file   = file,
                    type   = LayerType.mask(LayerType.unmask(base.type, LayerType.SHOPKEEPER), layer),
                    volume = base.volume,
                }
            end
        end
    end

    return built
end

event.musicTrack.add("apAltVocalLayers", "extraLayers", function(ev)
    active = {}

    if ev.vocals == Vocals.NONE then return end

    local resolved, added = {}, {}

    for _, slot in ipairs(SLOTS) do
        local vocals = resolveSlot(slot, ev.vocals)
        local built  = buildLayers(ev, vocals, slot.layer)

        if #built > 0 then
            resolved[slot.key] = vocals

            for _, layer in ipairs(built) do
                added[#added + 1] = layer
            end
        end
    end

    -- Checked last, so a track with no shopkeeper layer never reaches the session lookup.
    if #added == 0 or not apUtils.isAPContext() then return end

    for _, layer in ipairs(added) do
        ev.layers[#ev.layers + 1] = layer
    end

    active = resolved
end)

event.musicLayersUpdateVolume.add("apAltVocalLayerVolume", { order = "shopkeeper", sequence = 1 }, function()
    if not next(active) then return end

    local gains = FLOOR_GAIN[currentLevel.getZone()] or FLOOR_GAIN[1]
    local gain  = gains[currentLevel.getFloor()] or 1.6

    for _, slot in ipairs(SLOTS) do
        if active[slot.key] then
            musicLayers.multiplyVolume(slot.layer, gain)
        end
    end
end)

return apVocalLayers
