# Archipelago Redux — CotND Synchrony mod

Lua mod (`namespace: AP`, display name "Archipelago Redux") that turns Crypt of the
NecroDancer into an Archipelago multiworld game. It is one of three cooperating trees:

| Tree | Path | Role |
|------|------|------|
| **This mod** | `c:\Users\zanpr\AppData\Local\NecroDancer\mods\AP` | In-game Lua client: lobby, progression, item delivery, traps |
| **APWorld + Python client** | `d:\Windows Files\Documents\Programs\Personal\Archipelago-CotND\worlds\cotnd` | World definition, rules, and the local TCP broker to the AP server |
| **Engine decompile** | `c:\Users\zanpr\AppData\Local\NecroDancer\NecroExtracted` | Read-only reference for every Synchrony API this mod calls |

The mod never speaks to the Archipelago server. It speaks JSON over localhost TCP to the
Python client, which brokers everything.

---

## Two rules above all others

**1. Search the library before writing logic.** `NecroExtracted` is the whole engine in
readable Lua. Almost every loop, merge, distance check, sort, spatial query, RNG draw, or
scheduling primitive already exists there. Hand-rolled versions are longer, miss edge
cases the engine handles, and drift from the rest of the codebase.

Usual homes:

- `system/utils/Utilities.lua` — `mergeTables`, `mergeTablesRecursive`, `mergeDefaults`,
  `listToSet`, `removeIf`, `map`, `getOrderedValueList`, `sortedPairs`, `clamp`,
  `squareDistance`, `distanceL1`, `distanceLInf`, `lerp`, `deepCopy`, `arrayFind`
- `system/utils/` — `Enum`, `Color`, `Random`, `Rectangle`, `StringUtilities`, `Timer`,
  `SortedList`, `serial/JSON`
- `necro/game/system/` — `RNG`, `Snapshot`, `Delay`, `Damage`, `Flyaway`, `Move`,
  `Particle`, `Action`, `WorldLabel`, `StatusEffect`
- `necro/game/tile/` — `Tile`, `Collision`, `Segment`, `Marker`, `TileTypes`, `Area`
- `necro/game/object/` — `Object`, `Map`, `ObjectEvents`, `Shrine`, `Interaction`
- `necro/game/item/` — `Inventory`, `ItemPickup`, `ItemBan`, `ItemGeneration`,
  `ItemSlot`, `Currency`, `PriceTag`, `AffectorItem`
- `necro/game/character/` — `Player`, `Focus`, `Rhythm`, `CharacterSwitch`, `Health`
- `necro/game/enemy/Targeting` — `getNearestPlayer`, `selectNearest` (filters
  untargetable players and respects segments; a manual distance loop does neither)

Grep first (`grep -rn "function .*[Nn]earest" scripts/`), and only write custom logic once
the search comes up empty — and say so when you do.

**2. Keep it simple.** This mod is maintained by one person. Prefer the shortest solution
that reads clearly over the clever one. When a subsystem here already generalises a
pattern (`trapSystem.define`, `apGrants.define`, `apItemFactory.define`,
`apExtrasRoom.demand`, `apTrapStatus.register`), extend it with a new spec rather than
adding a parallel mechanism.

---

## Runtime: sandboxed LuaJIT 2.1-beta3

Synchrony runs LuaJIT v2.1-beta3 (Lua 5.1 plus a few 5.2 extensions) inside a sandbox
that differs from stock Lua in ways that produce real crashes.

### What exists

Globals: `assert`, `error`, `ipairs`, `next`, `pcall`, `pairs`, `require`, `select`,
`tonumber`, `tostring`, `type`, `unpack`, `xpcall`, plus `math`, `string`, `table`, `bit`,
`utf8`. Mod-specific globals: `event`, `script`, `L` (i18n string).

**Not available:** `rawget`, `rawset`, `io`, `os`, `loadstring`, `setfenv`, most of the
standard library outside the list above. `apUtils`/`trapSystem` work around the missing
`rawget` with plain field access through `__index` (see `contextMeta` in
[trapSystem.lua](scripts/traps/trapSystem.lua)).

Some `system.*` modules require a player-side whitelist in the game's `config.json`.
This mod guards them and degrades gracefully:

```lua
local hasClient, client = pcall(require, "system.network.Client")
local hasStorage, storage = pcall(require, "system.file.Storage")
```

If either is missing, [client.lua](scripts/client/client.lua) installs no-op stubs, warns
in chat, and the Archipelago trapdoor stays closed. That stub list is hand-maintained and
sits behind an early `return`, so **any `apClient` member defined below it does not exist
in degraded mode** — touching one at module scope crashes the whole mod at load rather
than degrading. A field the literal sets to `nil` is absent for this purpose too.
What a mod may require is set in the game's `config.json`, not by convention:

```
wos.game.mods.scriptWhitelist = necro.*, system.game.{Audio,Bitmap,Entities,FileIO,Graphics,Input},
                                system.network.IPC, system.events.*, system.gfx.*, system.i18n.*, system.utils.*
wos.game.mods.scriptBlacklist = necro.mod.*
```

