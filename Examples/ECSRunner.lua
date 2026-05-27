--!strict

local RunService = game:GetService("RunService")
local World = require(game.ReplicatedStorage.ECS.Core.World)

local world = World.new()

local Name = world:Component("Name", "Entity")
local Position = world:Component("Position", Vector3.zero)
local Velocity = world:Component("Velocity", Vector3.zero)
local Health = world:Component("Health", 100)
local MaxHealth = world:Component("MaxHealth", 100)
local Radius = world:Component("Radius", 2)
local Damage = world:Component("Damage", 10)
local Lifetime = world:Component("Lifetime", 1)
local Cooldown = world:Component("Cooldown", 0)
local Team = world:Component("Team", "Neutral")
local Render = world:Component("Render", nil)
local EnemyType = world:Component("EnemyType", "")
local ProjectileType = world:Component("ProjectileType", "")
local PickupType = world:Component("PickupType", "")
local AbilityClock = world:Component("AbilityClock", 0)
local SpawnClock = world:Component("SpawnClock", 0)
local Burn = world:Component("Burn", 0)
local Slow = world:Component("Slow", 0)
local Poison = world:Component("Poison", 0)
local Shield = world:Component("Shield", 0)
local Stun = world:Component("Stun", 0)

local Player = world:Tag("Player")
local Enemy = world:Tag("Enemy")
local Projectile = world:Tag("Projectile")
local Pickup = world:Tag("Pickup")
local Overlay = world:Tag("Overlay")
local Dead = world:Tag("Dead")

local Chaser = world:Tag("Chaser")
local Shooter = world:Tag("Shooter")
local Tank = world:Tag("Tank")
local Splitter = world:Tag("Splitter")
local Exploder = world:Tag("Exploder")

local Bullet = world:Tag("Bullet")
local Rocket = world:Tag("Rocket")
local Orb = world:Tag("Orb")
local BeamPulse = world:Tag("BeamPulse")

local HealthPickup = world:Tag("HealthPickup")
local SpeedPickup = world:Tag("SpeedPickup")
local DamagePickup = world:Tag("DamagePickup")
local ShieldPickup = world:Tag("ShieldPickup")

local DashAbility = world:Tag("DashAbility")
local PulseAbility = world:Tag("PulseAbility")
local MineAbility = world:Tag("MineAbility")
local HealAbility = world:Tag("HealAbility")

local OwnedBy = world:Relation("OwnedBy")
local Targets = world:Relation("Targets")

world:SetResource("Bounds", 60)
world:SetResource("Wave", 1)
world:SetResource("Score", 0)

local EnemyCatalog = {
	Chaser = { Tag = Chaser, Health = 70, Speed = 17, Radius = 2.1, Damage = 11, Color = Color3.fromRGB(240, 88, 88) },
	Shooter = { Tag = Shooter, Health = 55, Speed = 10, Radius = 2, Damage = 9, Color = Color3.fromRGB(255, 185, 70), FireRate = 1.25 },
	Tank = { Tag = Tank, Health = 180, Speed = 7, Radius = 3.2, Damage = 18, Color = Color3.fromRGB(120, 135, 255) },
	Splitter = { Tag = Splitter, Health = 80, Speed = 13, Radius = 2.2, Damage = 8, Color = Color3.fromRGB(186, 120, 255) },
	Exploder = { Tag = Exploder, Health = 45, Speed = 19, Radius = 2.1, Damage = 24, Color = Color3.fromRGB(255, 105, 165) },
}

local ProjectileCatalog = {
	Bullet = { Tag = Bullet, Speed = 54, Radius = 0.8, Damage = 13, Lifetime = 2.4, Color = Color3.fromRGB(255, 240, 150) },
	Rocket = { Tag = Rocket, Speed = 34, Radius = 1.25, Damage = 22, Lifetime = 3.0, Color = Color3.fromRGB(255, 125, 80) },
	Orb = { Tag = Orb, Speed = 26, Radius = 1.1, Damage = 10, Lifetime = 4.0, Color = Color3.fromRGB(135, 215, 255) },
	BeamPulse = { Tag = BeamPulse, Speed = 70, Radius = 1.6, Damage = 18, Lifetime = 0.9, Color = Color3.fromRGB(120, 255, 180) },
}

