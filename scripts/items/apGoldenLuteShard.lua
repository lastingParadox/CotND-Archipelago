local apItemFactory = require("AP.scripts.items.apItemFactory")

apItemFactory.define({
    name = "AP_GoldenLuteShard",
    texture = "GoldenLuteShard.png",
    hint = L("Golden Lute Shard", "AP.item.goldenLuteShard"),
    flyaway = L("Golden Lute Shard Obtained!", "AP.item.goldenLuteShard.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
        normalAnimation = { frames = { 1, 2, 3, 4 } },
    },
})
