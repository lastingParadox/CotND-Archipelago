local flyaway = require "necro.game.system.Flyaway"
local turn = require "necro.cycles.Turn"

local apFlyaways = {}
local queue = {}
local activeByEntity = {}
local OPACITY_THRESHOLD = 1.25

queue = script.persist(function()
    return queue
end)

-- Outside the snapshot on purpose: surviving a rollback is what lets a replayed
-- turn recognise its own work.
local shownKeys = {}

local BLOCKED_TEXT = "Exit stairs unlocked!"

local function isBlockedFlyawayActive()
    local function scan(list)
        for _, msg in ipairs(list or {}) do
            if msg.text == BLOCKED_TEXT then
                local opacity = msg.opacity
                if opacity == nil or opacity > OPACITY_THRESHOLD then
                    return true
                end
            end
        end
        return false
    end

    return scan(flyaway.getLocal())
end

local function getFlyawayEntityKey(flyawayData)
    local entity = flyawayData and flyawayData.entity
    if entity and entity.id then
        return entity.id
    end

    return "__global__"
end

function apFlyaways.addToFlyawayQueue(flyawayData)
    local turnID = turn.getActiveTurnID()
    if turnID then
        local key = table.concat({
            turnID,
            getFlyawayEntityKey(flyawayData),
            tostring(flyawayData and flyawayData.text),
        }, "\0")

        if shownKeys[key] then return end
        shownKeys[key] = true
    end

    table.insert(queue, {
        data = flyawayData,
        instance = nil
    })
end

event.tick.add("apFlyawayQueueTick", { order = "flyaway", sequence = 1 }, function()
    if isBlockedFlyawayActive() then return end

    for key, active in pairs(activeByEntity) do
        local opacity = active.instance and active.instance.opacity or 1
        if opacity <= OPACITY_THRESHOLD then
            activeByEntity[key] = nil
        end
    end

    local nextIndex = nil
    local nextItem = nil
    for i, item in ipairs(queue) do
        local key = getFlyawayEntityKey(item.data)
        if not activeByEntity[key] then
            nextIndex = i
            nextItem = item
            break
        end
    end

    if not nextIndex or not nextItem then return end

    table.remove(queue, nextIndex)

    flyaway.create(nextItem.data)

    local locals = flyaway.getLocal()
    nextItem.instance = locals[#locals]

    local key = getFlyawayEntityKey(nextItem.data)
    activeByEntity[key] = nextItem
end)

event.gameStateLevel.add("apResetLocalFlyaways", { order = "resetLevelVariables", sequence = 1 }, function()
    activeByEntity = {}
    shownKeys = {}
end)

event.gameStateReset.add("apResetLocalFlyaways", { order = "resetRunVariables", sequence = 1 }, function()
    activeByEntity = {}
    shownKeys = {}
end)

return apFlyaways
