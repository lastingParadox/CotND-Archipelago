local ecs = require("system.game.Entities")

local apItemFactory = require("AP.scripts.items.apItemFactory")
local apPreview = require("AP.scripts.utils.apPreview")

-- Sprite is hidden; the character is drawn via event.render below.
apItemFactory.define({
    name = "AP_Character",
    rawTexture = "",
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
    if ev.entity.AP_itemHintLabel then
        ev.entity.AP_itemHintLabel.text = charName
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
            local name = entity.AP_character and entity.AP_character.name
            if name and name ~= "" then
                apPreview.draw(name, {
                    entity = entity,
                    offsetY = getOffsetY(name),
                    -- The item's own shadow is already drawn by renderShadows.
                    previewArgs = { shadow = false },
                })
            end
        end
    end
end)
