local customEntities = require "necro.game.data.CustomEntities"
local ecs = require "system.game.Entities"
local itemGeneration = require "necro.game.item.ItemGeneration"
local levelBuilder = require "necro.game.level.LevelBuilder"
local levelGenerator = require "necro.game.level.LevelGenerator"
local levelUtils = require "necro.game.level.LevelUtils"
local marker = require "necro.game.tile.Marker"
local object = require "necro.game.object.Object"
local soundtrack = require "necro.game.data.Soundtrack"

local apBossRushShop = {}

apBossRushShop.GENERATOR_TYPE = levelGenerator.Type.extend("BossRushShop")
apBossRushShop.ZONE = 2

local MERCHANT = "AP_BossRushMerchant"
local POTION = "MiscPotion"
local PRICE_TAG = "PriceTagGold"

-- The dungeon shopkeeper, plus the immunity the safe level already grants the players.
customEntities.extend({
    name = MERCHANT,
    template = customEntities.template.enemy("shopkeeper", 1),
    components = {
        editorHidden = {},
        lobbyImmunity = {},
        storage = {
			items = {
				"AP_ItemUseful"
			}
		},
    },
})

local SHOP_SLOT = customEntities.register({
    name = "AP_BossRushShopSlot",
    gameObject = {},
    position = {},
    AP_bossRushShopSlot = {},
})

-- Outer bounds including walls, laid out around the shop room's centre tile.
local SHOP_ROOM = { -6, -5, 13, 11 }
local EXIT_ROOM = { -3, -12, 7, 7 }
local SPAWN_ROOM = { -3, 8, 7, 7 }
local CORRIDOR = { -2, 5, 5, 4 }

-- The five tile mouth the exit room shares with the shop, and the three tile doorway below it.
local MOUTH_WIDTH = 5
local DOOR_WIDTH = 3

local EXIT_Y = -7
local SPAWN_Y = 11
local MERCHANT_Y = 0
local SIDE_TORCH_Y = 1

local SHOP_LABEL = "mod.AP.level.bossRushShop.label"
local LABEL_OFFSET_X = 3

-- The dead end above the stairs, one row below the exit room's pillar.
local BARRELS_POS = { { -1, -11 }, { 0, -10 }, { 1, -11 } }

-- Every other tile, so the wares sit apart with a clear margin at each wall.
local WARES_X = { -4, -2, 0, 2, 4 }

