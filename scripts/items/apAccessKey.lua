local apItemFactory = require("AP.scripts.items.apItemFactory")

apItemFactory.define({
    name = "AP_ProgressiveZoneAccess",
    texture = "items/keys/progressive_access_key.png",
    hint = L("Progressive Zone Access", "AP.item.accessKey.progressive"),
    flyaway = L("Progressive Zone Access Obtained!", "AP.item.accessKey.progressive.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})

apItemFactory.define({
    name = "AP_Zone1Access",
    texture = "items/keys/zone_1_access_key.png",
    hint = L("Zone 1 Access", "AP.item.accessKey.zone1"),
    flyaway = L("Zone 1 Access Obtained!", "AP.item.accessKey.zone1.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})

apItemFactory.define({
    name = "AP_Zone2Access",
    texture = "items/keys/zone_2_access_key.png",
    hint = L("Zone 2 Access", "AP.item.accessKey.zone2"),
    flyaway = L("Zone 2 Access Obtained!", "AP.item.accessKey.zone2.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})

apItemFactory.define({
    name = "AP_Zone3Access",
    texture = "items/keys/zone_3_access_key.png",
    hint = L("Zone 3 Access", "AP.item.accessKey.zone3"),
    flyaway = L("Zone 3 Access Obtained!", "AP.item.accessKey.zone3.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})

apItemFactory.define({
    name = "AP_Zone4Access",
    texture = "items/keys/zone_4_access_key.png",
    hint = L("Zone 4 Access", "AP.item.accessKey.zone4"),
    flyaway = L("Zone 4 Access Obtained!", "AP.item.accessKey.zone4.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})

apItemFactory.define({
    name = "AP_Zone5Access",
    texture = "items/keys/zone_5_access_key.png",
    hint = L("Zone 5 Access", "AP.item.accessKey.zone5"),
    flyaway = L("Zone 5 Access Obtained!", "AP.item.accessKey.zone5.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})

apItemFactory.define({
    name = "AP_CharRoomKey",
    texture = "items/keys/character_room_access_key.png",
    hint = L("Character Room Key", "AP.item.accessKey.characterRoom"),
    flyaway = L("Character Room Key Obtained!", "AP.item.accessKey.characterRoom.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
})
