local currentLevel = require "necro.game.level.CurrentLevel"
local ecs          = require "system.game.Entities"
local rng          = require "necro.game.system.RNG"
local sound        = require "necro.audio.Sound"
local team         = require "necro.game.character.Team"
local turn         = require "necro.cycles.Turn"

local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

---Each group is a self-contained makeSummonTrap config plus a `weight`
---controlling how often it is picked when no variant is requested.
---TrapLink can target a group directly via args.variant (e.g. "Beetle").
local GROUPS = {
    Skeleton = {
        weight = 3,
        config = {
            min         = 2,
            max         = 6,
            radius      = 4,
            flyawayText = "Skeleton Trap!",
            variants    = {
                Skeleton         = 12,
                Skeleton2        = 9,
                Skeleton3        = 6,
                Armoredskeleton  = 5,
                Armoredskeleton2 = 4,
                Armoredskeleton3 = 3,
                Skeletonmage     = 4,
                Skeletonmage2    = 3,
                Skeletonmage3    = 2,
                Skeletonknight   = 2,
                Skeletonknight2  = 1,
                Skeletonknight3  = 1,
                Skull            = 1,
                Skull2           = 1,
                Skull3           = 1,
            },
            -- Incremental zone multipliers applied on top of base weights.
            zoneWeights = {
                [2] = {
                    Armoredskeleton  = 1.5,
                    Armoredskeleton2 = 1.5,
                    Armoredskeleton3 = 1.5,
                    Skeletonmage     = 1.3,
                    Skeletonmage2    = 1.3,
                    Skeletonmage3    = 1.3,
                },
                [3] = { Skeletonknight = 1.5, Skeletonknight2 = 1.5, Skeletonknight3 = 1.5 },
                [4] = {},
                [5] = { Skull = 2.5, Skull2 = 2.5, Skull3 = 2.5 },
            },
        },
    },
    Armadillo = {
        weight = 3,
        config = {
            min         = 2,
            max         = 6,
            radius      = 4,
            flyawayText = "Army Trap!",
            variants    = {
                Armadillo  = 12,
                Armadillo2 = 8,
                Armadillo3 = 4,
            },
            zoneWeights = {
                [2] = { Armadillo2 = 1.5, Armadillo3 = 1.3 },
                [3] = { Armadillo3 = 1.5 },
                [4] = {},
                [5] = { Armadillo3 = 1.75 },
            },
        },
    },
    Beetle = {
        weight = 3,
        config = {
            min         = 2,
            max         = 6,
            radius      = 4,
            flyawayText = "Beetle Trap!",
            variants    = { Beetle = 1, Beetle2 = 1 },
        },
    },
    Person = {
        weight = 1,
        config = {
            min           = 2,
            max           = 6,
            radius        = 4,
            flyawayText   = "Hello Everyone!",
            spawnProps    = false, -- people don't need aggro/stairLocker/ambusher
            particles     = false, -- no reroll particles on friendly spawns
            checkGrabbed  = false,
            requireSpawns = true,
            -- Pick from all playable character entity types each turn.
            getVariants   = function(_zone)
                return ecs.getEntityTypesWithComponents({ "playableCharacter" })
            end,
            -- Play each spawned character's greeting voice line.
            onSpawn       = function(spawned, _tile)
                team.setTeam(spawned, team.Id.NONE)
                -- Mark as spectating so these cosmetic spawns are excluded from the
                -- exit-level requirement count and don't softlock the level transition.
                spawned.spectator.active = true
                if spawned.voiceGreeting and spawned.voiceGreeting.sound then
                    sound.play(spawned.voiceGreeting.sound, spawned.position.x, spawned.position.y)
                end
            end,
        },
    },
}

-- Sorted iteration keeps the weighted list identical on every client.
local groupNames = {}
for name in pairs(GROUPS) do
    table.insert(groupNames, name)
end
table.sort(groupNames)

local trapFns = {}
local weightedGroups = {}
for _, name in ipairs(groupNames) do
    trapFns[name] = makeSummonTrap(GROUPS[name].config)
    for _ = 1, GROUPS[name].weight or 1 do
        table.insert(weightedGroups, name)
    end
end

TrapHandler.register("SummonTrap", function(ev, args)
    local variant = args and args.variant
    if not (variant and trapFns[variant]) then
        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        variant = rng.choice(weightedGroups, channel)
    end
    return trapFns[variant](ev)
end)
