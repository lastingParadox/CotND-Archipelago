local ecs = require "system.game.Entities"
local player = require("necro.game.character.Player")
local hasSkins, SkinReaction = pcall(require, "CharacterSkins.SkinReaction")
local _, SkinStorage         = pcall(require, "CharacterSkins.SkinStorage")

local makeSimpleTrap = (require "AP.scripts.traps.factories.makeSimpleTrap").makeSimpleTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local baldTextureFallback = "mods/AP/gfx/bald/bald_heads.png"
local baldTextureByChar = {
    bard     = "mods/AP/gfx/bald/bald_heads_bard.png",
    bolt     = "mods/AP/gfx/bald/bald_heads_bolt.png",
    coda     = "mods/AP/gfx/bald/bald_heads_coda.png",
    diamond  = "mods/AP/gfx/bald/bald_heads_diamond.png",
    dorian   = "mods/AP/gfx/bald/bald_heads_dorian.png",
    dove     = "mods/AP/gfx/bald/bald_heads_dove.png",
    eli      = "mods/AP/gfx/bald/bald_heads_eli.png",
    monk              = "mods/AP/gfx/bald/bald_heads_monk.png",
    nocturna          = "mods/AP/gfx/bald/bald_heads_nocturna.png",
    tempo             = "mods/AP/gfx/bald/bald_heads_tempo.png",
    coldsteel_coldsteel = "mods/AP/gfx/bald/bald_heads_coldsteel_coldsteel.png",
    sync_klarinetta   = "mods/AP/gfx/bald/bald_heads_sync_klarinetta.png",
    sync_suzu         = "mods/AP/gfx/bald/bald_heads_sync_suzu.png",
}

-- Characters with rift (supporter) skin bald variants.
local riftBaldTextureByChar = {
    cadence   = {
        normal = "mods/AP/gfx/bald/bald_heads_cadence_rift.png",
        happy  = "mods/AP/gfx/bald/bald_heads_cadence_rift_happy.png",
        sad    = "mods/AP/gfx/bald/bald_heads_cadence_rift_sad.png",
    },
    dove      = {
        normal = "mods/AP/gfx/bald/bald_heads_dove_rift.png",
        happy  = "mods/AP/gfx/bald/bald_heads_dove_rift_happy.png",
        sad    = "mods/AP/gfx/bald/bald_heads_dove_rift_sad.png",
    },
    reaper    = {
        normal = "mods/AP/gfx/bald/bald_heads_reaper_rift.png",
        happy  = "mods/AP/gfx/bald/bald_heads_reaper_rift_happy.png",
        sad    = "mods/AP/gfx/bald/bald_heads_reaper_rift_sad.png",
    },
    nocturna  = {
        normal = "mods/AP/gfx/bald/bald_heads_nocturna_rift.png",
        happy  = "mods/AP/gfx/bald/bald_heads_nocturna_rift_happy.png",
        sad    = "mods/AP/gfx/bald/bald_heads_nocturna_rift_sad.png",
    },
    sync_suzu = {
        normal = "mods/AP/gfx/bald/bald_heads_sync_suzu_rift.png",
        happy  = "mods/AP/gfx/bald/bald_heads_sync_suzu_rift_happy.png",
        sad    = "mods/AP/gfx/bald/bald_heads_sync_suzu_rift_sad.png",
    },
}

local baldTrapExceptions = {
    Reaper        = true,
    Sync_Chaunter = true,
    Goldman_Goldman = true
}

local isBald = false
isBald = script.persist(function()
    return isBald
end)

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
    if head and head.sprite then
        local charKey = string.lower(entity.name)
        local texture
        if isUsingRiftSkin(entity, head) then
            local riftTextures = riftBaldTextureByChar[charKey]
            if riftTextures then
                local state = entity.CharacterSkins_skinReaction and entity.CharacterSkins_skinReaction.state
                if state == SkinReaction.State.HAPPY then
                    texture = riftTextures.happy
                elseif state == SkinReaction.State.SAD then
                    texture = riftTextures.sad
                else
                    texture = riftTextures.normal
                end
            end
        end
        head.sprite.texture = texture or baldTextureByChar[charKey] or baldTextureFallback
    end
end

-- sequence 1 runs after CharacterSkins (sequence -1) so the texture isn't overwritten
event.objectSpawn.add("APBaldTrapApplyOnSpawn",
    { order = "sprite", sequence = 1, filter = "characterWithAttachment" },
    function(ev)
        if isBald then
            applyBaldToEntity(ev.entity)
        end
    end
)

local function onReactionChange(ev)
    if isBald then applyBaldToEntity(ev.entity) end
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

-- Clear the trap when the run resets.
event.gameStateReset.add("APBaldTrapClearOnReset", { order = "resetRunVariables" }, function()
    isBald = false
end)

TrapHandler.register("BaldTrap", makeSimpleTrap({
    flyawayText = function(entity)
        return baldTrapExceptions[entity.name] and "Bald Trap negated!" or "Bald!"
    end,
    setup = function()
        if isBald then return false end
        return { anyBald = false }
    end,
    action = function(entity, ctx)
        if not baldTrapExceptions[entity.name] then
            applyBaldToEntity(entity)
            ctx.anyBald = true
        end
    end,
    after = function(ctx)
        isBald = ctx.anyBald
    end,
    alwaysSucceed = true,
}))
