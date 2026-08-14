local collision    = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local object       = require "necro.game.object.Object"
local particle     = require "necro.game.system.Particle"
local player       = require "necro.game.character.Player"
local rng          = require "necro.game.system.RNG"
local sound        = require "necro.audio.Sound"
local tile         = require "necro.game.tile.Tile"
local turn         = require "necro.cycles.Turn"

local apFlyaways   = require "AP.scripts.ui.apFlyaways"

---Default props applied to every spawned entity (aggro, revealed, locked to current floor).
local DEFAULT_SPAWN_PROPS = {
    visibility  = { revealed = true },
    aggro       = { active = true },
    stairLocker = { level = 0 },
    ambusher    = { pending = false },
}

---Applies cumulative zone multipliers to a base-weight table and returns
---a flat array where each entry appears proportional to its rounded weight.
---@param variants    table<string, number>  { [entityTypeName] = baseWeight }
---@param zoneWeights table<number, table>   { [zone] = { [name] = multiplier } } or nil
---@param zone        number                 Current dungeon zone
---@return table<string>  Flat weighted list
local function buildVariantList(variants, zoneWeights, zone)
    local out = {}
    for name, base in pairs(variants) do
        local w = base
        if zoneWeights then
            for z = 2, zone do
                local zt = zoneWeights[z]
                if zt and zt[name] then w = w * zt[name] end
            end
        end
        for _ = 1, math.max(math.floor(w + 0.5), 1) do
            table.insert(out, name)
        end
    end
    return out
end

---Plays the standard "reroll" particle burst on a newly spawned entity.
---@param entity table ECS entity with position and sprite components.
local function spawnParticles(entity)
    particle.playFromTable({
        type          = "Sync_particleSpritePixels",
        x             = entity.position.x,
        y             = entity.position.y,
        texture       = entity.sprite.texture,
        rangeX        = entity.sprite.width,
        rangeY        = entity.sprite.height,
        duration      = 1,
        maxHeight     = 60,
        offsetZ       = 20,
        particleCount = 25,
        fadeRate      = 1,
        size          = 2,
        radiusX       = 25,
        radiusY       = 25,
    })
end

