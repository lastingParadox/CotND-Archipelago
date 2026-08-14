local collision      = require "necro.game.tile.Collision"
local currentLevel   = require "necro.game.level.CurrentLevel"
local inventory      = require "necro.game.item.Inventory"
local itemBan        = require "necro.game.item.ItemBan"
local itemPickup     = require "necro.game.item.ItemPickup"
local moveAnimations = require "necro.render.level.MoveAnimations"
local object         = require "necro.game.object.Object"
local player         = require "necro.game.character.Player"
local soulLink       = require "necro.game.character.SoulLink"
local sound          = require "necro.audio.Sound"

local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

local dadLinks = {}
dadLinks = script.persist(function()
    return dadLinks
end)

local function createDadlinkIndex(dad)
    return tostring(dad.id) .. "-" .. tostring(dad.dad and dad.dad.playerID or "x")
end

local function scatterInventory(playerEntity, dadInventory)
    local x = playerEntity and playerEntity.position and playerEntity.position.x or 0
    local y = playerEntity and playerEntity.position and playerEntity.position.y or 0

    local radius = 1
    local dx     = -radius
    local dy     = -radius
    local mask   = collision.mask(collision.Group.SOLID, collision.Type.ITEM, collision.Type.TRAP)

    for _, itemName in ipairs(dadInventory) do
        while collision.check(x + dx, y + dy, mask) or math.abs(dx) + math.abs(dy) == 1 do
            dx = dx + 1
            if dy == radius then
                dx = dx + 1
                if dx > 6 then
                    dy   = 0
                    dx   = 0
                    mask = 0
                    break
                elseif radius < dx then
                    radius = dx
                    dx     = -radius
                end
                dy = -radius
            else
                dy = math.abs(dx) == radius and dy + 1 or radius
            end
        end
        local item = object.spawn(itemName, x + dx, y + dy)
        moveAnimations.play(item, moveAnimations.Type.HOP, x, y)
    end
end

event.objectTryCollectItem.add("apDadItemCheck", { order = "pickupEffects", filter = "dad" }, function(ev)
    local dadIndex = createDadlinkIndex(ev.entity)
    if dadLinks[dadIndex] and ev.result == itemPickup.Result.SUCCESS then
        local dadEntry = dadLinks[dadIndex]
        local items    = inventory.getItems(dadEntry.dad)
        dadEntry.inventory = {}
        for _, item in ipairs(items) do
            if not itemBan.isBanned(ev.entity, item, itemBan.Flag.LOSS_SCATTER) then
                dadEntry.inventory[#dadEntry.inventory + 1] = item.name
            end
        end
    end
end)

event.levelLoad.add("apClearDadLinks", { order = "entities" }, function()
    for _, entry in pairs(dadLinks) do
        if entry.link and entry.dad and currentLevel.getSeed() == entry.seed then
            if #entry.inventory > 0 then
                local playerEntity = player.getPlayerEntity(entry.dad.dad.playerID)
                scatterInventory(playerEntity, entry.inventory)
            end
        end
    end
    dadLinks = {}
end)

TrapHandler.register("DadTrap", makeSummonTrap({
    flyawayText = "Dad trap!",
    variants    = { DorianDad = 1 },
    min         = 1,
    max         = 1,
    radius      = 3,
    spawnProps  = false,
    onSpawn = function(dad, t, playerEntity)
        dad.dad.playerID = playerEntity.controllable.playerID
        local link = soulLink.create("SoulLinkDad")
        soulLink.attach(link, playerEntity)
        soulLink.attach(link, dad)
        dadLinks[createDadlinkIndex(dad)] = {
            dad       = dad,
            link      = link,
            inventory = { "WeaponDaggerDad", "RingMight" },
            seed      = currentLevel.getSeed(),
        }
        sound.playFromEntity("dorianHi", dad)
    end,
}))