local PickupCatalog = {
	Health = { Tag = HealthPickup, Color = Color3.fromRGB(100, 255, 130), Radius = 2.2 },
	Speed = { Tag = SpeedPickup, Color = Color3.fromRGB(120, 210, 255), Radius = 2.2 },
	Damage = { Tag = DamagePickup, Color = Color3.fromRGB(255, 230, 90), Radius = 2.2 },
	Shield = { Tag = ShieldPickup, Color = Color3.fromRGB(160, 130, 255), Radius = 2.2 },
}

local AbilityCatalog = {
	Dash = { Tag = DashAbility, Cooldown = 3.4 },
	Pulse = { Tag = PulseAbility, Cooldown = 2.8 },
	Mine = { Tag = MineAbility, Cooldown = 4.6 },
	Heal = { Tag = HealAbility, Cooldown = 6.0 },
}

local enemyOrder = { "Chaser", "Shooter", "Tank", "Splitter", "Exploder" }
local pickupOrder = { "Health", "Speed", "Damage", "Shield" }

local function rand(min: number, max: number): number
	return min + math.random() * (max - min)
end

local function spawnPoint(radius: number?): Vector3
	local r = radius or rand(12, 52)
	local a = rand(0, math.pi * 2)
	return Vector3.new(math.cos(a) * r, 4, math.sin(a) * r)
end

