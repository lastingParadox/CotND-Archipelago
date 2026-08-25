local collision = require "necro.game.tile.Collision"
local flyaway = require "necro.game.system.Flyaway"
local itemPickup = require "necro.game.item.ItemPickup"
local object = require "necro.game.object.Object"
local player = require "necro.game.character.Player"
local sound = require "necro.audio.Sound"
local visualUpdate = require "necro.cycles.VisualUpdate"
local winScreen = require "necro.render.WinScreen"

local apReplay = require("AP.scripts.utils.apReplay")
local apStorage = require("AP.scripts.client.storage")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")
local trapHandler = require("AP.scripts.traps.trapHandler")

local apGrants = {}

local byItemId = {}
local byCarrier = {}
local families = {}
local fallback = nil

local function generateRadialOffsets(maxRadius)
    local offsets = {}

    -- center first
    table.insert(offsets, { 0, 0 })

    for r = 1, maxRadius do
        -- cardinals
        table.insert(offsets, { -r, 0 })
        table.insert(offsets, { r, 0 })
        table.insert(offsets, { 0, -r })
        table.insert(offsets, { 0, r })

        -- diagonals
        table.insert(offsets, { -r, -r })
        table.insert(offsets, { -r, r })
        table.insert(offsets, { r, -r })
        table.insert(offsets, { r, r })

        -- edges between
        for i = 1, r - 1 do
            table.insert(offsets, { -r, -i })
            table.insert(offsets, { -r, i })
            table.insert(offsets, { r, -i })
            table.insert(offsets, { r, i })

            table.insert(offsets, { -i, -r })
            table.insert(offsets, { i, -r })
            table.insert(offsets, { -i, r })
            table.insert(offsets, { i, r })
        end
    end

    return offsets
end

local radialOffsets = generateRadialOffsets(20)

---Lays an item at the feet of everyone in the run, which is how AP delivers anything it
---cannot hand over directly. The search fans out from the tile below each player, so a
---drop in a crowded room still lands somewhere reachable. The player who already carried
---this one off a chest is skipped: they have it.
---@param ctx table|nil The grant context; omitted when replaying from the queue.
---@return boolean spawned Whether it landed for anyone.
function apGrants.drop(itemType, ctx)
    if not (itemType and apUtils.isAPContext()) or winScreen.isActive() then return false end

    local consumed = apStorage.saveData.chestConsumedLocations or {}
    local collector = ctx and consumed[tostring(ctx.item.location_code)]
    local players = ctx and ctx.players or player.getPlayerEntities()
    local spawned = false

    for _, playerEntity in ipairs(players) do
        if playerEntity and playerEntity.position and playerEntity.id ~= collector then
            local item = object.spawn(itemType,
                playerEntity.position.x, playerEntity.position.y + 1)

            if item then
                object.moveToNearbyVacantTile(item, collision.Group.ITEM_PLACEMENT, 0, radialOffsets)
                spawned = true
            end
        end
    end

    if spawned then
        sound.play("secretFound", players[1].position.x, players[1].position.y + 1)
        visualUpdate.trigger()
    end

    return spawned
end

---Declares a filler that is really an ordinary CotND item. In a run it is laid out like
---any other item, skipping whoever already carried it off the location in person; with no
---run to lay it into -- bought from the lobby shop -- it waits in the queue for the start
---of the next one, since nothing on the Python side replays a filler the mod was sent.
---@param apItemId string The AP item id, e.g. "APBomb".
---@param itemType string The entity it really is, e.g. "Bomb".
function apGrants.defineItemFiller(apItemId, itemType)
    trapHandler.register(apItemId, function() return apGrants.drop(itemType) end)

    return apGrants.define({
        item = apItemId,
        apply = function(_, _, ctx)
            if apUtils.isAPContext() then return apGrants.drop(itemType, ctx) end

            trapHandler.queueTrap(apItemId)
        end,
    })
end

---Declares how one AP item takes effect, next to the carrier that represents it.
function apGrants.define(spec)
    if spec.item then byItemId[spec.item] = spec end
    if spec.carrier then byCarrier[spec.carrier] = spec end

    return spec
end

---A grant rule for a whole class of items rather than one id
---@param spec table `{ order, match(itemId), sound?, apply }`
function apGrants.defineFamily(spec)
    families[#families + 1] = spec
    table.sort(families, function(a, b) return a.order < b.order end)

    return spec
end

---What a grant does when nothing else claims it.
function apGrants.defineFallback(spec)
    fallback = spec
    return spec
end

---The rule that governs an AP item id, for the grant path to run.
function apGrants.resolve(itemId)
    if not itemId then return nil end
    if byItemId[itemId] then return byItemId[itemId] end

    for _, family in ipairs(families) do
        if family.match(itemId) then return family end
    end

    return fallback
end

-- A carrier standing on an AP location has a grant following it, so applying it here has
-- to be recorded; one that does not -- diamonds dug out of a wall -- simply applies.
local function locationCode(item)
    local tag = item.AP_locationItem
    local code = tag and tag.locationCode

    return code ~= nil and code ~= "" and code or nil
end

-- Ahead of "priceTag" itself: a carrier that refuses to be taken must do so before the
-- player is charged for it.
event.objectTryCollectItem.add("apGateGrantPickup", { order = "priceTag", sequence = -100 }, function(ev)
    local spec = byCarrier[ev.item.name]
    if not (spec and spec.gate) then return end
    if ev.result ~= itemPickup.Result.SUCCESS then return end

    local refusal = spec.gate(ev.entity, ev.item)
    if not refusal then return end

    flyaway.create({ entity = ev.item, text = refusal })
    sound.playFromEntity("error", ev.item)
    ev.result = itemPickup.Result.FAILURE
end)

-- Ahead of the carrier's own removal at this same order, and after "priceTag", so a shop
-- copy the player could not afford has already been failed.
event.objectTryCollectItem.add("apApplyGrantOnPickup", { order = "priceTag", sequence = 1 }, function(ev)
    if not apUtils.isAPContext(ev.entity) then return end
    if ev.result ~= itemPickup.Result.SUCCESS then return end

    local spec = byCarrier[ev.item.name]
    if not spec then return end

    local code = locationCode(ev.item)

    -- Every chest of a kind offers the same location until one is opened, so two players
    -- can carry off the same item on the same turn.
    if code and progression.isLocationConsumed(code) then return end

    if not apReplay.firstThisTurn("grant:" .. ev.item.id) then return end

    if spec.apply(ev.entity, ev.item) == false then return end

    if code then progression.markLocationConsumed(code) end
end)

return apGrants
