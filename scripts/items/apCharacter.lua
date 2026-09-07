local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require("system.game.Entities")
local itemStorage = require "necro.game.item.ItemStorage"
local objectRenderer = require "necro.render.level.ObjectRenderer"
local perspective = require "necro.game.system.Perspective"
local render = require "necro.render.Render"
local sound = require "necro.audio.Sound"
local visualUpdate = require "necro.cycles.VisualUpdate"
local worldLabel = require "necro.game.system.WorldLabel"

local apCharacters = require("AP.scripts.utils.apCharacters")
local apGrants = require("AP.scripts.items.apGrants")
local apItemFactory = require("AP.scripts.items.apItemFactory")
local apPreview = require("AP.scripts.utils.apPreview")

-- Cadence's body stands in for the editor; a spawned carrier hides it and draws its own.
apItemFactory.define({
    name = "AP_Character",
    rawTexture = "ext/entities/player1_armor_body.png",
    hint = L("Character", "AP.item.character"),
    flyaway = L("Character Unlocked!", "AP.item.character.flyaway"),
    components = {
        AP_character = { name = "" },
    },
})

event.objectSpawn.add("apCharacterItemSetup", { order = "overrides", filter = { "AP_character", "!AP_buffCharacterShrine" } }, function(ev)
    local name = ev.entity.AP_character and ev.entity.AP_character.name
    if not name or name == "" then return end

    local proto = ecs.getEntityPrototype(name)
    local charName = proto and proto.friendlyName and proto.friendlyName.name or name

    if ev.entity.AP_flyaway then
        ev.entity.AP_flyaway.text = charName .. " Unlocked!"
    end
    if ev.entity.AP_hintLabel then
        ev.entity.AP_hintLabel.text = charName
    end

    ev.entity.sprite.visible = false
end)

local function getOffsetY(name)

    if name == "Merlin" then
        return -8
    elseif name == "Janitor" then
        return -7
    elseif name == "AP_Hintmaster" then
        return -5
    end

    return -2
end

event.render.add("apCharacterRender", { order = "objects", sequence = 1 }, function()
    for entity in ecs.entitiesWithComponents({ "AP_character", "visibility", "position", "!AP_buffCharacterShrine" }) do
        if entity.visibility.visible then
            local proto = apPreview.spriteSource(entity)

            if proto ~= entity then
                apPreview.draw(proto, {
                    entity = entity,
                    offsetY = getOffsetY(proto.name),
                    -- The item's own shadow is already drawn by renderShadows.
                    previewArgs = { shadow = false, outline = apPreview.checkOutline(entity) },
                })
            end
        end
    end
end)

-- Retextures the carrier's content visual with the character's own sprite.
local function drawStoredCharacter(draw, item, container, offset)
    local source = apPreview.spriteSource(item)
    if source == item then return end

    local visual = objectRenderer.getContentVisual(item, container)
    visual.rect[1] = visual.rect[1] + offset

    draw(apPreview.retextureContent(visual, item, source))
end

-- Mirrors "renderContents", which draws stored items under a monocle or the editor.
event.render.add("apCharacterContents", { order = "contents", sequence = 1 }, function()
    local draw = render.getBuffer(render.Buffer.OBJECT).draw

    for _, component in ipairs(perspective.getListAttribute(perspective.Attribute.CONTENTS_VISIBILITY_GROUPS)) do
        for container in ecs.entitiesWithComponents({ "storage", "visibility", "sprite", "positionalSprite", component }) do
            if container.visibility.visible and container.sprite.visible then
                local items = itemStorage.getItems(container)

                for i, item in ipairs(items) do
                    if item and item.sprite and item.AP_character then
                        drawStoredCharacter(draw, item, container, (i - (#items + 1) * 0.5) * 12)
                    end
                end
            end
        end
    end
end)

-- Unlocking is recorded when the item is logged, so a grant only has to announce it.
local function greetPlayers(sound_, players)
    for _, playerEntity in ipairs(players) do
        if playerEntity then sound.playFromEntity(sound_, playerEntity) end
    end
end

local function refreshLobby()
    if currentLevel.isLobby() then
        visualUpdate.trigger()
        worldLabel.updateAll()
    end
end

local GREETING_PREFIXES = {
    { prefix = "Sync_",      sound = nil },
    { prefix = "Coldsteel_", sound = "Coldsteel_MikuHi" },
    { prefix = "Goldman_",   sound = "Goldman_GoldmanHi" },
}

local function greetingSound(itemId)
    for _, entry in ipairs(GREETING_PREFIXES) do
        if itemId:sub(1, #entry.prefix) == entry.prefix then
            return entry.sound or (itemId:sub(#entry.prefix + 1):lower() .. "Hi")
        end
    end

    return itemId:lower() .. "Hi"
end

apGrants.defineFamily({
    order = 20,
    match = function(itemId) return apCharacters.isCharacter(itemId) end,
    apply = function(_, _, ctx)
        if not ctx.silent then greetPlayers(greetingSound(ctx.item.item), ctx.players) end
        refreshLobby()
    end,
})

apGrants.defineFamily({
    order = 21,
    match = function(itemId) return apCharacters.isNPC(itemId) end,
    apply = function(_, _, ctx)
        if not ctx.silent then
            for _, playerEntity in ipairs(ctx.players) do
                if playerEntity then
                    local greeting = playerEntity.voiceGreeting and playerEntity.voiceGreeting.sound
                    sound.playFromEntity(greeting or "doorOpen", playerEntity)
                end
            end
        end

        refreshLobby()
    end,
})
