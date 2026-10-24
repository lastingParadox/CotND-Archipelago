local chat               = require "necro.client.Chat"
local clientActionBuffer = require "necro.client.ClientActionBuffer"
local color              = require "system.utils.Color"
local currentLevel       = require "necro.game.level.CurrentLevel"
local ecs                = require "system.game.Entities"
local gameState          = require "necro.client.GameState"
local itemBan            = require "necro.game.item.ItemBan"
local lobby              = require "necro.game.level.Lobby"
local netplay            = require "necro.network.Netplay"
local player             = require "necro.game.character.Player"
local playerList         = require "necro.client.PlayerList"
local resources          = require "necro.client.Resources"
local singlePlayer       = require "necro.client.SinglePlayer"
local sound              = require "necro.audio.Sound"
local timer              = require "system.utils.Timer"
local turn               = require "necro.cycles.Turn"

local apLog              = require("AP.scripts.utils.log").apLog
local apStorage          = require("AP.scripts.client.storage")

local hasDebugCommands, debugCommands = pcall(require, "necro.debug.DebugCommands")

local apTest = {}

local specs = {}
local names = {}

local current = { name = "", passed = 0, failures = {} }
local currentPlayerID = nil
local watching = false

local function record(passed, message)
    if passed then
        current.passed = current.passed + 1
    else
        current.failures[#current.failures + 1] = message
    end

    return passed
end

local t = {}

function t.ok(condition, message)
    return record(not not condition, message or "expected a truthy value")
end

function t.eq(value, expected, message)
    return record(value == expected,
        message or ("expected %s, got %s"):format(tostring(expected), tostring(value)))
end

function t.ne(value, unexpected, message)
    return record(value ~= unexpected,
        message or ("expected anything but %s"):format(tostring(unexpected)))
end

function t.fail(message)
    return record(false, message or "fail")
end

function t.note(message)
    apLog(("%s: %s"):format(current.name, message))
end

function t.banned(holder, item, mask)
    return record(itemBan.isBanned(holder, item, mask),
        ("%s should be banned for %s"):format(tostring(item), tostring(holder)))
end

function t.unbanned(holder, item, mask)
    return record(not itemBan.isBanned(holder, item, mask),
        ("%s should not be banned for %s"):format(tostring(item), tostring(holder)))
end

function t.entityType(typeName)
    return record(ecs.isValidEntityType(typeName),
        ("unknown entity type %s"):format(tostring(typeName)))
end

function t.hasComponent(typeName, componentName)
    return record(ecs.isValidEntityType(typeName) and ecs.typeHasComponent(typeName, componentName),
        ("%s is missing component %s"):format(tostring(typeName), tostring(componentName)))
end

function t.player()
    return player.getPlayerEntity(currentPlayerID)
end

function t.act(...)
    for _, entry in ipairs({ ... }) do
        local entity = t.player()

        if not entity or entity.respawn and entity.respawn.pending then
            return t.fail("player died unexpectedly")
        end

        clientActionBuffer.addAction(currentPlayerID, turn.getCurrentTurnID(), entry, 0)
        turn.process()
    end
end

---Runs `body` with the save data's contents swapped for `contents`, restoring them afterwards.
---@param contents table
---@param body function
function apTest.withSaveData(contents, body)
    local saveData = apStorage.saveData
    local live = {}

    for key, value in pairs(saveData) do live[key] = value end
    for key in pairs(live) do saveData[key] = nil end
    for key, value in pairs(contents) do saveData[key] = value end

    local ok, err = pcall(body)

    for key in pairs(saveData) do saveData[key] = nil end
    for key, value in pairs(live) do saveData[key] = value end

    if not ok then error(err, 0) end
end

---Declares one test. `world` runs it on a generated AP test floor; `level` runs it
---against whatever floor is already loaded.
---@param spec table `{ name, run(t), world?, level?, mode?, seed?, character? }`
---@return table spec
function apTest.define(spec)
    assert(type(spec.name) == "string", "apTest.define: spec.name is required")
    assert(type(spec.run) == "function",
        ("apTest.define(%s): spec.run is required"):format(spec.name))

    if not specs[spec.name] then
        names[#names + 1] = spec.name
        table.sort(names)
    end

    specs[spec.name] = spec

    return spec
end

-- A 19x19 sheet of Zone 1 floor, matching the shape LevelLoader expects of a dungeon level.
local function flatLevel()
    local tiles = {}
    for i = 1, 361 do
        tiles[i] = 1
    end

    return {
        boss = 0,
        num = 1,
        silent = true,
        entities = {},
        segments = { { bounds = { -9, -9, 19, 19 }, tiles = tiles } },
        tileMapping = {
            tileNames = { "Floor" },
            tilesetNames = { "Zone1" },
            tilesets = { 1 },
        },
    }
end

local function enterTestLevel(spec)
    currentPlayerID = playerList.getLocalPlayerID()

    resources.upload(netplay.Resource.DUNGEON, nil, {
        options = {
            modeID = spec.mode or "AP_APAllZones",
            seed = spec.seed or 1,
            initialCharacters = { [currentPlayerID] = spec.character or "Cadence" },
        },
        levels = { flatLevel() },
    })

    event.gameStateReset.fire({})
    event.gameStateLevel.fire({ level = 1 })
end

local function runOne(spec)
    current = { name = spec.name, passed = 0, failures = {} }

    if spec.world then
        local entered, err = pcall(enterTestLevel, spec)
        if not entered then
            current.failures[1] = "setup: " .. tostring(err):gsub(".-:%d+: ", "")
            return current
        end
    end

    local ok, err = pcall(spec.run, t)
    if not ok then
        current.failures[#current.failures + 1] = "error: " .. tostring(err):gsub(".-:%d+: ", "")
    end

    return current
end

local function report(text, textColor)
    chat.addMessage({ name = "apTest", text = text, color = textColor })
end

local function kindOf(spec)
    return spec.world and "world" or spec.level and "level" or "schema"
end

-- A world test rewrites the dungeon resource, so it may only run from a local lobby.
local function worldAllowed()
    return singlePlayer.isActive() and gameState.isInLobby()
end

local function levelAllowed()
    return gameState.isInGame() and not currentLevel.isLobby() and not currentLevel.isLoading()
end

local function canRun(spec)
    if spec.world then return worldAllowed() end
    if spec.level then return levelAllowed() end

    return true
end

function apTest.list()
    for _, name in ipairs(names) do
        report(("%s  [%s]"):format(name, kindOf(specs[name])), color.WHITE)
    end

    return ("%d tests registered"):format(#names)
end

function apTest.run(pattern)
    local matched = {}
    for _, name in ipairs(names) do
        if pattern == nil or name:lower():find(tostring(pattern):lower(), 1, true) then
            matched[#matched + 1] = name
        end
    end

    if not matched[1] then
        report(("no tests match '%s'"):format(tostring(pattern)), color.RED)
        return "0 tests"
    end

    local runnable, skipped, needsWorld = {}, {}, false

    for _, name in ipairs(matched) do
        local spec = specs[name]

        if canRun(spec) then
            runnable[#runnable + 1] = spec
            needsWorld = needsWorld or spec.world == true
        else
            skipped[kindOf(spec)] = (skipped[kindOf(spec)] or 0) + 1
        end
    end

    if skipped.world then
        report(("skipped %d world tests: run them from the lobby in single player")
            :format(skipped.world), color.WHITE)
    end

    if skipped.level then
        report(("skipped %d level tests: run them while standing on a floor")
            :format(skipped.level), color.WHITE)
    end

    local volume = sound.getSoundVolume()
    if needsWorld then sound.setSoundVolume(0) end

    local clock = timer.new()
    local passed, failed = 0, 0

    for _, spec in ipairs(runnable) do
        local result = runOne(spec)
        passed = passed + result.passed
        failed = failed + #result.failures

        for _, message in ipairs(result.failures) do
            report(spec.name .. ": " .. message, color.RED)
            apLog(("%s: %s"):format(spec.name, message), "warning")
        end
    end

    if needsWorld then
        sound.resetGameSounds()
        sound.setSoundVolume(volume)
        lobby.open()
    end

    local summary = ("%d/%d assertions OK across %d tests in %dms"):format(
        passed, passed + failed, #runnable, math.floor(timer.toMilliseconds(clock.getTime())))

    report(summary, failed == 0 and color.GREEN or color.WHITE)
    apLog(summary, failed == 0 and "info" or "warning")

    return summary
end

---Toggles running every level test as each floor finishes generating.
function apTest.watch(enabled)
    if enabled == nil then enabled = not watching end
    watching = enabled and true or false

    report(watching and "watching level generation" or "no longer watching level generation",
        color.WHITE)

    return watching
end

-- Past "levelLoadingDone", so the floor is built and currentLevel no longer reads as loading.
event.gameStateLevel.add("apTestWatchLevel", { order = "splitScreen", sequence = 1 }, function()
    if not watching or not levelAllowed() then return end

    local failed = 0

    for _, name in ipairs(names) do
        local spec = specs[name]

        if spec.level then
            local result = runOne(spec)
            failed = failed + #result.failures

            for _, message in ipairs(result.failures) do
                report(name .. ": " .. message, color.RED)
                apLog(("%s: %s"):format(name, message), "warning")
            end
        end
    end

    if failed > 0 then
        report(("%d level checks failed on %s"):format(failed, currentLevel.getName()), color.RED)
    end
end)

if hasDebugCommands then
    debugCommands.register("aptest", apTest.run)
    debugCommands.register("aptests", apTest.list)
    debugCommands.register("aptestwatch", apTest.watch)
else
    apLog("necro.debug.DebugCommands is unavailable; the aptest console command is disabled.", "warning")
end

return apTest
