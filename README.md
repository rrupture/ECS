## Author

[777rupture](https://github.com/777rupture)

---

# bsECS

A Roblox ECS framework with a runtime inspector plugin, live component editing, debug overlays, and an example game runner.

Basically: entities are just IDs, components are stored in fast sparse sets, systems run through queries, and the plugin lets you watch the whole thing live.

---

## Install

Put the files in Roblox Studio like this:

```text
ReplicatedStorage
└── ECS
    ├── Core
    │   ├── CommandBuffer
    │   ├── ComponentStore
    │   ├── EntityManager
    │   ├── EventBus
    │   ├── QueryEngine
    │   ├── Scheduler
    │   └── World
    └── Debug
        └── DebugAPI

ServerScriptService
└── ECSRunner
```

For the plugin, copy:

```text
Plugin/ECSInspector.lua
```

into your Roblox plugins folder:

```text
C:\Users\yourname\AppData\Local\Roblox\Plugins
```

Restart Studio after installing the plugin.

---

## Usage

```lua
local World = require(game.ReplicatedStorage.ECS.Core.World)

local world = World.new()

local Position = world:Component("Position", Vector3.zero)
local Velocity = world:Component("Velocity", Vector3.zero)
local Health = world:Component("Health", 100)
local Dead = world:Tag("Dead")

local entity = world:Spawn(
    Position(Vector3.new(0, 5, 0)),
    Velocity(Vector3.new(4, 0, 0)),
    Health(100)
)

world:System({ Position, Velocity }, function(id, pos, vel, dt)
    world:Set(id, Position, pos + vel * dt)
end, {
    Name = "MovementSystem",
    Phase = "Update",
    Priority = 10,
})

game:GetService("RunService").Heartbeat:Connect(function(dt)
    world:Update(dt)
end)
```

---

## Queries

```lua
-- simple query
world:Query(Position, Velocity)

-- filter builders
world:Query(
    World.All(Position, Velocity),
    World.None(Dead)
)

-- chainable style
world:Query(Position)
    :With(Velocity)
    :Without(Dead)
    :Cached()
```

---

## Components And Tags

```lua
local Position = world:Component("Position", Vector3.zero)
local Health = world:Component("Health", 100)
local Player = world:Tag("Player")

local id = world:Spawn(
    Position(Vector3.new(0, 3, 0)),
    Health(100),
    Player
)

world:Add(id, Health, 75)
world:Remove(id, Player)
print(world:Get(id, Health))
print(world:Has(id, Player))
```

---

## Relationships

bsECS supports ECS-style relationships.

```lua
local OwnedBy = world:Relation("OwnedBy")

local player = world:Spawn(Player)
local projectile = world:Spawn(Projectile)

world:Add(projectile, world:Pair(OwnedBy, player))
```

Hierarchy is built in too:

```lua
world:SetParent(child, parent)

print(world:Parent(child))

for childId in world:Children(parent) do
    print(childId)
end
```

---

## Command Buffers

Use command buffers when a system needs to change entities while systems are running.

```lua
world:System({ Health }, function(id, hp, dt, commands)
    if hp <= 0 then
        commands:Add(id, Dead)
        commands:Despawn(id)
    end
end)
```

Commands are applied after systems finish.

---

## Events

```lua
world:OnAdd(Health, function(id, value)
    print("health added", id, value)
end)

world:OnChange(Health, function(id, value, old)
    print("health changed", old, "->", value)
end)

world:OnRemove(Health, function(id)
    print("health removed", id)
end)
```

---

## Inspector Plugin

The plugin shows the world while the game is running:

- live entities
- component values
- system timings
- component counts
- relationships
- editable values

Click an entity, edit a value in the right panel, then unfocus the box. The runtime updates it.

---

## Example Runner

The example runner includes:

- enemies
- projectiles
- pickups
- status effects
- abilities
- health bars
- velocity arrows
- waves
- cleanup systems

Use:

```text
Examples/ECSRunner.lua
```

as:

```text
ServerScriptService > ECSRunner
```

Press Play and open the bsECS inspector.

---

## Current Features

- [x] Entity IDs with generations
- [x] Sparse set component storage
- [x] Components and tags
- [x] Queries
- [x] Chainable cached queries
- [x] Systems and scheduler phases
- [x] Priority / After / Before ordering
- [x] Command buffers
- [x] Resources
- [x] Events
- [x] Change detection
- [x] Relationships
- [x] Hierarchy
- [x] Snapshots
- [x] Serialization
- [x] Runtime inspector plugin
- [x] Live component editing
- [x] Debug overlays
- [x] Example runner
 