So `necro.*` needs no guard **except `necro.mod.*`, which is blacklisted outright** —
`AssetMod`, `ModWizard`, `Mods` all raise *"Cannot require module … Permission denied"* at
load. Anything they expose has to be reproduced (a local playlist's folder is its
`res_`-stripped name under `ext/mods`). Another mod's scripts are exempt from the list once
that mod is loaded (`ModScriptProvider.lua:85`), so `require "CustomArtists.scripts.…"`
works. `system.mod.ModLoader` is likewise out of the whitelist —
detect other mods via `resources.getData(netplay.Resource.MOD_LIST)`
(see [modConflict.lua](scripts/utils/modConflict.lua) and
[version.lua](scripts/utils/version.lua)).

### Module tables are write-protected

`ScriptLoader` puts a `__newindex` on every module table. `someModule.fn = ...` throws
*"Attempt to modify module member"* immediately. **Monkey-patching is impossible**, even
temporarily for instrumentation. `event.<name>.override(handlerName, fn)` is the only
supported seam; when there is no seam, reproduce the logic. Reading a member that does not
exist raises *"Attempt to access non-existent member"* rather than returning `nil`, so test
for absence with `pcall`. The protection is on what `require` hands out: a module's own
functions still reassign its members (`apStorage.initSession` replaces `saveData`), but another
module may only change what is *inside* one — which is why tests go through
`apTest.withSaveData`, which swaps `saveData`'s contents in place.

A module that ends without `return` becomes an error table that raises on any access
(`necro.render.hud.TimerHUD` is one). Read user settings through
`necro.config.SettingsStorage` by id instead.

### Load-time vs run-time

Accessing another module's members at module scope makes it a **load-time** dependency;
accessing them only inside handlers makes it **run-time**. Cyclic requires are legal so
long as the cycle is not entirely load-time — the fix for a cycle is to move one side's
access inside an event handler. At load-time you may register handlers and read static
members, but you may not touch the ECS or fire events.

### Globals persist, locals do not

Module-scope `local` resets on every script reload (starting the game, toggling a mod,
saving a `.lua`). Module-scope globals persist across reloads, matched by name.
`script.persist` gives a local variable the same persistence:

```lua
local apClient = { ... }
apClient = script.persist(function() return apClient end)
```

Order matters in a multi-value `script.persist`; names do not. This mod persists the
client, storage, progression table, trap registry state, and event-sync counters.
Deliberately *not* persisted: `trapSystem`'s `specs`/`names` registry, so that a reload
re-runs every `define()` cleanly (`forgetSpec` displaces the old spec).

### Determinism and snapshots

Every client simulates the run in lockstep, so any gameplay-relevant state must be
snapshot-managed or it desyncs and fails to roll back:

```lua
apTrapQueue = snapshot.variable({}, true)   -- no reset
apTrapState = snapshot.variable({}, true)
collectedItems = snapshot.levelVariable({}) -- resets per level
score = snapshot.runVariable(0)             -- resets per run
```

Snapshot variables must be globals, must be serialisable (no functions, userdata, or
entity wrappers), and lose their metatables on restore.

Desync sources to avoid: `math.random` (use `necro.game.system.RNG`), `pairs` iteration
order for anything that drives state (use `utils.sortedPairs` or a sorted key list —
`trapSystem.forEachInstance` sorts entity ids for exactly this reason),
`system.utils.Timer` for gameplay timing (use `necro.game.system.Delay`),
`necro.audio.Beatmap` for in-turn decisions, `necro.game.character.Focus` (local by
definition), and sprite/animation fields.

Gameplay state may only be mutated **in-turn** — inside `event.turn`,
`event.gameStateLevel`, or `event.gameStateReset`. Ticks, message handlers, and render
are out-of-turn; render-only state is free to change there.

---

## Components and events

### Components

All custom components are registered in one place:
[ArchipelagoMod.lua](ArchipelagoMod.lua), via `components.register`. Names are prefixed
`AP_`. Fields are `components.field.*` (mutable, snapshotted) or `components.constant.*`
(per-entity-type, not serialised — prefer these, especially for strings and tables).

Reading a **missing component** off an entity returns `false`, so
`if ev.item.itemGoldenLute then` is safe. Reading an **undeclared field** on a present
component *raises* — `entity.someComponent.missingField or 0` does not protect you. Guard
on the component name first.

Components cannot be added or removed per instance. To change what an entity is, use
`object.convert(entity, targetType)` from `necro.game.object.Object` — never
`ecs.convert`.

Never store an entity wrapper across turns; store `entity.id` and re-fetch with
`ecs.getEntityByID`.

### Attaching components to vanilla entities

[entities/vanilla.lua](scripts/entities/vanilla.lua) is the single place vanilla content
is amended, through schema events:

```lua
event.entitySchemaLoadItem.add("addAPComponents", { order = "common", sequence = 1 }, function(ev)
    ev.entity.AP_hintLabel = {}
    ev.entity.AP_locationItem = {}
end)

event.entitySchemaLoadNamedEntity.add("apMarv", { order = "overrides", sequence = 1, key = "Marv" }, ...)
```

`customEntities.register` runs its definition through `entityPostProcessor.apply`, so
`entitySchemaLoadNamedEntity` fires for **another mod's** custom entities too, keyed on the
prefixed name (`CustomArtists_SongRandomizerShrine`). That is the seam for amending one. A
component added there is type-wide, and the other mod's own copies get it as well — so give
it a default that changes nothing (`visible = false`) and switch it on per instance through
`object.spawn`'s attributes, which only `components.field.*` accept.

