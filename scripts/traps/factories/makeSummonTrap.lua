local collision    = require "necro.game.tile.Collision"
local currentLevel = require "necro.game.level.CurrentLevel"
local object       = require "necro.game.object.Object"
local particle     = require "necro.game.system.Particle"
local rng          = require "necro.game.system.RNG"
local sound        = require "necro.audio.Sound"
local tile         = require "necro.game.tile.Tile"

local trapSystem   = require "AP.scripts.traps.trapSystem"

---Default props applied to every spawned entity (aggro, revealed, locked to current floor).
local DEFAULT_SPAWN_PROPS = {
    visibility  = { revealed = true },
    aggro       = { active = true },
    stairLocker = { level = 0 },
    ambusher    = { pending = false },
}

---Expands a base-weight table into a flat array, applying cumulative zone multipliers.
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

---Plays the "reroll" particle burst on a newly spawned entity.
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

---The option table shared by `summon` and `makeSummonTrap`.
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
---    spawnProps     table|false  Extra props for object.spawn; nil uses DEFAULT_SPAWN_PROPS.
---    particles      bool   Play reroll particle on each spawn (default true).
---    checkGrabbed   bool   Skip grabbed players (default true).
---    requireSpawns  bool   Skip sound+flyaway unless at least one entity spawned (default false).
---    nearestFirst   bool   Sort vacant tiles closest-first before selecting (default false).
---    minRadius      number Minimum tile search distance (default 2).
---    getTiles       function(entity, minDist, maxDist)->table  Tile finder returning {[i]={x,y}}.
---    onSpawn        function(entity, tile, playerEntity, ctx)  Called after each spawn.
---    perPlayerSetup function(entity, zone, channel)  Returns { variants, flyawayText } or false.
---Runs one config's spawn pass for the player `ctx` is focused on.
---@param ctx table  The trap system context, focused on a player.
---@param opts table Same shape as makeSummonTrap's opts.
---@return boolean|nil false to skip this player
local function summon(ctx, opts)
    local entity  = ctx.entity
    local channel = ctx.channel
    local min     = opts.min    or 1
    local max     = opts.max    or 5
    local radius  = opts.radius or 4

    local checkGrabbed  = opts.checkGrabbed  ~= false  -- default true
    local useParticles  = opts.particles     ~= false  -- default true
    local requireSpawns = opts.requireSpawns == true   -- default false
    local nearestFirst  = opts.nearestFirst  == true   -- default false

    local spawnProps = DEFAULT_SPAWN_PROPS
    if opts.spawnProps == false then
        spawnProps = nil                  -- explicitly no extra props
    elseif opts.spawnProps ~= nil then
        spawnProps = opts.spawnProps
    end

    if checkGrabbed and entity.grabbable and entity.grabbable.isGrabbed then return false end

    local zone = currentLevel.getZone()

    -- Per-player variant/flyaway override.
    local weighted
    ctx.state.flyaway = opts.flyawayText

    if opts.perPlayerSetup then
        local pSetup = opts.perPlayerSetup(entity, zone, channel)
        if not pSetup then return false end

        weighted = pSetup.variants
        ctx.state.flyaway = pSetup.flyawayText or opts.flyawayText

        -- Negated / empty: announce without spawning.
        if #weighted == 0 then
            sound.playFromEntity(opts.sound or "trapDice", entity)
            return
        end
    elseif opts.getVariants then
        weighted = opts.getVariants(zone)
        if #weighted == 0 then return false end
    else
        weighted = buildVariantList(opts.variants, opts.zoneWeights, zone)
        if #weighted == 0 then return false end
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

    local count      = math.min(#tiles, rng.range(min, max, channel))
    local anySpawned = false

    for i = 1, count do
        local typeName = rng.choice(weighted, channel)
        local t        = tiles[i]
        if not (t and typeName) then goto nextSpawn end

        local spawned = object.spawn(typeName, t[1], t[2], spawnProps)
        if spawned then
            anySpawned = true
            if spawned.Sync_homeTile then
                tile.setType(t[1], t[2], spawned.Sync_homeTile.tileType)
            end
            if useParticles then spawnParticles(spawned) end
            if opts.onSpawn then opts.onSpawn(spawned, t, entity, ctx) end
        end
        ::nextSpawn::
    end

    if requireSpawns and not anySpawned then return false end

    sound.playFromEntity(opts.sound or "trapDice", entity)
end

---Creates a summon-style trap that spawns entities near each affected player.
---@param opts table See the shared option table above.
---@return table spec
local function makeSummonTrap(opts)
    assert(opts.name, "makeSummonTrap: opts.name is required")
    assert(opts.variants or opts.getVariants or opts.perPlayerSetup,
        "makeSummonTrap: one of opts.variants, opts.getVariants, or opts.perPlayerSetup is required")

    return trapSystem.define({
        name      = opts.name,
        perPlayer = opts.perPlayer,
        stateful  = opts.stateful,
        scope     = opts.scope,
        duration  = opts.duration,
        status    = opts.status,
        expire    = opts.expire,
        -- Resolved after the spawn pass, which may have replaced it per player.
        flyaway   = function(ctx) return ctx.state.flyaway or opts.flyawayText end,
        apply     = function(ctx) return summon(ctx, opts) end,
    })
end

return { makeSummonTrap = makeSummonTrap, summon = summon }
