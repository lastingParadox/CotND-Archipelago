local ecs = require "system.game.Entities"
local fileio = require "system.game.FileIO"
local player = require("necro.game.character.Player")
local hasSkins, SkinReaction = pcall(require, "CharacterSkins.SkinReaction")
local _, SkinStorage         = pcall(require, "CharacterSkins.SkinStorage")

local trapSystem = require "AP.scripts.traps.trapSystem"

local BALD_TEXTURE_PREFIX = "mods/AP/gfx/entities/bald/bald_heads"
local BALD_TEXTURE_FALLBACK = BALD_TEXTURE_PREFIX .. ".png"

-- Cached per suffix, since this resolves once per head on every spawn.
local baldTextures = {}

local function baldTexture(suffix)
    local cached = baldTextures[suffix]
    if cached ~= nil then return cached end

    local path = BALD_TEXTURE_PREFIX .. suffix .. ".png"
    local texture = fileio.exists(path) and path or false
    baldTextures[suffix] = texture

    return texture
end

local baldTrapExceptions = {
    Reaper        = true,
    Sync_Chaunter = true,
    Goldman_Goldman = true
}

local function getHeadEntity(playerEntity)
    if not playerEntity.characterWithAttachment then return nil end
    local headID = playerEntity.characterWithAttachment.attachmentID
    if not headID or headID == 0 then return nil end
    return ecs.getEntityByID(headID)
end

local function isUsingRiftSkin(entity, head)
    if not hasSkins then return false end
    local playerID = head and head.CharacterSkins_skinnable and head.CharacterSkins_skinnable.playerID
    if not playerID or playerID == 0 then
        playerID = (entity.controllable and entity.controllable.playerID ~= 0 and entity.controllable.playerID)
            or (entity.playableCharacter and entity.playableCharacter.pendingPlayerID ~= 0 and entity.playableCharacter.pendingPlayerID)
    end
    if not playerID or playerID == 0 then return false end
    local skin = SkinStorage.get(playerID, entity.name)
    return skin and type(skin.id) == "string" and skin.id:match("^_rift") ~= nil
end

local function applyBaldToEntity(entity)
    if not (entity and entity.playableCharacter) then return end
    if baldTrapExceptions[entity.name] then return end
    local head = getHeadEntity(entity)
    if not (head and head.sprite) then return end

    local charKey = "_" .. string.lower(entity.name)
    local texture

    if isUsingRiftSkin(entity, head) then
        local state = entity.CharacterSkins_skinReaction and entity.CharacterSkins_skinReaction.state
        local reaction = ""

        if state == SkinReaction.State.HAPPY then
            reaction = "_happy"
        elseif state == SkinReaction.State.SAD then
            reaction = "_sad"
        end

        texture = baldTexture(charKey .. "_rift" .. reaction) or baldTexture(charKey .. "_rift")
    end

    head.sprite.texture = texture or baldTexture(charKey) or BALD_TEXTURE_FALLBACK
end

-- sequence 1 runs after CharacterSkins (sequence -1) so the texture isn't overwritten
event.objectSpawn.add("APBaldTrapApplyOnSpawn",
    { order = "sprite", sequence = 1, filter = "characterWithAttachment" },
    function(ev)
        if trapSystem.isActive("BaldTrap") then
            applyBaldToEntity(ev.entity)
        end
    end
)

local function onReactionChange(ev)
    if trapSystem.isActive("BaldTrap") then applyBaldToEntity(ev.entity) end
end

event.objectTakeDamage.add("APBaldTrapReaction",
    { order = "sprite", sequence = 1, filter = "playableCharacter" },
    onReactionChange
)
event.objectHeal.add("APBaldTrapReaction",
    { order = "end", sequence = 1, filter = "playableCharacter" },
    onReactionChange
)
event.objectGrooveChain.add("APBaldTrapReaction",
    { order = "sprite", sequence = 1, filter = "playableCharacter" },
    onReactionChange
)

trapSystem.define({
    name     = "BaldTrap",
    flyaway  = function(ctx)
        return baldTrapExceptions[ctx.entity.name] and "Bald Trap negated!" or "Bald!"
    end,
    -- Head sprites for the rest of the run, and nothing the simulation reads.
    scope    = trapSystem.Scope.RUN,
    storage  = trapSystem.Storage.VOLATILE,
    stateful = true,
    apply    = function(ctx)
        if baldTrapExceptions[ctx.entity.name] then return end

        applyBaldToEntity(ctx.entity)
        ctx.state.anyBald = true
    end,
    -- Ends the trap unless somebody actually went bald.
    finish   = function(ctx)
        if not ctx.state.anyBald then trapSystem.stop("BaldTrap") end
    end,
})