New entities come from `necro.game.data.CustomEntities` — wrapped here by
[apItemFactory.lua](scripts/items/apItemFactory.lua) (`define` for carriers,
`defineDisplay` for cosmetic props, `disguise` to wear another item's sprite).
Custom entities register as `entitySchemaCustomEntities` handlers named after the entity, and
`OrderedSelector` sorts handlers sharing an order and sequence **by name** — so registration
order is alphabetical, not declaration order, and identical on every client by construction.

### Events

```lua
event.turn.add("apDeliverItemActions", { order = "customActions", sequence = 0 }, function(ev) end)
event.objectSpawn.add("apGrantInitialItems", { filter = "initialInventoryUnlockReceiver", order = "itemsUnlockable", sequence = 1 }, ...)
```

- Handler names may contain **only letters and digits** — `event.<name>.add` raises
  *"Invalid event handler name"* on anything matching `%W`, underscores included, then
  prefixes the mod namespace itself (`necro/event/Event.lua:67-74`). Never build a name by
  concatenating a key that can hold `_` (a menu name like `CustomArtists_grid`). Keep names
  unique and descriptive. `scriptMetaInfo.validateAndPrefix` is the separate rule for
  **components, custom entities, custom weapons, enum extensions, HUD elements, and `Delay`
  names**: it adds `AP_` and rejects any underscore outside that prefix.
- The second argument to `add` is the filter key, kept separate from the name, so a
  mod-registered key matches the engine's dispatch exactly as a vanilla one does.
- Handlers may only be registered at **load time**; `add` inside a handler raises
  *"Attempt to register handler … at run time."*
- Vanilla handlers all sit at `sequence = 0`. Negative sequences run before vanilla,
  positive after.
- Prefer `filter = "componentName"` over an `if` inside the body; the engine caches the
  applicable handler list per entity type.
- `objectX` events have a matching `holderX` event that filters on the holder's
  *equipment*: there `ev.holder` is the character and `ev.entity` is the item.
- `event.<name>.override("originalHandlerName", { sequence = n }, function(func, ev) end)`
  suppresses or wraps a vanilla handler. It is the only patching seam, but it is fragile
  across game updates — use it last. Existing overrides: `giveInitialInventory`,
  `pickupEffects.flyaway`, `spellcast`-adjacent Coldsteel handlers.
- Fire events with `objectEvents.fire("respawn", entity, {...})` or
  `event.<name>.fire(ev, filterKey)`.

### Custom events defined here

`event.apConnect` and `event.apUpdate` are ordered selectors created in
[client.lua](scripts/client/client.lua); `event.apConnect.fire({ status = "Connected" })`
is the signal that a session became usable.

---

## Repository layout

```
ArchipelagoMod.lua           every AP_ component + textPool registration
mod.json                     namespace AP, version, synchronyVersion floor
gfx/ sfx/                    art and audio (referenced as "mods/AP/gfx/...")
scripts/
  client/                    TCP client, packet handlers, session storage, progression
    client.lua               socket lifecycle, tick loop, packet dispatch, host detection
    initHandlers.lua         datatype -> handler registry
    storage.lua              in-memory session state (apStorage.saveData)
    apStateSync.lua          host replicates session state to joiners (APState resource)
    apEventSync.lua          host publishes turn-stamped events (APEvents resource)
    progression.lua          aggregate progression facade + level-complete checks
    progression/*.lua        attach(progression) mixins: meta, player, items, characters,
                             shops, network, goals, zoneAccess
    handlers/*.lua           one file per incoming datatype
  traps/
    trapSystem.lua           declarative trap framework (define/stop/stateOf/eachState)
    trapHandler.lua          rollback-safe trap queue, ticketing, RNG channels
    factories/*.lua          higher-level trap shapes (summon, item ban, menu, sound...)
    traps/*.lua              ~90 individual trap definitions
  items/                     AP carriers, grants, factories, upgrades, filler/
  entities/                  lobby NPCs, shrines, shop slots, triggers, vanilla.lua
  level/                     lobby + run generation, item generation, extras rooms, modes
  modes/                     APAllZones, APSingleZone, APEnsemble, APBossRush game modes
  buffs/                     per-character permanent run buffs
  audio/                     apSongRandomizer.lua (supplies AP's settings + seed to CustomArtists)
  menu/                      connection menus + AP's own song randomizer menu
  test/                      in-game test harness
    apTest.lua               define/run/watch + the `aptest` console commands
    cases/*.lua              one file per area, self-registering
  ui/                        flyaway queue, chat badge, HUDs, trap status, outlines
  utils/                     characters, items, inventory, level gen, colors, log, version
  weapons/ tile/             supporting content
```

Synchrony auto-loads every `.lua` under the mod (`mod.json`'s `api.scriptPath` is `""`),
so trap files and entity files need no central `require` — they self-register on load.
Module paths are `AP.scripts.<dir>.<file>`.

---

## Core subsystems

### Network client — [scripts/client/client.lua](scripts/client/client.lua)

Reads the port from `archipelago/port.txt` (written by the Python client) via
`system.file.Storage`, connects with `client.connectTCP("127.0.0.1", port, "AP:<version>")`.
The identity string carries the mod version so Python can reject a too-old mod.

The tick loop is `client.process()` then `client.poll()` until nil; each message is
`json.decode`d and passed to `handlers.dispatch`, both inside `pcall` so one bad packet
does not stop the loop.

Handler ordering on `event.tick` (`order = "lobby"`) is deliberate:
`1` port read + trap real-time clock, `2` client loop, `3` deferred item processing,
`4` state upload, and a deferred-disconnect pass so a `Disconnect` reason reaches Python
before the socket closes.

### Session state — [storage.lua](scripts/client/storage.lua)

`apStorage.saveData` is the mod's whole picture of the slot. There is **no local save
file** — it is rebuilt from the Python client's `State` packet on every connect, which is
why the AP server is always the source of truth. `ensureSaveDataTables()` runs at load so
nothing reads a nil table in the window before `State` arrives. A session is keyed by
`seed + playerName + slot`; a TCP reconnect with the same triple preserves the dedup
tables rather than reinitialising.

### Progression — [progression.lua](scripts/client/progression.lua) + `progression/`

One persisted table assembled from `attach(progression)` mixins. Read state through the
accessors (`progression.getGoal()`, `progression.isDLCEnabled("Amplified")`,
`progression.getZoneProgressFloors()`) rather than reaching into `apStorage.saveData`,
so defaults for older saves live in one place. `rebuildCaches()` re-derives the item and
character caches after any state change; `apStateSync` calls it on joiners.

`event.levelComplete` is where zone/floor/boss/mode checks are collected and sent through
`progression.sendLocationChecks`.

### Item delivery — [handlers/items.lua](scripts/client/handlers/items.lua) + [apGrants.lua](scripts/items/apGrants.lua)

Incoming items are deduped by `ap_index`, recorded in `saveData.receivedItems`, then
queued in `defferredItems`. Delivery waits for a safe moment (`canProcessItems()` rejects
win screens, cutscenes, replays, loading, descent).

`apGrants` decides what an AP item id *does*:

- `apGrants.define{ item = "APx", carrier = "AP_Entity", apply = fn }` — one id
- `apGrants.defineFamily{ order, match, apply }` — a whole class
- `apGrants.defineItemFiller("APBomb", "Bomb")` — a real CotND item
- `apGrants.defineFallback{ apply }` — anything unclaimed is dropped on the floor

`apGrants.drop` fans out from each player's feet using precomputed radial offsets and
`object.moveToNearbyVacantTile`.

### Traps — [trapSystem.lua](scripts/traps/trapSystem.lua)

The system owns duration, per-player instances, stacking, storage class, cleanup, status
text, RNG channel, variant selection, and the floor-rewrite pass. A trap file declares
only what the trap does:

```lua
trapSystem.define({
    name     = "TempoTrap",
    variants = VARIANTS,
    clock    = trapSystem.Clock.REAL,      -- BEAT (default) or REAL
    storage  = trapSystem.Storage.VOLATILE, -- SNAPSHOT (default) or VOLATILE
    stateful = true,
    flyaway  = function(ctx) ... end,
    start    = function(ctx) ... end,       -- shared setup, false aborts
    apply    = function(ctx) ... end,       -- per player, false skips
    tick     = function(ctx) ... end,
    expire   = function(ctx) ... end,
})
```

Enums: `Announce` (EACH/FIRST/NONE), `Clock` (BEAT/REAL), `Scope` (LEVEL/RUN),
`Stacking` (QUEUE/REFRESH/IGNORE/STACK), `Storage` (SNAPSHOT/VOLATILE). Use `SNAPSHOT`
for simulated effects and `VOLATILE` for render/window/audio state that must not rewind
mid-frame. Read state from outside a trap's callbacks with `trapSystem.stateOf`,
`trapSystem.isActive`, `trapSystem.eachState`; end one early with `trapSystem.stop`.

`trapHandler` is the queue underneath: `apTrapQueue`/`apTrapTicket` are snapshot
variables, tickets identify a trap that had to sit out a turn, and
`TrapHandler.channel(ticket)` seeds RNG on `(levelSeed, turnID, ticket)` so two of a kind
on the same beat do not roll identically. `TrapHandler.fire(name, args, { host = true })`
is the TrapLink path: publish to every client rather than acting locally.

Reach for a factory before a bare `define` — `makeSummonTrap`, `makeItemBanTrap`,
`makeMenuTrap`, `makeMirrorXTrap`, `makeSoundLoopTrap` cover most shapes.

### Lobby and level generation

[apLobby.lua](scripts/level/apLobby.lua) owns the AP lobby segment and player placement;
[lobby/](scripts/level/lobby/) builds its rooms (character select, item room, buff room,
game mode select). [lobbyUtils.lua](scripts/utils/lobbyUtils.lua) and
[levelGen.lua](scripts/utils/levelGen.lua) are the helpers — use `lobbyUtils.addRoom`,
`addLabel`, `addDestination`, `levelGen.placeObject` rather than touching tiles directly.

Standing "in the AP lobby" means standing in a segment `lobbyUtils.addRoom` created, so every AP
room must come from it. Segment ids are not a range: vanilla's `trainingRooms` pass runs after the
AP lobby, so the Beastmaster and Bossmaster rooms sit at higher ids than the AP hub, and rooms built
on connect land after them. The Trackermaster room holds the Item Room and Enemy Room stairs;
the Enemy Room groups checks by the slot's `enemy_zones` (the engine's `enemyPoolZoneN` pools when
there are none), with `enemyPoolMiniboss` prototypes split out, and draws each one as an
`AP_ItemShowcase` whose `category` is `"enemy"`; an enemy with no check is never silhouetted.

`apExtrasRoom.demand(name, estimate)` is how a feature asks a floor for extra rooms; the
estimator runs at `levelSequenceUpdate` so all demands collapse into one map resize.

### UI

Flyaways go through [apFlyaways.addToFlyawayQueue](scripts/ui/apFlyaways.lua) so they do
not overlap — except beat-synced text, which must call `flyaway.create` directly.
Chat notices go through [apChatBadge.addMessage](scripts/ui/apChatBadge.lua). Trap
indicators register a poll-based provider with
[apTrapStatus.register](scripts/ui/apTrapStatus.lua).

### Tests — [scripts/test/apTest.lua](scripts/test/apTest.lua)

`necro.debug.DebugCommands` is reachable from a mod (`necro.*` is whitelisted), and
`debugCommands.register(name, fn)` is only `event.debugCommand.add(name, name, fn)`, so
the harness registers real Lua-console commands with no patching. Enable the debug console
in Options → Advanced, then **Shift+F4**. `aptest()` runs every test (`aptest("filter")` a
subset) and reports a summary in chat and the log; `aptests()` only lists what is registered;
`aptestwatch()` toggles level tests on each floor load. The console only runs registered commands,
never arbitrary Lua; `apsongs()` reports the Song Randomizer's effective config and who supplied it. The engine's own suite is at
`necro/test/Test.lua` and is worth reading before extending this one.

```lua
apTest.define({ name = "someInvariant", run = function(t) t.eq(a, b) end })
```

Three kinds, chosen by a flag on the spec:

- **schema** (default) — no level, no player, no turn. Item bans resolve straight from type
  names, since `itemBan.getBanFlags` puts both arguments through `ecs.getEntityTypeName`,
  which returns a string unchanged. Most tests belong here.
- **`world = true`** — a flat 19×19 floor uploaded as the `DUNGEON` resource with
  `options.modeID`, which is what `gameSession.getCurrentModeID` reads, so the floor comes
  up in an AP mode with a fixed `options.seed`. Runs only from the lobby in single player,
  because it overwrites the dungeon resource. `t.act(...)` steps turns synchronously.
- **`level = true`** — assertions against whatever floor is loaded. `aptestwatch()` runs
  them on every `gameStateLevel` past `levelLoadingDone`, which is the seam where the floor
  is built and `currentLevel` has stopped reading as loading.

Assertions record and continue rather than throwing; an uncaught error fails the one test.
The registry is unpersisted, so a reload re-runs every `define` cleanly.

`luaparser` (Python) parses this codebase, so `ast.parse` over `scripts/**/*.lua` is an
offline syntax gate that needs no game.

---

## Multiplayer (Synchrony online)

The mod is host-authoritative: only the host holds the TCP socket to the Python client.

- **`apClient.isHost()`** — true offline, or when local player id == host player id.
- **`apClient.isSessionConnected()`** — host checks its socket, joiners read the
  replicated `APState` resource. Level transitions block on
  `resources.allTransfersDone()`, which is why session state is a `netplay.Resource`
  rather than a player attribute.
- **`APState`** ([apStateSync.lua](scripts/client/apStateSync.lua)) — throttled
  (20 ticks) upload of `{ connected, seedName, playerName, slot, saveData }`. On
  `resourceLoaded`, joiners call `applyHostState` + `rebuildCaches` +
  `worldLabel.updateAll`. The `connected` flag bypasses the throttle.
- **`APEvents`** ([apEventSync.lua](scripts/client/apEventSync.lua)) — deathlink and
  TrapLink arrive at the host alone, so each is stamped with the turn it happened on and
  published. Every client applies it on that same turn; a joiner that learns late issues
  `clientActionBuffer.requestRollback(turn)` and resimulates. `apEventsApplied` is a
  snapshot variable so a rewind past an event lets it apply again. Entries older than
  `RETAIN_TURNS` (600) stop being republished. Subscribe with
  `apEventSync.subscribe(kind, apply)`; the apply callback runs on every client and must
  only touch simulated state.
- **Item delivery** uses a different mechanism: the host queues one
  `AP_ITEM_ACTION` system action per batch through `clientActionBuffer.addAction`, with
  the payload inside the action, so no client acts on data it has not received.
- `apUtils.isNetworked()` is `not singlePlayer.isActive()` — the switch between the
  networked and local delivery paths.
- **Joiners inherit the host's gameplay content.** DLC load status, mods, custom rules,
  extra modes and feature packs all follow the host, and a player must own every *active*
  DLC to join at all. So anything gated on `gameDLC.isAmplifiedLoaded()` is safe to assume
  identical across a session. Audio and graphics settings stay per-player.
  An owned DLC the host does not have stays unloaded, so runtime availability checks such
  as `soundtrack.isArtistAvailable` agree across a session — which is why they invalidate
  on `dlcStatusChange` rather than being resolved once.

---

## Interaction with the APWorld and Python client

Transport: JSON over localhost TCP, zstandard-compressed with a LuaJIT-compatible
`prefix_uint32` length frame. Port is discovered from `archipelago/port.txt`.

```
CotND (this mod) ──JSON/TCP──> CotNDServer ──> CotNDContext ──WebSocket──> AP server
```

### Mod → Python (`PacketDatatype` in `client/server.py`)

| datatype | Payload | Meaning |
|----------|---------|---------|
| `State` | `init`, `last_ap_index` | Request full state; resume point |
| `Locations` | `sources` (names or codes) | Location checks completed |
| `Victory` | — | Goal reached |
| `Death` | `msg` | Outgoing deathlink |
| `Chat` | `msg` | Say into the AP room |
| `Hint` | `type` | Request a hint |
| `HintNpc` | `location_code`, `player_slot` | Targeted hint from an NPC |
| `Disconnect` | `reason` | Graceful teardown, reason shown to the user |
| `SetDeathLink` / `SetTrapLink` | `deathlink` / `traplink` | Toggle |
| `ChangeDiamonds` | `value` | Mod-owned diamond balance |
| `ChangeBuffs` | `buffs` | Mod-owned buff config |
| `ChangeRunItems` | `bannedItems`, `nextRunItems` | Mod-owned shop/run state |

### Python → Mod (registered in `scripts/client/handlers/`)

| datatype | Handler | Meaning |
|----------|---------|---------|
| `Handshake` | handshake.lua | `seed`, `playerName`, `slot`; triggers the `State` request |
| `State` | state.lua | Full slot config + save state; `init = true` on first connect |
| `SaveUpdate` | saveUpdate.lua | Incremental save fields (snake_case → camelCase) |
| `Items` | items.lua | `[{ item, item_name, location_code, playername, ap_index }]` |
| `Locations` | locations.lua | Missing/checked location lists |
| `LocationInfo` | locationInfo.lua | Scout results for hints |
| `Death` | death.lua | Incoming deathlink |
| `Trap` | trap.lua | Incoming TrapLink: `trap_name` + `args` |
| `Chat` | chat.lua | Server message into game chat |
| `SetDeathLink` / `SetTrapLink` / `SetDiamonds` | respective files | Server-driven toggles |
| `SetSongRandomizer` | setSongRandomizer.lua | `song_randomizer` table: `mode`, `artistScope`, `seeding`, `duplicates` |
| `Disconnected` | disconnected.lua | AP server dropped |

### Authority split

- **AP server** — what is in the world, and what has been received.
- **Python `CotNDSaveData`** — derived CotND state: `zone_access`, `character_locations`,
  `shop_locations`, `codex_locations`, `extra_modes`. Persisted to AP
  DataStorage as `cotnd_{slot}_save`, keyed by seed with a `_v` sentinel.
- **Caged NPCs** — placement comes from slot data (`caged_npc_locations`); whether a cage is
  `freed` is the mod's own, set only by its "Caged X" location being checked. Receiving the
  NPC *item* opens the lobby room and never touches the cage.
- **This mod** — `diamonds` and `received_items` (listed in `MOD_OWNED` in
  [saveUpdate.lua](scripts/client/handlers/saveUpdate.lua)) because Python's copy runs
  ahead and would dedupe away items not yet applied. `characterLocations` and
  `extraModes` are **merged**, never replaced, so a locally-earned check is not reset by
  a stale reply.

`FIELD_MAP` in saveUpdate.lua is the single snake_case ↔ camelCase table; both `State`
and `SaveUpdate` read it. Adding a field means touching that map and nothing else.

### Version gate

Both directions use min-version (`>=`) comparison, never an exact pin:

- Mod → Python: the TCP identity `"AP:<modVersion>"` is checked against
  `minimum_mod_version` in `worlds/cotnd/archipelago.json`.
- Python → Mod: the `State` packet's `world_version` is checked against
  `apVersion.MIN_APWORLD_VERSION` in [version.lua](scripts/utils/version.lua); a mismatch
  disconnects with an explanatory chat message.

When bumping either side, update `mod.json`'s `version`, `version.lua`'s
`MOD_VERSION_FALLBACK` and `MIN_APWORLD_VERSION`, and `archipelago.json`'s
`world_version` / `minimum_mod_version` together.

---

## Game modes

`APAllZones`, `APSingleZone`, `APEnsemble`, `APBossRush` (+ `APHintMode`) are registered
via `gameSession.Mode.extend` in [scripts/modes/](scripts/modes/).
`apUtils.isAPContext(entity)` is the gate every AP behaviour checks — in the lobby it
means "standing in the AP lobby segment", elsewhere it means "in an AP mode". Use it
rather than testing mode ids by hand.

---

## Engine gotchas that have already cost time

- **HUD text colour is `fillColor`, not `color`.** `hud.drawText` copies the font table
  and overlays args, so `color` is silently ignored. Menu entries are the opposite —
  `entry.color` works but tints the whole label; splice `textFormat.color` for part of one.
- **Two speedrun clocks.** `speedrunTimer.getDeterministicTime()` for replicated decisions
  at level complete; `getTime()` for anything read continuously (the deterministic one
  collapses to the completed-level total while the player stands still).
- **Item ban strength lives on the character, not the item.** Ban flags are cached per
  (holder, item) and only flush on `ecsSchemaReloaded` or an `ITEM_BAN`-tagged setting
  change — so a runtime condition inside an `itemBanCheck` handler freezes after its first
  evaluation. Unban selectively via `inventoryUnbannedItems` at `entitySchemaLoadPlayer`.
  Pick masks from `itemBan.Type`, not `itemBan.Flag`; `Type.FULL` contains no LOSS flags.
- **`segment.add` resizes the whole map** and fires `mapSizeChange` to ten subscribers.
  Claim the total footprint up front with one `setLevelBounds`. `segments` is a
  `snapshot.levelVariable`, so runtime room generation is inside the rollback window.
- **`health.increaseMaxHealth` clamps; writing `entity.health.maxHealth` does not.**
  One heart is two health.
- **Boss exits are marked, not fixed.** `marker.lookUpFirst(marker.Type.STAIRS)` finds
  the post-fight exit, but only after `bossFightEnd` builds the corridor.
- **Flyaways split by turn context.** Inside a turn they are replicated snapshot state;
  outside they are render-only.
- **A song ending is a turn action, not presentation.** `SongEnd.lua` pushes
  `action.System.SONG_ENDED` into the client action buffer when the beatmap runs out.
  Zone songs don't loop, so a song's length is its floor's time limit; boss songs loop,
  except `boss_7` (Return of the NecroDancer), whose length is that fight's time limit.
  Code that moves tracks around must set `loop` from where the song plays, not where it
  came from — forcing `loop = true` removes every floor's time limit.
- **`event.musicTrack` at `order = "customMusic"` is the soundtrack seam.** It fires before
  the `zone`/`boss`/`special` handlers build filenames, so rewriting
  `ev.type/zone/floor/boss/artist` there carries beatmaps, layers, vocals and volumes with
  it. The stock phase 2 layer is only added when `ev.boss` is the NecroDancer, so moving
  that fight's track elsewhere drops it. The song shuffle itself lives in the CustomArtists
  dependency (`SongRandomizer.lua`); AP only answers its `event.customArtistsSongRandomizer`
  hook, in an AP context, with its own mode, artist scope, seeding, duplicates and seed.
- **AP and CustomArtists keep separate song-randomizer settings.** `MODDING.md` in that mod is
  the integration reference. AP's settings are synced with the slot (`songRandomizer` in
  DataStorage, the `SetSongRandomizer` table) in CustomArtists' own vocabulary, and govern AP
  runs and the AP lobby entirely, Off included. AP borrows `CustomArtists_SongRandomizerShrine`
  for the lobby settings room and overrides its `CustomArtists_showSongRandomizerMenu` handler
  for the copy in the AP lobby, which opens AP's own `AP_songRandomizer` menu
  ([apSongRandomizerMenu.lua](scripts/menu/apSongRandomizerMenu.lua)); the pause menu and the
  vanilla shrine keep CustomArtists' menu with no AP rows. Option hints are `customDesc`, read
  by the engine's `settingsMenu.createDynamicFooter`. CustomArtists' `updateVisuals` handler
  pins every shrine to *its* mode, so AP re-stamps `spriteSheet.frameX` at `sequence = 1` on the
  shrine standing in the AP lobby segment. `FULLY_RANDOM` ignores `ev.seed`, so the multiworld
  seed only reaches the shuffle through `PER_CHARACTER`. It is a declared dependency but can still
  be switched off, and three touchpoints break then: a module-scope
  `require "CustomArtists.scripts.…"` (guard with `pcall`), `object.spawn` of its shrine,
  since `ecs.spawn` raises *"Unknown type"* (guard with `ecs.isValidEntityType`), and a handler
  on one of *its* events — an event with handlers but no `orderedSelector` fails the load with
  *"invalid event … specified for handler"*, so `apSongRandomizer` only adds its handler when
  `pcall(require, …Randomizer)` succeeds. Overriding a handler name that never appears, filtering
  `entitiesWithComponents` on an unregistered component, and keying a schema or menu handler on a
  name that never appears are all inert.
