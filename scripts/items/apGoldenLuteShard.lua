local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

apItemFactory.define({
    name = "AP_GoldenLuteShard",
    texture = "items/golden_lute_shard.png",
    hint = L("Golden Lute Shard", "AP.item.goldenLuteShard"),
    flyaway = L("Golden Lute Shard Obtained!", "AP.item.goldenLuteShard.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
        normalAnimation = { frames = { 1, 2, 3, 4 } },
    },
    grant = {
        item = "APGoldenLuteShard",
        sound = "pickupGeneral",
        apply = function() progression.addGoldenLuteShard() end,
    },
})
