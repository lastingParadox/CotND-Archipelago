local gameDLC = require "necro.game.data.resource.GameDLC"

local apLog = require("AP.scripts.utils.log").apLog
local apVersion = require("AP.scripts.utils.version")
local apStorage = require("AP.scripts.client.storage")
local apTypes = require("AP.scripts.utils.types")
local handlers = require("AP.scripts.client.initHandlers")
local itemHandler = require("AP.scripts.client.handlers.items")
local locationHandler = require("AP.scripts.client.handlers.locations")
local saveUpdateHandler = require("AP.scripts.client.handlers.saveUpdate")
local apUtils = require("AP.scripts.utils.apUtils")
local progression = require("AP.scripts.client.progression")

local function buildNpcTable(npc_dict)
    local result = {}
    if npc_dict ~= nil and next(npc_dict) ~= nil then
        for npc, info in pairs(npc_dict) do
            result[npc] = {
                unlocked = false,
                zone = info.zone,
                level = info.level,
                unlockType = info.unlockType,
            }
        end
    else
        local LOBBY_NPCS = { "Beastmaster", "Merlin", "Hintmaster", "Weaponmaster", "Diamond Dealer" }
        for _, npc in ipairs(LOBBY_NPCS) do
            result[npc] = { unlocked = true }
        end
    end
    return result
end

local function arrayToTable(arr, defaultValue)
    local t = {}
    for _, v in ipairs(arr or {}) do
        t[v] = defaultValue
    end
    return t
end

local function convertDeathlinkType(str)
    local t = apTypes.DeathlinkTypes.TEMPO
    if str == "Absolute" then
        t = apTypes.DeathlinkTypes.ABSOLUTE
    elseif str == "Marv" then
        t = apTypes.DeathlinkTypes.MARV
    end
    if t == apTypes.DeathlinkTypes.MARV and not gameDLC.isAmplifiedLoaded() then
        return apTypes.DeathlinkTypes.TEMPO
    end
    return t
end

local function buildPricing(p)
    p = p or {}
    local gen = p.general_price_range or {}
    local fil = p.filler_price_range or {}
    local use = p.useful_price_range or {}
    local pro = p.progression_price_range or {}
    return {
        type        = p.type or 0,
        general     = { min = gen.min or 1,  max = gen.max or 10 },
        filler      = { min = fil.min or 1,  max = fil.max or 4  },
        useful      = { min = use.min or 2,  max = use.max or 8  },
        progression = { min = pro.min or 4,  max = pro.max or 10 },
    }
end

local function applyState(data)
    local saveData = apStorage.saveData

    -- Fields present on every State packet (init and reconnect)
    saveData.deathlink    = data.deathlink or false
    saveData.traplink     = data.traplink or false
    saveData.hintBaseCost = data.hint_cost or 10

    -- Computed + non-derivable fields from Python's save state
    for snakeKey, camelKey in pairs(saveUpdateHandler.FIELD_MAP) do
        local value = data[snakeKey]
        if value ~= nil then
            saveData[camelKey] = value
        end
    end

    -- One-time slot config, only sent on first connect
    if data.init then
        saveData.goal               = data.goal
        saveData.goalRequired       = data.goal_required
        -- Resolved by the client, so the spacing rule lives only in the apworld.
        saveData.zoneProgressFloors = arrayToTable(data.zone_progress_floors or { 2 }, true)
        saveData.deathlinkType      = convertDeathlinkType(data.death_link_type)
        saveData.deathlinkTrigger   = data.death_link_trigger or "Game Over"
        saveData.enabledDLCs        = arrayToTable(data.dlc, true)
        -- Seed included modes as locked without clobbering Python's unlocks above.
        local seededModes = arrayToTable(data.included_extra_modes, false)
        for mode, unlocked in pairs(saveData.extraModes or {}) do
            if unlocked then seededModes[mode] = true end
        end
        saveData.extraModes         = seededModes
        saveData.characterBlacklist = arrayToTable(data.character_blacklist, true)
        saveData.characterUnlocks   = data.character_unlocks or 0
        saveData.includeUniqueItems = data.include_unique_items == 1
        saveData.shrineChecks       = data.include_shrine_checks == 1
        saveData.chestChecks        = data.include_chest_checks == 1
        saveData.flawlessChestChecks = data.include_flawless_chest_checks == 1
        saveData.chestCheckChance   = data.chest_check_chance or 50
        saveData.zoneAccessKeys     = data.zone_access_keys or 0
        saveData.startingZone       = data.starting_zone or 1
        local VICTORY_TRIGGER_NAMES = {
            disabled           = "Disabled",
            ensemble           = "Ensemble",
            boss_rush          = "Boss Rush",
            expensive_purchase = "Expensive Purchase",
        }
        saveData.victoryTrigger         = VICTORY_TRIGGER_NAMES[data.victory_trigger] or "Ensemble"
        saveData.expensivePurchasePrice = data.expensive_purchase_price or 150
        saveData.goldToDiamondRate      = data.diamond_exchange_rate or 100
        saveData.itemRoom           = data.item_room or {}
        saveData.unlockedNPCs       = buildNpcTable(data.caged_npc_locations)
        saveData.npcHintLocations   = data.npc_hint_locations or {}
        saveData.pricing            = buildPricing(data.pricing)
    end

    apStorage.ensureSaveDataTables()
    progression.rebuildCaches()

    -- Recompute from the received-items log so goldenLuteShards is correct
    -- before apConnect fires, even when reconnecting without restarting the game.
    local shardCount = 0
    for _, entry in pairs(apStorage.saveData.receivedItems) do
        if entry.item == "APGoldenLuteShard" then
            shardCount = shardCount + 1
        end
    end
    apStorage.saveData.goldenLuteShards = shardCount

    if data.items and #data.items > 0 then
        itemHandler.handleItems(data.items, data.init == true)
    end

    if data.missing_locations or (data.init and data.checked_locations) then
        locationHandler.handleLocations(data)
    end
end

handlers.register("State", function(message, ctx)
    if message.world_version then
        ctx.apworldVersion = message.world_version

        if not apVersion.isApworldCompatible(message.world_version) then
            local text = ("Archipelago apworld (v%s) is too old for this mod\n(v%s, requires apworld v%s+). Ask your host to update the apworld,\nor downgrade the AP Redux mod to a matching version, then reconnect.")
                :format(message.world_version, apVersion.getModVersion(), apVersion.MIN_APWORLD_VERSION)
            apLog(text, "error")
            ctx.lastConnectError = text
            ctx.disconnect(("Apworld too outdated (v%s, mod requires apworld v%s+)."):format(message.world_version, apVersion.MIN_APWORLD_VERSION))
            return
        end
    end
    applyState(message)

    -- apConnect rebuilds lobby entities (shop slots, victory slot, item room) and
    -- flips shrine components. Only the host receives State, so firing it in a
    -- networked session would leave every other client without those changes.
    -- There the lobby's own generation pass -- gameStateLevel, which all clients
    -- run -- places them from the state replicated by apStateSync.
    if not apUtils.isNetworked() then
        event.apConnect.fire({ status = "Connected" })
    end
end)
