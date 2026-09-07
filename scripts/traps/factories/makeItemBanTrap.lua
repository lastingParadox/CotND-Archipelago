local ecs       = require("system.game.Entities")
local inventory = require("necro.game.item.Inventory")
local itemBan   = require("necro.game.item.ItemBan")
local object    = require("necro.game.object.Object")

local trapSystem = require("AP.scripts.traps.trapSystem")

---Defines a trap that strips and bans every item carrying any of `opts.components`.
---@param opts table
---  Required:
---    name         string         Trap id.
---    flyaway      string
---    components   table<string>  Component names; item matches if it has any of these.
---  Optional:
---    voice            string?    Played per player.
---    sound            string?    Played per player at their world position.
---    banComponents    table?     Components to ban; defaults to opts.components.
---    deleteFloor      bool?      Delete non-equipped floor/shop items (default true).
---    deleteContainers bool?      Delete items from container storage (default false).
---    priceTagDelete   bool?      Delete price tags along with floor items (default true).
---@return table spec
local function makeItemBanTrap(opts)
    assert(opts.flyaway, "makeItemBanTrap: opts.flyaway is required")
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

    -- Delete matching non-equipped floor / shop items.
    local function sweepFloor()
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
    end

    -- Delete matching items stored in containers (chests, crates, etc.).
    local function sweepContainers()
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
                if matched then table.remove(items, i) end
            end
        end
    end

    return trapSystem.define({
        name    = opts.name,
        flyaway = opts.flyaway,
        voice   = opts.voice,
        sound   = opts.sound,
        apply   = function(ctx)
            local entity = ctx.entity
            if not entity.inventory then return false end

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
        end,
        finish  = function()
            if deleteFloor then sweepFloor() end
            if deleteContainers then sweepContainers() end
        end,
    })
end

return { makeItemBanTrap = makeItemBanTrap }
