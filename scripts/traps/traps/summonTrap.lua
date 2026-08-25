local currentLevel = require "necro.game.level.CurrentLevel"
local ecs          = require "system.game.Entities"
local rng          = require "necro.game.system.RNG"
local sound        = require "necro.audio.Sound"
local team         = require "necro.game.character.Team"
local turn         = require "necro.cycles.Turn"

local makeSummonTrap = (require "AP.scripts.traps.factories.makeSummonTrap").makeSummonTrap
local TrapHandler    = require "AP.scripts.traps.trapHandler"

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
    Goblin = {
        weight = 3,
        config = {
            min         = 2,
            max         = 6,
            radius      = 4,
            flyawayText = "Goblin Trap!",
            variants    = {
                Goblin         = 12,
                Goblin2        = 9,
                GoblinBomber   = 6,
                SleepingGoblin = 3,
            },
            zoneWeights = {
                [2] = { Goblin2 = 1.5, GoblinBomber = 1.1, },
                [3] = { Goblin2 = 1.3, GoblinBomber = 1.1 },
                [4] = { GoblinBomber = 1.5, SleepingGoblin = 1.2 },
                [5] = { Goblin2 = 1.5, GoblinBomber = 1.5 },
            },
        },
    },
    Golem = {
        weight = 3,
        config = {
            min         = 2,
            max         = 6,
            radius      = 4,
            flyawayText = "Golem Trap!",
            variants    = {
                Golem  = 12,
                Golem2 = 8,
                Golem3 = 4,
            },
            zoneWeights = {
                [2] = { Golem2 = 1.5 },
                [3] = { Golem3 = 1.1 },
                [4] = { Golem3 = 1.5 },
                [5] = { Golem3 = 1.75 },
            },
        },
    },
    Slime = {
        weight = 3,
        config = {
            min         = 2,
            max         = 6,
            radius      = 4,
            flyawayText = "Slime Trap!",
            -- Slime6 through Slime8 are Amplified-only; without it they simply fail to
            -- spawn, the same way the Skeleton group's skulls do.
            variants    = {
                Slime  = 3,
                Slime2 = 10,
                Slime3 = 10,
                Slime4 = 8,
                Slime5 = 8,
                Slime6 = 6,
                Slime7 = 4,
                Slime8 = 4,
            },
            zoneWeights = {
                [2] = { Slime2 = 1.5, Slime3 = 1.5 },
                [3] = { Slime4 = 1.5, Slime5 = 1.5 },
                [4] = { Slime6 = 1.75 },
                [5] = { Slime7 = 2, Slime8 = 2 },
            },
        },
    },
    Person = {
        weight = 1,
        config = {
            min           = 2,
            max           = 6,
            radius        = 4,
            flyawayText   = "Hello Everyone!",
            spawnProps    = false,
            particles     = false,
            checkGrabbed  = false,
            requireSpawns = true,
            getVariants   = function(_zone)
                return ecs.getEntityTypesWithComponents({ "playableCharacter" })
            end,
            onSpawn       = function(spawned, _tile)
                team.setTeam(spawned, team.Id.NONE)
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
