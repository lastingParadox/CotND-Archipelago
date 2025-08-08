local CustomEntities = require("necro.game.data.CustomEntities")
local collision = require("necro.game.tile.Collision")
local minimapTheme = require("necro.game.data.tile.MinimapTheme")
local ping = require("necro.client.Ping")

CustomEntities.register({
    name = "AP_CharacterSelectorLobbyRandom",
    gameObject = {},
    position = {},
    interactable = {},
    interactableSelectCharacter = {},
    interactableSelectCharacterRandom = {},
    AP_interactableSelectCharacterLobby = {},
    collision = {
        mask = collision.Type.OBJECT
    },
    random = {},
    soundInteract = {
        sound = "minibossShake"
    },
    soundInteractFocus = {
        sound = "shrineActivate"
    },
    particlePuff = {},
    visibility = {},
    rowOrder = {
        z = 20
    },
    sprite = {
        height = 52,
        texture = "ext/level/shrine_chance.png",
        width = 35
    },
    spriteSheet = {},
    positionalSprite = {
        offsetX = -5,
        offsetY = -22
    },
    pingable = {
        type = ping.Type.CONTAINER
    },
    visualExtent = {
        height = 36,
        offsetX = 0,
        offsetY = -3,
        width = 24
    },
    silhouette = {},
    minimapStaticPixel = {
        color = minimapTheme.Color.SHRINE,
        depth = minimapTheme.Depth.SHRINE
    }
})

-- Event associated with this Entity is located in AP_CharacterSelectorLobby