local function makeBillboard(part: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "bsECS_Health"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(72, 12)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = gui

	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(110, 230, 130)
	bar.BorderSizePixel = 0
	bar.Parent = back

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.Font = Enum.Font.Code
	text.TextSize = 9
	text.Text = ""
	text.Parent = back

	return gui, bar, text
end

local function makePart(name: string, color: Color3, size: Vector3, shape: Enum.PartType?): any
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.Parent = workspace

	local billboard, bar, text = makeBillboard(part)

	local arrow = Instance.new("Part")
	arrow.Name = name .. "_Velocity"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.fromRGB(85, 210, 255)
	arrow.Transparency = 1
	arrow.Size = Vector3.new(0.16, 0.16, 1)
	arrow.Parent = workspace

	return {
		Part = part,
		Billboard = billboard,
		Bar = bar,
		Label = text,
		Arrow = arrow,
	}
end

local function destroyRender(render: any)
	if not render then
		return
	end
	for _, key in ipairs({ "Part", "Arrow" }) do
		local instance = render[key]
		if instance and instance.Parent then
			instance:Destroy()
		end
	end
end

local function spawnOverlay(parent: number, label: string): number
	local child = world:Spawn(Name(label), Overlay)
	world:SetParent(child, parent)
	return child
end

local function spawnPlayer(): number
	local render = makePart("PlayerCore", Color3.fromRGB(80, 180, 255), Vector3.new(3, 3, 3), Enum.PartType.Ball)
	local id = world:Spawn(
		Name("Player Core"),
		Player,
		Team("Player"),
		Position(Vector3.new(0, 4, 0)),
		Velocity(Vector3.zero),
		Health(260),
		MaxHealth(260),
		Radius(3),
		Shield(35),
		Render(render),
		AbilityClock(0),
		SpawnClock(0),
		DashAbility,
		PulseAbility,
		MineAbility,
		HealAbility
	)
	spawnOverlay(id, "Player Overlay")
	return id
end

local player = spawnPlayer()
world:SetResource("Player", player)

local function spawnEnemy(kind: string, pos: Vector3?): number
	local cfg = EnemyCatalog[kind]
	local render = makePart(kind, cfg.Color, Vector3.new(cfg.Radius * 2, cfg.Radius * 2, cfg.Radius * 2), Enum.PartType.Ball)
	local id = world:Spawn(
		Name(kind .. " Enemy"),
		Enemy,
		cfg.Tag,
		Team("Enemy"),
		EnemyType(kind),
		Position(pos or spawnPoint()),
		Velocity(Vector3.zero),
		Health(cfg.Health),
		MaxHealth(cfg.Health),
		Damage(cfg.Damage),
		Radius(cfg.Radius),
		Cooldown(rand(0.2, 1.5)),
		Render(render)
	)
	world:Add(id, world:Pair(Targets, player))
	spawnOverlay(id, kind .. " Overlay")
	return id
end

local function spawnProjectile(kind: string, owner: number, team: string, pos: Vector3, dir: Vector3): number
	local cfg = ProjectileCatalog[kind]
	local render = makePart(kind .. "Projectile", cfg.Color, Vector3.new(cfg.Radius * 2, cfg.Radius * 2, cfg.Radius * 2), Enum.PartType.Ball)
	local velocity = if dir.Magnitude > 0 then dir.Unit * cfg.Speed else Vector3.new(0, 0, -cfg.Speed)

	local id = world:Spawn(
		Name(kind .. " Projectile"),
		Projectile,
		cfg.Tag,
		Team(team),
		ProjectileType(kind),
		Position(pos),
		Velocity(velocity),
		Damage(cfg.Damage),
		Radius(cfg.Radius),
		Lifetime(cfg.Lifetime),
		Render(render)
	)
	world:Add(id, world:Pair(OwnedBy, owner))
	world:SetParent(id, owner)
	return id
end

local function spawnPickup(kind: string, pos: Vector3?): number
	local cfg = PickupCatalog[kind]
	local render = makePart(kind .. "Pickup", cfg.Color, Vector3.new(2, 2, 2), Enum.PartType.Ball)
	local id = world:Spawn(
		Name(kind .. " Pickup"),
		Pickup,
		cfg.Tag,
		PickupType(kind),
		Position(pos or spawnPoint(30)),
		Radius(cfg.Radius),
		Lifetime(18),
		Render(render)
	)
	spawnOverlay(id, kind .. " Pickup Overlay")
	return id
end

for i = 1, 8 do
	spawnEnemy(enemyOrder[((i - 1) % #enemyOrder) + 1], spawnPoint())
end
for i = 1, 4 do
	spawnPickup(pickupOrder[i], spawnPoint(24))
end

local function applyDamage(target: number, amount: number, status: string?)
	if not world:IsAlive(target) or world:Has(target, Dead) or not world:Has(target, Health) then
		return
	end

	local shield = (world:Get(target, Shield) or 0) :: number
	if shield > 0 then
		local absorbed = math.min(shield, amount)
		amount -= absorbed
		world:Set(target, Shield, shield - absorbed)
	end

	if amount > 0 then
		local hp = world:Get(target, Health) :: number
		world:Set(target, Health, hp - amount)
	end

	if status == "Burn" then
		world:Set(target, Burn, 3)
	elseif status == "Slow" then
		world:Set(target, Slow, 2.5)
	elseif status == "Poison" then
		world:Set(target, Poison, 4)
	elseif status == "Stun" then
		world:Set(target, Stun, 0.75)
	end
end

local function enemyCount(): number
	local n = 0
	for _, _entity in ipairs(world:Query(Enemy):Without(Dead):Cached():Run()) do
		n += 1
	end
	return n
end

world:System(world:Query(Player):Cached(), function(entity, _playerTag, dt)
	local t = os.clock()
	local pos = Vector3.new(math.cos(t * 0.45) * 8, 4, math.sin(t * 0.45) * 8)
	local old = world:Get(entity, Position) :: Vector3
	world:Set(entity, Velocity, (pos - old) / math.max(dt, 1 / 240))
	world:Set(entity, Position, pos)
end, {
	Name = "PlayerOrbitSystem",
	Phase = "PreUpdate",
	Priority = 30,
})

world:System(world:Query(Player):Cached(), function(entity, _playerTag, dt)
	local clock = (world:Get(entity, SpawnClock) :: number) - dt
	if clock > 0 then
		world:Set(entity, SpawnClock, clock)
		return
	end

	world:Set(entity, SpawnClock, 2.4)
	local wave = world:GetResource("Wave") :: number
	world:SetResource("Wave", wave + 1)

	if enemyCount() < 18 then
		for i = 1, math.min(2 + math.floor(wave / 3), 5) do
			spawnEnemy(enemyOrder[((wave + i - 2) % #enemyOrder) + 1], spawnPoint())
		end
	end
	if math.random() < 0.55 then
		spawnPickup(pickupOrder[((wave - 1) % #pickupOrder) + 1], spawnPoint(28))
	end
end, {
	Name = "WaveSystem",
	Phase = "PreUpdate",
	Priority = 20,
})

world:System(world:Query(Position, Velocity):Without(Dead):Cached(), function(entity, pos, vel, dt)
	if world:Has(entity, Stun) then
		vel = Vector3.zero
	elseif world:Has(entity, Slow) then
		vel *= 0.45
	end

	local bounds = world:GetResource("Bounds") :: number
	local nextPos = pos + vel * dt
	if math.abs(nextPos.X) > bounds then
		vel = Vector3.new(-vel.X, vel.Y, vel.Z)
		nextPos = pos + vel * dt
	end
	if math.abs(nextPos.Z) > bounds then
		vel = Vector3.new(vel.X, vel.Y, -vel.Z)
		nextPos = pos + vel * dt
	end

	world:Set(entity, Velocity, vel)
	world:Set(entity, Position, nextPos)
end, {
	Name = "MovementSystem",
	Phase = "Update",
	Priority = 40,
})

world:System(world:Query(Position, EnemyType, Cooldown):With(Enemy):Without(Dead):Cached(), function(entity, pos, kind, cooldown, dt)
	local playerId = world:GetResource("Player") :: number
	if not world:IsAlive(playerId) then
		return
	end

	local playerPos = world:Get(playerId, Position) :: Vector3
	local cfg = EnemyCatalog[kind]
	local delta = playerPos - pos
	local dist = delta.Magnitude
	local dir = if dist > 0.1 then delta.Unit else Vector3.zero
	local speed = cfg.Speed

	if world:Has(entity, Stun) then
		speed = 0
	elseif world:Has(entity, Slow) then
		speed *= 0.4
	end

	if kind == "Shooter" and dist < 45 then
		world:Set(entity, Velocity, dir * speed * 0.35)
		cooldown -= dt
		if cooldown <= 0 then
			world:Set(entity, Cooldown, cfg.FireRate or 1.4)
			spawnProjectile("Orb", entity, "Enemy", pos + dir * 3, dir)
		else
			world:Set(entity, Cooldown, cooldown)
		end
	else
		world:Set(entity, Velocity, dir * speed)
	end
end, {
	Name = "AISystem",
	Phase = "Update",
	Priority = 35,
})

world:System(world:Query(Player, AbilityClock):Without(Dead):Cached(), function(entity, _playerTag, clock, dt)
	clock -= dt
	if clock > 0 then
		world:Set(entity, AbilityClock, clock)
		return
	end
	world:Set(entity, AbilityClock, 1.2)

	local pos = world:Get(entity, Position) :: Vector3
	local t = os.clock()
	local mode = math.floor(t) % 4

	if mode == 0 and world:Has(entity, PulseAbility) then
		for _, enemy in ipairs(world:Query(Position, Health):With(Enemy):Without(Dead):Cached():Run()) do
			local enemyPos = world:Get(enemy, Position) :: Vector3
			if (enemyPos - pos).Magnitude < 20 then
				applyDamage(enemy, 18, "Stun")
			end
		end
		spawnProjectile("BeamPulse", entity, "Player", pos, Vector3.new(1, 0, 0))
	elseif mode == 1 and world:Has(entity, MineAbility) then
		spawnProjectile("Rocket", entity, "Player", pos + Vector3.new(rand(-4, 4), 0, rand(-4, 4)), Vector3.new(rand(-1, 1), 0, rand(-1, 1)))
	elseif mode == 2 and world:Has(entity, DashAbility) then
		local dir = Vector3.new(math.cos(t * 2), 0, math.sin(t * 2))
		world:Set(entity, Position, pos + dir * 12)
	else
		local hp = world:Get(entity, Health) :: number
		local maxHp = world:Get(entity, MaxHealth) :: number
		world:Set(entity, Health, math.min(maxHp, hp + 14))
	end
end, {
	Name = "AbilitySystem",
	Phase = "Update",
	Priority = 25,
})

world:System(world:Query(Position, Damage, Radius, Team):With(Projectile):Without(Dead):Cached(), function(projectile, pos, damage, radius, team, _dt, commands)
	local targets = world:Query(Position, Health, Radius, Team):Without(Dead):Cached():Run()
	for _, target in ipairs(targets) do
		if target ~= projectile and world:Get(target, Team) ~= team then
			local targetPos = world:Get(target, Position) :: Vector3
			local targetRadius = world:Get(target, Radius) :: number
			if (targetPos - pos).Magnitude <= radius + targetRadius then
				local status = nil
				if world:Has(projectile, Rocket) then
					status = "Burn"
				elseif world:Has(projectile, Orb) then
					status = "Slow"
				elseif world:Has(projectile, BeamPulse) then
					status = "Stun"
				end
				applyDamage(target, damage, status)
				commands:Add(projectile, Dead)
				break
			end
		end
	end
end, {
	Name = "CollisionSystem",
	Phase = "Update",
	Priority = 20,
})

world:System(world:Query(Position, Radius, PickupType):With(Pickup):Without(Dead):Cached(), function(entity, pos, radius, kind, _dt, commands)
	local playerId = world:GetResource("Player") :: number
	if not world:IsAlive(playerId) then
		return
	end

	local playerPos = world:Get(playerId, Position) :: Vector3
	local playerRadius = world:Get(playerId, Radius) :: number
	if (playerPos - pos).Magnitude > radius + playerRadius then
		return
	end

	if kind == "Health" then
		local hp = world:Get(playerId, Health) :: number
		local maxHp = world:Get(playerId, MaxHealth) :: number
		world:Set(playerId, Health, math.min(maxHp, hp + 45))
	elseif kind == "Shield" then
		world:Set(playerId, Shield, ((world:Get(playerId, Shield) or 0) :: number) + 35)
	elseif kind == "Speed" then
		world:Set(playerId, Slow, 0)
	elseif kind == "Damage" then
		spawnProjectile("BeamPulse", playerId, "Player", playerPos, Vector3.new(rand(-1, 1), 0, rand(-1, 1)))
	end

	commands:Add(entity, Dead)
end, {
	Name = "PickupSystem",
	Phase = "Update",
	Priority = 18,
})

local function tickStatus(component: any, dt: number, fn: ((number, number) -> ())?)
	for _, entity in ipairs(world:Query(component):Without(Dead):Cached():Run()) do
		local time = (world:Get(entity, component) :: number) - dt
		if fn then
			fn(entity, dt)
		end
		if time <= 0 then
			world:Remove(entity, component)
		else
			world:Set(entity, component, time)
		end
	end
end

world:System(world:Query(Player):Cached(), function(_entity, _playerTag, dt)
	tickStatus(Burn, dt, function(target, step)
		applyDamage(target, 5 * step)
	end)
	tickStatus(Poison, dt, function(target, step)
		applyDamage(target, 3 * step)
	end)
	tickStatus(Slow, dt, nil)
	tickStatus(Stun, dt, nil)
end, {
	Name = "StatusEffectSystem",
	Phase = "Update",
	Priority = 13,
})

world:System(world:Query(Health):Without(Dead):Cached(), function(entity, hp, _dt, commands)
	if hp <= 0 then
		if world:Has(entity, Splitter) then
			local pos = world:Get(entity, Position) :: Vector3
			spawnEnemy("Chaser", pos + Vector3.new(4, 0, 0))
			spawnEnemy("Chaser", pos + Vector3.new(-4, 0, 0))
		elseif world:Has(entity, Exploder) then
			local pos = world:Get(entity, Position) :: Vector3
			for _, target in ipairs(world:Query(Position, Health):Without(Dead):Cached():Run()) do
				if target ~= entity and ((world:Get(target, Position) :: Vector3) - pos).Magnitude < 15 then
					applyDamage(target, 20, "Burn")
				end
			end
		end
		commands:Add(entity, Dead)
	end
end, {
	Name = "StatusHealthSystem",
	Phase = "Update",
	Priority = 12,
})

world:System(world:Query(Lifetime):Without(Dead):Cached(), function(entity, life, dt, commands)
	life -= dt
	if life <= 0 then
		commands:Add(entity, Dead)
	else
		world:Set(entity, Lifetime, life)
	end
end, {
	Name = "LifetimeSystem",
	Phase = "Update",
	Priority = 8,
})

world:System(world:Query(Position, Render):Without(Dead):Cached(), function(entity, pos, render)
	local part = render.Part
	if part and part.Parent then
		part.Position = pos
		part:SetAttribute("ECSEntity", entity)
	end

	local hp = if world:Has(entity, Health) then world:Get(entity, Health) :: number else nil
	local maxHp = if world:Has(entity, MaxHealth) then world:Get(entity, MaxHealth) :: number else nil
	if hp and maxHp and render.Bar then
		local ratio = math.clamp(hp / math.max(maxHp, 1), 0, 1)
		render.Bar.Size = UDim2.fromScale(ratio, 1)
		render.Bar.BackgroundColor3 = if ratio > 0.5 then Color3.fromRGB(110, 230, 130) elseif ratio > 0.25 then Color3.fromRGB(245, 205, 85) else Color3.fromRGB(235, 85, 85)
		render.Label.Text = string.format("%.0f/%.0f", hp, maxHp)
	elseif render.Billboard then
		render.Billboard.Enabled = false
	end

	local vel = if world:Has(entity, Velocity) then world:Get(entity, Velocity) :: Vector3 else Vector3.zero
	local arrow = render.Arrow
	if arrow and arrow.Parent then
		local mag = vel.Magnitude
		if mag > 0.5 then
			local dir = vel.Unit
			local length = math.clamp(mag * 0.18, 2, 9)
			arrow.Size = Vector3.new(0.14, 0.14, length)
			arrow.CFrame = CFrame.lookAt(pos + Vector3.new(0, 2.4, 0), pos + Vector3.new(0, 2.4, 0) + dir) * CFrame.new(0, 0, -length / 2)
			arrow.Transparency = 0.25
		else
			arrow.Transparency = 1
		end
	end
end, {
	Name = "RenderOverlaySystem",
	Phase = "PostUpdate",
	Priority = 30,
})

world:System(world:Query(Dead):Cached(), function(entity, _deadTag, _dt, commands)
	if world:Has(entity, Render) then
		destroyRender(world:Get(entity, Render))
	end
	for child in world:Children(entity) do
		if world:IsAlive(child) then
			commands:Despawn(child)
		end
	end
	commands:Despawn(entity)
end, {
	Name = "CleanupSystem",
	Phase = "PostUpdate",
	Priority = 0,
	After = { "RenderOverlaySystem" },
})

world:OnAdd(Dead, function(entity)
	if world:Has(entity, Enemy) then
		world:SetResource("Score", (world:GetResource("Score") :: number) + 1)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	world:Update(dt)
end)

print("bsECS example online.")
