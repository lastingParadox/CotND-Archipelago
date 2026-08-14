local ecs = require("system.game.Entities")
local hasNecroEdit, _ = pcall(require, "NecroEdit.NecroEdit")

local FILTER_GROUP_ITEM = 4   -- editorCategory.FilterGroup.ITEM
local FILTER_GROUP_OBJECT = 5 -- editorCategory.FilterGroup.OBJECT

local function byName(a, b)
    return a.name < b.name
end

-- Splits the tagged prototypes into the two tabs and claims them in ev.set, which
-- is what stops the built-in categories from also listing them.
local function collectTagged(set)
    local items, objects = {}, {}

    for _, typeName in ipairs(ecs.getEntityTypesWithComponents({ "AP_editorCategory" })) do
        local proto = ecs.getEntityPrototype(typeName)

        if proto and proto.sprite and not set[proto] then
            set[proto] = true

            local bucket = proto.item and items or objects
            bucket[#bucket + 1] = proto
        end
    end

    table.sort(items, byName)
    table.sort(objects, byName)

    return items, objects
end

if hasNecroEdit then
    -- Ahead of NecroEdit's own "entities" pass so these are claimed before the
    -- vanilla categories can absorb them; sortResults still places the tabs last.
    event.NecroEdit_categoryInit.add("apEditorItems", { order = "entities", sequence = -1 }, function(ev)
        local items, objects = collectTagged(ev.set)

        if #items > 0 then
            ev.result[#ev.result + 1] = {
                label = "AP Items",
                entities = items,
                id = 700,
                filterGroup = FILTER_GROUP_ITEM,
            }
        end

        if #objects > 0 then
            ev.result[#ev.result + 1] = {
                label = "AP Entities",
                entities = objects,
                id = 701,
                filterGroup = FILTER_GROUP_OBJECT,
            }
        end
    end)
end