- **The lobby track is chosen before players reach the AP lobby.** `event.levelLoad`'s
  `playLevelMusic` runs inside `gameStateLevel` order `"level"`, while `apLobby`'s teleport
  sits at `"splitScreen"` — the last entry in that list — so anything keyed on where a player
  is standing resolves against the *vanilla* lobby spawn. Restarting the track afterwards is
  audible however short the crossfade, so answer for where players are *about to be* instead:
  `apSongRandomizer` raises a flag at `"resetLevelVariables"` and drops it at `"splitScreen"`,
  and the teleport's own condition is just `isSessionConnected()`. `setLobbyState` runs before
  the `gameStateLevel` chain, so `gameState.isInLobby()` is already correct that early.
- **Weapon shapes:** `customWeapons.registerShape` refuses `xmlTypes` from a mod, but
  stamping `weaponType` + the shape component + `weaponMaterial`/`weaponMaterialBase` via
  `entitySchemaLoadNamedEntity` achieves the same thing. See
  [zweihander.lua](scripts/weapons/zweihander.lua).
- **A player's body has no player during its own spawn.** `Player.lua` spawns the character, then
  calls `setControlledEntity`, so inside `objectSpawn` (where the initial inventory and every buff
  is granted) `controllable.playerID` is 0. The id is in `playableCharacter.pendingPlayerID`;
  anything keyed by player across the lobby → run boundary must fall back to it.
