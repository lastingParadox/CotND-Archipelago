local currentLevel = require "necro.game.level.CurrentLevel"
local visualUpdate = require "necro.cycles.VisualUpdate"

local apItemFactory = require("AP.scripts.items.apItemFactory")
local progression = require("AP.scripts.client.progression")

local function refreshLobby()
    if currentLevel.isLobby() then visualUpdate.trigger() end
end

local function unlockZone(zone)
    return function()
        if zone > 0 then
            progression.addZoneAccess(zone)
        else
            progression.addProgressiveZoneAccess()
        end

        refreshLobby()
    end
end

apItemFactory.define({
    name = "AP_ProgressiveZoneAccess",
    texture = "items/keys/progressive_access_key.png",
    hint = L("Progressive Zone Access", "AP.item.accessKey.progressive"),
    flyaway = L("Progressive Zone Access Obtained!", "AP.item.accessKey.progressive.flyaway"),
    components = {
        spriteSheet = { frameX = 1, frameY = 1 },
    },
    grant = {
        item = "APProgressiveZoneAccess",
        sound = "shrineActivate",
        apply = unlockZone(0),
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
    grant = {
        item = "APZone1Access",
        sound = "shrineActivate",
        apply = unlockZone(1),
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
    grant = {
        item = "APZone2Access",
        sound = "shrineActivate",
        apply = unlockZone(2),
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
    grant = {
        item = "APZone3Access",
        sound = "shrineActivate",
        apply = unlockZone(3),
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
    grant = {
        item = "APZone4Access",
        sound = "shrineActivate",
        apply = unlockZone(4),
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
    grant = {
        item = "APZone5Access",
        sound = "shrineActivate",
        apply = unlockZone(5),
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
    grant = {
        item = "APCharRoomKey",
        sound = "shrineActivate",
        apply = function()
            progression.unlockCharacterRoom()
            refreshLobby()
        end,
    },
})
