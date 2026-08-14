local ecs       = require("system.game.Entities")
local inventory = require("necro.game.item.Inventory")
local itemBan   = require("necro.game.item.ItemBan")
local object    = require("necro.game.object.Object")
local player    = require("necro.game.character.Player")
local sound     = require("necro.audio.Sound")
local voice     = require("necro.audio.Voice")

local apFlyaways = require("AP.scripts.ui.apFlyaways")

---Creates a trap that removes items from player inventories, bans their component
---types from future generation, and optionally deletes matching items from the
---floor and/or containers.
---
---An item "matches" if it has ANY of the listed `opts.components`.
---
---@param opts table
---  Required:
---    flyawayText  string
---    components   table<string>   Component names; item matches if it has any of these.
---  Optional:
---    voice            string?    Played per player via voice.tryPlay.
---    sound            string?    Played per player at their world position.
---    banComponents    table?     Components to ban; defaults to opts.components.
---    deleteFloor      bool?      Delete non-equipped floor/shop items (default true).
---    deleteContainers bool?      Delete items from container storage (default false).
---    priceTagDelete   bool?      Delete price tags along with floor items (default true).
---@return function trapFn
local function makeItemBanTrap(opts)
    assert(opts.flyawayText, "makeItemBanTrap: opts.flyawayText is required")
    assert(opts.components and #opts.components > 0,
        "makeItemBanTrap: opts.components must be a non-empty table")

    local deleteFloor      = opts.deleteFloor      ~= false  -- default true
    local deleteContainers = opts.deleteContainers == true   -- default false
    local priceTagDelete   = opts.priceTagDelete   ~= false  -- default true
    local banComponents    = opts.banComponents or opts.components

    -- Returns true when an entity has any of the listed components.
    local function matchesEntity(item)
        for _, comp in ipairs(opts.components) do
            if item[comp] then return true end
        end
        return false
    end

    -- Returns true when a prototype type name has any of the listed components.
    local function matchesType(typeName)
        for _, comp in ipairs(opts.components) do
            if ecs.typeHasComponent(typeName, comp) then return true end
        end
        return false
    end

    return function(ev)
        local trapSuccess = false

        -- Remove matching items from player inventories and ban their components.
        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end
            if not entity.inventory then goto continue end

            local toDelete = {}
            for _, item in ipairs(inventory.getItems(entity)) do
                if matchesEntity(item) then
                    toDelete[#toDelete + 1] = item
                end
            end
            for _, item in ipairs(toDelete) do
                object.delete(item)
            end

            if entity.inventoryBannedItems and entity.inventoryBannedItems.components then
                for _, comp in ipairs(banComponents) do
                    entity.inventoryBannedItems.components[comp] = itemBan.Type.GENERATION_ALL
                end
            end

            if opts.voice then voice.tryPlay(entity, opts.voice) end
            if opts.sound then sound.play(opts.sound, entity.position.x, entity.position.y) end

            apFlyaways.addToFlyawayQueue({ entity = entity, text = opts.flyawayText })
            trapSuccess = true

            ::continue::
        end

        -- Delete matching non-equipped floor / shop items.
        if deleteFloor then
            local levelItems = {}
            for levelItem in ecs.entitiesWithComponents({ "item" }) do
                if levelItem.item and not levelItem.item.equipped and matchesEntity(levelItem) then
                    levelItems[#levelItems + 1] = levelItem
                end
            end
            for _, levelItem in ipairs(levelItems) do
                if priceTagDelete and levelItem.sale and levelItem.sale.priceTag ~= 0 then
                    object.delete(ecs.getEntityByID(levelItem.sale.priceTag))
                end
                object.delete(levelItem)
            end
            if #levelItems > 0 then trapSuccess = true end
        end

        -- Delete matching items stored in containers (chests, crates, etc.).
        if deleteContainers then
            for container in ecs.entitiesWithComponents({ "storage" }) do
                local items = container.storage.items
                for i = #items, 1, -1 do
                    local entry = items[i]
                    local matched
                    if type(entry) == "string" then
                        matched = matchesType(entry)
                    else
                        local storedItem = ecs.getEntityByID(entry)
                        matched = storedItem and matchesEntity(storedItem)
                        if matched then object.delete(storedItem) end
                    end
                    if matched then
                        table.remove(items, i)
                        trapSuccess = true
                    end
                end
            end
        end

        return trapSuccess
    end
end

return { makeItemBanTrap = makeItemBanTrap }