- **Not every defeated enemy dies.** Every `explosion.registerExplosion` spell carries
  `spellcastDespawnCaster`, so a pixie hit by a player is deleted by its own explosion and
  `objectDeath` never fires. `apEnemyChecks` catches it at `objectTakeDamage` order `spellLate`,
  sequence 1, where the shielded hit's player attacker is still on the event.
- **The walkable lobby counts as in game.** It runs as the `IN_GAME` state with the lobby flag,
  so `gameState.isInGame()` and `isInLobby()` are both true there; only `isInLobby()` tells it
  apart from a run.
- **A `character` is not necessarily somewhere you can stand.** When a Coral Riff tentacle
  dies, `spawnDecorTentacle` places a `TentacleDecor` one column outside the arena, inside
  the wall, and it carries `character`. Before moving a player onto a character's tile,
  check the tile with `collision.check(x, y, mask(WALL, BORDER))`
  ([swapTrap.lua](scripts/traps/traps/swapTrap.lua)).
- **`object.spawn` can hand back an enemy that is already gone.** On a procedural floor,
  `EnemySubstitutions` deletes any spawned enemy listed in a living player's `enemyBans` (Dove:
  Harpy and every Monkey) inside `objectSpawn`. Check `gameObject.despawned` before using the
  result; possessing one leaves the player controlling a deleted entity, and every read of
  that body then raises from `Entities.lua`.
