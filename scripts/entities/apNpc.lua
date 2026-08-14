local customEntities = require("necro.game.data.CustomEntities")

local function makeApNpc(name, components)
    components.AP_editorCategory = {}

    return customEntities.extend {
        name = name,
        template = customEntities.template.enemy("bossmaster"),
        components = components,
    }
end

makeApNpc("AP_Hintmaster", {
    sprite = {
        texture = "mods/AP/gfx/entities/Hintmaster.png",
        numFrames = 4,
        width = 29,
        height = 34,
    },
    friendlyName = {
        name = "Hintmaster"
    },
    positionalSprite = {
        offsetX = -2,
        offsetY = -3
    },
})

makeApNpc("AP_Buffmaster", {
    sprite = {
        texture = "ext/entities/npc_transmogrifier.png",
        numFrames = 4,
        width = 26,
        height = 27,
    },
    friendlyName = {
        name = "Buffmaster"
    },
    positionalSprite = {
        offsetX = 1,
        offsetY = 2
    },
})