---Creates a summon-style trap that spawns entities near each affected player.
---
---@param opts table
---  Required (choose one):
---    variants    table<string, number>         { [entityTypeName] = baseWeight }
---    getVariants function(zone)->table<string> Returns a flat array of type names for the given zone.
---  Required:
---    flyawayText string
---  Optional:
---    zoneWeights    table   { [zone]={ [name]=multiplier } }  Zone scaling (only with `variants`).
---    min            number  Minimum spawn count per player (default 1).
---    max            number  Maximum spawn count per player (default 5).
---    radius         number  Vacant tile search radius (default 4).
---    sound          string  Sound played per player (default "trapDice").
---    spawnProps     table|false  Extra props for object.spawn.
---                              nil  → use DEFAULT_SPAWN_PROPS (monster spawns).
---                              false → spawn with no extra props (neutral/friendly spawns).
---    particles      bool   Play reroll particle on each spawn (default true).
---    checkGrabbed   bool   Skip grabbed players (default true).
---    requireSpawns  bool   Skip sound+flyaway unless at least one entity spawned (default false).
---    nearestFirst   bool   Sort vacant tiles closest-first before selecting (default false).
---    minRadius      number Minimum tile search distance (default 2).
---    getTiles       function(entity, minDist, maxDist)->table  Custom tile finder;
---                            replaces getVacantTiles when set. Must return {[i]={x,y}}.
---    onSpawn        function(entity, tile, playerEntity) Called after each successful spawn.
---    perPlayerSetup function(entity, zone, channel)
---                           Return { variants: table, flyawayText: string? } to use per-entity
---                            variants and text. Empty variants shows flyaway without spawning.
---                           Return false to skip this player silently.
---@return function trapFn
local function makeSummonTrap(opts)
    assert(opts.flyawayText, "makeSummonTrap: opts.flyawayText is required")
    assert(opts.variants or opts.getVariants or opts.perPlayerSetup,
        "makeSummonTrap: one of opts.variants, opts.getVariants, or opts.perPlayerSetup is required")

    local function getWeighted(zone)
        if opts.getVariants then return opts.getVariants(zone) end
        return buildVariantList(opts.variants, opts.zoneWeights, zone)
    end

    -- Resolve spawn props once at factory-creation time.
    local resolvedSpawnProps
    if opts.spawnProps == false then
        resolvedSpawnProps = nil          -- explicitly no extra props
    elseif opts.spawnProps == nil then
        resolvedSpawnProps = DEFAULT_SPAWN_PROPS
    else
        resolvedSpawnProps = opts.spawnProps
    end

    local checkGrabbed  = opts.checkGrabbed  ~= false  -- default true
    local useParticles  = opts.particles     ~= false  -- default true
    local requireSpawns = opts.requireSpawns == true   -- default false
    local nearestFirst  = opts.nearestFirst  == true   -- default false

    return function(ev)
        local min    = opts.min    or 1
        local max    = opts.max    or 5
        local radius = opts.radius or 4
        local channel = rng.makeChannel(currentLevel.getSeed() + turn.getCurrentTurnID())
        local trapSuccess = false

        for _, entity in ipairs(player.getPlayerEntities()) do
            if not (entity and entity.playableCharacter) then goto continue end
            if checkGrabbed and entity.grabbable and entity.grabbable.isGrabbed then goto continue end

            local zone = currentLevel.getZone()

            -- Per-player variant/flyaway override.
            local weighted
            local entityFlyaway = opts.flyawayText
            if opts.perPlayerSetup then
                local pSetup = opts.perPlayerSetup(entity, zone, channel)
                if not pSetup then goto continue end
                weighted      = pSetup.variants
                entityFlyaway = pSetup.flyawayText or opts.flyawayText
                if #weighted == 0 then
                    -- Negated / empty: show flyaway without spawning.
                    sound.playFromEntity(opts.sound or "trapDice", entity)
                    apFlyaways.addToFlyawayQueue({ entity = entity, text = entityFlyaway })
                    trapSuccess = true
                    goto continue
                end
            else
                weighted = getWeighted(zone)
                if #weighted == 0 then goto continue end
            end

            local tiles
            if opts.getTiles then
                tiles = opts.getTiles(entity, opts.minRadius or 2, radius, channel)
            else
                tiles = collision.getVacantTiles(
                    entity, opts.minRadius or 2, radius, 6, false,
                    collision.Type.mask(collision.Group.SOLID, collision.Type.TRAP)
                )
                if nearestFirst then
                    local px, py = entity.position.x, entity.position.y
                    table.sort(tiles, function(a, b)
                        local da = (a[1]-px)*(a[1]-px) + (a[2]-py)*(a[2]-py)
                        local db = (b[1]-px)*(b[1]-px) + (b[2]-py)*(b[2]-py)
                        return da < db
                    end)
                end
            end

            local count    = math.min(#tiles, rng.range(min, max, channel))
            local anySpawned = false

            for i = 1, count do
                local typeName = rng.choice(weighted, channel)
                local t        = tiles[i]
                if not (t and typeName) then goto nextSpawn end

                local spawned = object.spawn(typeName, t[1], t[2], resolvedSpawnProps)
                if spawned then
                    anySpawned = true
                    if spawned.Sync_homeTile then
                        tile.setType(t[1], t[2], spawned.Sync_homeTile.tileType)
                    end
                    if useParticles then spawnParticles(spawned) end
                    if opts.onSpawn then opts.onSpawn(spawned, t, entity) end
                end
                ::nextSpawn::
            end

            if requireSpawns and not anySpawned then goto continue end

            sound.playFromEntity(opts.sound or "trapDice", entity)
            apFlyaways.addToFlyawayQueue({ entity = entity, text = entityFlyaway })
            trapSuccess = true

            ::continue::
        end

        return trapSuccess
    end
end

return { makeSummonTrap = makeSummonTrap }