-- The merchant stands between the two rows; the potion closes the lower one.
local WARES_ROWS = {
    { y = MERCHANT_Y - 2 },
    { y = MERCHANT_Y + 2, potionIndex = #WARES_X },
}

local function rectBottom(rect)
    return rect[2] + rect[4] - 1
end

-- The lobby lights a room with 512 radius units per tile of its longest side; this spans the map.
local LEVEL_SPAN = math.max(SHOP_ROOM[3], rectBottom(SPAWN_ROOM) - EXIT_ROOM[2] + 1)
local TORCH_RADIUS = 512 * LEVEL_SPAN

local function room(level, rect)
    level.fillBox(rect, level.tile, "Floor")
    level.outlineBox(rect, level.tile, "UnbreakableWall")
end

-- level.torch picks the tileset's own wall light; the radius is widened off its default 1088.
local function torchPillar(level, x, y)
    level.tile(x, y, "UnbreakableWall")
    levelUtils.addEntityAttribute(level.torch(x, y), "lightSourceRadial", "outerRadius", TORCH_RADIUS)
end

-- Four pillars on the diagonals of a room's focal tile, as the boss antechambers have.
local function flankingPillars(level, x, y)
    for _, dx in ipairs({ -1, 1 }) do
        for _, dy in ipairs({ -1, 1 }) do
            torchPillar(level, x + dx, y + dy)
        end
    end
end

local function centredLine(level, y, width, tileName)
    level.lineH(-math.floor(width / 2), y, width, level.tile, tileName)
end

-- A sequence entry for the shop, taking its depth from the boss level it follows.
function apBossRushShop.levelEntry(previous)
    previous = previous or {}

    return {
        type = apBossRushShop.GENERATOR_TYPE,
        zone = apBossRushShop.ZONE,
        depth = previous.depth or apBossRushShop.ZONE,
        floor = (previous.floor or 0) + 1,
    }
end

event.levelGenerate.add("generateAPBossRushShop", apBossRushShop.GENERATOR_TYPE, function(ev)
    local level = levelBuilder.new(ev.options, "Zone" .. apBossRushShop.ZONE)

    room(level, SHOP_ROOM)
    room(level, EXIT_ROOM)
    room(level, SPAWN_ROOM)
    room(level, CORRIDOR)

    -- The exit room opens straight onto the shop; the spawn room is walled off behind doors.
    centredLine(level, rectBottom(EXIT_ROOM), MOUTH_WIDTH, "Floor")
    centredLine(level, SHOP_ROOM[2], MOUTH_WIDTH, "Floor")
    centredLine(level, rectBottom(SHOP_ROOM), DOOR_WIDTH, "DoorHorizontal")
    centredLine(level, SPAWN_ROOM[2], DOOR_WIDTH, "Floor")

    flankingPillars(level, 0, EXIT_Y)
    flankingPillars(level, 0, SPAWN_Y)
    torchPillar(level, SHOP_ROOM[1], SIDE_TORCH_Y)
    torchPillar(level, SHOP_ROOM[1] + SHOP_ROOM[3] - 1, SIDE_TORCH_Y)
    local doorFlank = math.floor(DOOR_WIDTH / 2) + 1
    torchPillar(level, -doorFlank, rectBottom(SHOP_ROOM))
    torchPillar(level, doorFlank, rectBottom(SHOP_ROOM))

    -- The far wall of the exit room, which the arena this copies puts a sealed door in.
    level.tile(0, EXIT_ROOM[2] + 1, "UnbreakableWall")

    for _, position in ipairs(BARRELS_POS) do
        level.entity(position[1], position[2], "Crate2")
    end

    level.tile(0, EXIT_Y, "Stairs")
    level.entity(0, MERCHANT_Y, MERCHANT)

    for _, x in ipairs({ -LABEL_OFFSET_X, LABEL_OFFSET_X }) do
        level.entity(x, MERCHANT_Y, "LabelBasic", {
            worldLabel = { offsetY = 0 },
            worldLabelTextPool = { key = SHOP_LABEL },
        })
    end

    for _, waresRow in ipairs(WARES_ROWS) do
        for index, x in ipairs(WARES_X) do
            level.entity(x, waresRow.y, SHOP_SLOT, {
                AP_bossRushShopSlot = { potion = index == waresRow.potionIndex },
            })
        end
    end

    ev.level = level.getData()
    ev.level.name = L("Shop", "mod.AP.level.bossRushShop")
    ev.level.markers = { { type = marker.Type.SPAWN, x = 0, y = SPAWN_Y } }
    ev.level.playerOptions = { isSafe = true }
    ev.level.music = {
        type = soundtrack.TrackType.ZONE,
        zone = apBossRushShop.ZONE,
        level = 2,
    }
end)

local function itemSlotName(itemName)
    local proto = itemName and ecs.getEntityPrototype(itemName)

    return proto and proto.itemSlot and proto.itemSlot.name or ""
end

-- Mirrors the vanilla shop tag so proximity, stealing and blood conversion all still apply.
local function attachPriceTag(item, merchant)
    if not (item and item.sale and item.itemPrice) then return end

    local tag = object.spawn(PRICE_TAG, item.position.x, item.position.y, {
        priceTagCostCurrency = { cost = item.itemPrice.coins },
        priceTagCostHealth = { cost = item.itemPrice.blood },
        priceTagShopkeeperProximity = { shopkeeper = merchant and merchant.id or 0 },
    })

    if tag then item.sale.priceTag = tag.id end
end

-- Top row first, then left to right, so every client draws the same stock from the shop pool.
local function orderedSlots()
    local slots = {}

    for slot in ecs.entitiesWithComponents({ "AP_bossRushShopSlot", "position" }) do
        slots[#slots + 1] = slot
    end

    table.sort(slots, function(a, b)
        if a.position.y ~= b.position.y then return a.position.y < b.position.y end
        return a.position.x < b.position.x
    end)

    return slots
end

local function stockSlot(slot, bannedSlots)
    if slot.AP_bossRushShopSlot.potion then
        return itemGeneration.maybeMarkSeen(POTION)
    end

    -- One item per equipment slot, as a vanilla shop does, until the pool runs dry.
    local itemName = itemGeneration.choice({ chanceType = "shop", bannedSlots = bannedSlots })
    if not itemName or itemName == "" then
        itemName = itemGeneration.choice({ chanceType = "shop" })
    end

    if itemName and itemName ~= "" then
        bannedSlots[itemSlotName(itemName)] = true
    end

    return itemName
end

local function findMerchant()
    for entity in ecs.entitiesWithComponents({ "shopkeeper", "position" }) do
        return entity
    end
end

event.levelLoad.add("apStockBossRushShop", { order = "initialItems", sequence = 1 }, function()
    local slots = orderedSlots()
    if #slots == 0 then return end

    local merchant = findMerchant()

    -- Banned per row, so each row stays varied without starving the row below it.
    local bannedSlotsByRow = {}

    for _, slot in ipairs(slots) do
        local row = slot.position.y
        bannedSlotsByRow[row] = bannedSlotsByRow[row] or {}

        local itemName = stockSlot(slot, bannedSlotsByRow[row])

        if itemName and itemName ~= "" then
            local item = object.spawn(itemName, slot.position.x, slot.position.y)
            attachPriceTag(item, merchant)
        end

        object.delete(slot)
    end
end)

return apBossRushShop