- **`descent.active` spans the level transition.** It is set on the stairs and cleared only
  by `objectDescentArrive` on the next floor, so it is the simulated signal that a level change
  is in flight. No trap lands while any player is descending; `trapHandler` keeps it queued
  for the next floor.
- **One HUD slot holds every countdown.** Tempo's `damageCountdown`, Chaunter's
  `Sync_possessableTimer`, Coda's buff counter, DeathLink's `AP_damageCountdown` and the Timer
  Trap's `AP_timerCountdown` all draw into element `damageCountdown`, and all keep running side
  by side. Each source registers a provider with `apDamageCountdownHUD.register`
  ([ui/apDamageCountdown.lua](scripts/ui/apDamageCountdown.lua)); once two show, or one that
  is not `native`, `ownsSlot` is true. The native handlers then stand down, and the soonest
  beat count draws in MEDIUM while the rest go small beside it, each in its own colour. Countdowns belong on the body the
  player is driving (`player.getPlayerEntities()`), since `apCarryDamageCountdown` moves
  them across possession with the remaining beats intact. A DeathLink that ends on a
  possessed body also hits its `Sync_possessable.possessor`; the creature dying alone only
  ejects Chaunter.

---

## Surfacing improvements and tech debt

When you notice an optimization, a simplification, or tech debt while working on
something else — a hand-rolled loop the library already covers, a duplicated table that
wants one owner, a subsystem two files reimplement differently, a hot path doing more
work than it needs — **say so and propose the fix**. Name the file, describe the change in
a sentence or two, and offer to make it.

