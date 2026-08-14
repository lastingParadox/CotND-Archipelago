local apUtils        = require "AP.scripts.utils.apUtils"
local collision      = require "necro.game.tile.Collision"
local currentLevel   = require "necro.game.level.CurrentLevel"
local itemGeneration = require "necro.game.item.ItemGeneration"
local object         = require "necro.game.object.Object"
local placementUtils = require "necro.game.level.PlacementUtils"
local player         = require "necro.game.character.Player"
local progression    = require "AP.scripts.client.progression"

local goldman = {}

local function isGoldmanBuff()
    return apUtils.isAPContext() and progression.getCharacterBuff("Shovel Knight")
end

local function spawnExtraDigspot()
    local coords = placementUtils.randomTile {
        minSpawnDistance = 40,
        collisionMask = collision.Group.PLAYER_PLACEMENT,
    }
    if coords then
        object.spawn("Goldman_CrackTreasure", coords[1], coords[2])
    end
end

event.levelLoad.add("apGoldmanBuffExtraDigspots", { order = "initialItems", sequence = 0 }, function(level)
    if not isGoldmanBuff() then return end
    if not currentLevel.isRegularFloor() or level.zone == 4 then return end
    if not player.firstWithComponent("Goldman_traitSpawnCrackTreasure") then return end
    spawnExtraDigspot()
    spawnExtraDigspot()
end)

event.objectSpawn.add("apGoldmanBuffBetterLoot", {
    filter = "Goldman_CrackTreasure",
    order = "storageInit",
    sequence = 1,
}, function(ev)
    if not isGoldmanBuff() then return end
    local items = ev.entity.storage and ev.entity.storage.items
    if not items or #items == 0 then return end
    if items[1] == "ResourceCoin10" then
        items[1] = itemGeneration.choice({ chanceType = "lockedChest" })
    end
end)

function goldman.apply() end
function goldman.revoke() end
return goldman
