# ECS

A strict Luau entity component system for Roblox.

This framework keeps game state in entities and components, then runs logic through queries, systems, events, command buffers, catalogs, and optional networking. The point is to keep gameplay code organized around data instead of large object trees or tangled scripts.

## Structure

```text
ReplicatedStorage/
└── ECS/
    ├── Core/
    │   ├── World.lua
    │   ├── EntityManager.lua
    │   ├── ComponentStore.lua
    │   ├── QueryEngine.lua
    │   ├── Scheduler.lua
    │   ├── CommandBuffer.lua
    │   ├── EventBus.lua
    │   └── Resources.lua
    ├── Debug/
    │   └── DebugAPI.lua
    ├── Net/
    │   └── NetworkBridge.lua
    └── Util/
        └── Catalog.lua
```

## Basic Idea

An entity is just a number.

A component is data attached to that number.

A system is logic that runs over every entity matching a query.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage.ECS.Core.World)

local world = World.new()

local Position = world:Component("Position", Vector3.zero)
local Velocity = world:Component("Velocity", Vector3.zero)
local Player = world:Tag("Player")

local entity = world:Spawn(
	Player(),
	Position(Vector3.new(0, 5, 0)),
	Velocity(Vector3.new(0, 0, -12))
)
```

The entity above has no behavior by itself. It only has data. Systems decide what happens to it.

## Components And Tags

Components store values.

```lua
local Health = world:Component("Health", 100)

local entity = world:Spawn(Health(75))

print(world:Get(entity, Health)) -- 75
world:Set(entity, Health, 60)
```

Tags are components with no meaningful data. They mark an entity as something.

```lua
local Enemy = world:Tag("Enemy")

local enemy = world:Spawn(Enemy())

print(world:Has(enemy, Enemy)) -- true
```

Components and tags are both queried the same way.

## Queries

Queries select entities by component layout.

```lua
local query = world:Query(Position, Velocity):Cached()

for entity, position, velocity in world:Each(query, Position, Velocity) do
	print(entity, position, velocity)
end
```

Filters can require all, any, or none of a group.

```lua
local Alive = world:Tag("Alive")
local Dead = world:Tag("Dead")
local Burning = world:Tag("Burning")
local Frozen = world:Tag("Frozen")

local query = world:Query(
	World.All(Position, Alive),
	World.Any(Burning, Frozen),
	World.None(Dead)
):Cached()
```

This means:

- must have `Position`
- must have `Alive`
- must have either `Burning` or `Frozen`
- must not have `Dead`

## Systems

Systems run through the scheduler when `world:Update(dt)` is called.

```lua
world:System({ Position, Velocity }, function(entity, position, velocity, dt, commands)
	commands:Set(entity, Position, position + velocity * dt)
end, {
	Name = "MovementSystem",
	Phase = "Update",
	Priority = 10,
})

game:GetService("RunService").Heartbeat:Connect(function(dt)
	world:Update(dt)
end)
```

The system receives:

- entity id
- requested component values
- delta time
- command buffer

The command buffer lets systems queue changes safely while iteration is happening.

## Command Buffer

The command buffer batches mutations until the end of the frame.

```lua
world:System({ Health }, function(entity, health, dt, commands)
	if health <= 0 then
		commands:Remove(entity, Alive)
		commands:Add(entity, Dead())
	end
end)
```

Queued commands flush after systems run inside `world:Update(dt)`.

This avoids mutating component stores while queries are currently iterating over them.

## Events

The event bus supports immediate events and queued events.

Immediate event:

```lua
world:On("DamageTaken", function(entity, amount)
	print(entity, amount)
end)

world:Emit("DamageTaken", entity, 25)
```

Queued event:

```lua
world:Queue("AbilityUsed", entity, "Dash")
```

Queued events are handled by event systems.

```lua
world:EventSystem("AbilityUsed", function(entity, abilityName, dt, commands)
	print(entity, abilityName)
end, {
	Name = "AbilityEventSystem",
	Priority = 20,
})
```

This is useful when gameplay should stay frame-based and deterministic instead of firing logic from random places in the codebase.

## Component Lifecycle Events

Components also fire add, change, and remove events.

```lua
world:OnAdd(Health, function(entity, value)
	print("health added", entity, value)
end)