Do not silently fold it into the current change. Scope stays what was asked; the
suggestion is a separate offer I accept or decline. If several turn up, list them briefly
rather than writing an essay on each.

## Comments

**Default to none.** Well-named functions in a codebase this consistent explain
themselves — the implementation *is* the description, and restating it in prose only adds
something to keep in sync.

A comment earns its place only where the logic is genuinely contrived or unreadable
without one: a bit-twiddling hash, a compensation for engine behaviour that looks wrong on
its face, an ordering constraint nothing in the code expresses. That is rare.

When one is warranted, it is **one line saying what the code does** — never why it was
written that way, never what would break otherwise, never a paragraph of engine
archaeology. Multi-line rationale comments break up the code, make it harder to read as a
whole, and rot the moment the surrounding logic changes. Rationale belongs in the commit
message or in our conversation.

```lua
-- Moves the pedestal's existing tag onto whatever now stands there.
local function transferPriceTag(from, to)
```

Before finishing an edit, scan the diff for any comment spanning two or more lines and cut
it down or delete it.

## Working conventions

- **Verify before asserting.** There is no Lua toolchain here and the mod cannot be run
  from this environment. A function body in `NecroExtracted` proves neither that a mod can
  reach it nor that it does what its name suggests — trace it to the data it reads and
  confirm something populates that data. When a claim can only be settled in game, say so
  plainly and name the one check that would settle it. Prefer designs that fail visibly
  over ones that fail open.
- **Make edits with the Edit tool** — never through `sed`, heredocs, or inline scripts.
- **Commit messages carry no Claude attribution** — no `Co-Authored-By` trailer.
- **Naming:** components `AP_camelCase`; files `apThing.lua`; handler names descriptive
  and unique per event (`apGrantInitialItems`); modules required as
  `require("AP.scripts.…")` with library requires listed first, alphabetically, then AP
  requires.
- **Logging** goes through `require("AP.scripts.utils.log").apLog(msg, "warning")`.

---

## Keeping this file current

This document is meant to absorb what each session learns. When you discover an engine
behaviour that contradicts the decompile, a sandbox limit, a subsystem seam worth reusing,
or a protocol change on the Python side, add it here in the same session — a short entry
in the right section beats a long one written later. Prune anything that stops being true.