world:OnChange(Health, function(entity, value, previous)
	print("health changed", entity, previous, value)
end)

world:OnRemove(Health, function(entity, value)
	print("health removed", entity, value)
end)
```

## Relations And Pairs

Relations connect entities to other entities or targets.

```lua
local Owner = world:Relation("Owner", {
	Exclusive = true,
})

local playerEntity = world:Spawn(Player())
local swordEntity = world:Spawn(world:Pair(Owner, playerEntity))

print(world:Target(swordEntity, Owner)) -- playerEntity
```

Exclusive relations make sure an entity only has one target for that relation.

The framework also creates `ChildOf` by default.

```lua
world:SetParent(swordEntity, playerEntity)

for child in world:Children(playerEntity) do
	print(child)
end
```

## Catalogs

Catalogs route named actions into handlers.

They are useful for abilities, items, commands, upgrades, or any system where string keys should map to controlled behavior without huge if chains.

```lua
world:Catalog("Abilities", {
	Dash = function(world, context)
		local entity = context.entity
		if not entity then
			return
		end

		local Position = context.Position
		local Direction = context.Direction

		local position = world:Get(entity, Position)
		local direction = world:Get(entity, Direction)

		world:Set(entity, Position, position + direction * 18)
		world:Queue("AbilityActivated", entity, "Dash")
	end,
})

world:Dispatch("Abilities", "Dash", {
	entity = entity,
	Position = Position,
	Direction = Direction,
})
```

Catalogs keep routing separate from execution. Systems can ask for an action by key, while the catalog decides if that key exists and what function owns it.

## Networking

`NetworkBridge` is an optional RemoteEvent wrapper for Roblox client/server gameplay.

The intended pattern is:

- client sends intent
- server validates entity/action
- server mutates ECS state
- server replicates results back to clients

Server:

```lua
local world = World.new()
local network = world:Network()

world:Catalog("Actions", {
	Dash = function(world, context)
		local entity = context.entity
		if not entity then
			return
		end

		context.commands:Emit("ActionAccepted", entity, "Dash")
	end,
})

network:BindCatalog("Actions")
```

Client:

```lua
local world = World.new()
local network = world:Network()

network:SendAction("Dash", entityId, {
	direction = Vector3.new(0, 0, -1),
})
```

The bridge does not make the client authoritative. It only transports intent. The server still owns the world.

## Debug API

Every world has a debug API.

```lua
local snapshot = world:Snapshot()
local text = world:Serialize()

world:Deserialize(text)
```

Snapshots are useful for inspection, testing, saving temporary state, or comparing changes while developing systems.

`QueryText` can inspect entity sets from a simple string.

```lua
local result = world:QueryText("Position Velocity !Dead")
print(result.count)
```

## Full Example

```lua
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.ECS.Core.World)

local world = World.new()

local Position = world:Component("Position", Vector3.zero)
local Velocity = world:Component("Velocity", Vector3.zero)
local Health = world:Component("Health", 100)
local Player = world:Tag("Player")
local Dead = world:Tag("Dead")

local playerEntity = world:Spawn(
	Player(),
	Position(Vector3.new(0, 5, 0)),
	Velocity(Vector3.new(0, 0, -16)),
	Health(100)
)

world:System({ Position, Velocity }, function(entity, position, velocity, dt, commands)
	commands:Set(entity, Position, position + velocity * dt)
end, {
	Name = "MovementSystem",
	Priority = 10,
})

world:System({ Health }, function(entity, health, dt, commands)
	if health <= 0 and not world:Has(entity, Dead) then
		commands:Add(entity, Dead())
		commands:Emit("EntityDied", entity)
	end
end, {
	Name = "DeathSystem",
	Priority = 20,
})

world:EventSystem("EntityDied", function(entity, dt, commands)
	print("entity died", entity)
end, {
	Name = "DeathEventSystem",
	Priority = 30,
})

RunService.Heartbeat:Connect(function(dt)
	world:Update(dt)
end)
```

## Rojo

The project is mapped as:

```text
ReplicatedStorage.ECS -> ReplicatedStorage/ECS
```

Run:

```powershell
cd C:\Users\mikol\Desktop\ecs
rojo serve
```

Then connect from Roblox Studio using the Rojo plugin.

