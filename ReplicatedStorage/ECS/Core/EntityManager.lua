--!strict

local EntityManager = {}
EntityManager.__index = EntityManager

local floor = math.floor
local MAX_INDEX = 2 ^ 20
local MAX_GENERATION = 2 ^ 12

local function pack(index: number, generation: number): number
	return index + generation * MAX_INDEX
end

local function unpack(id: number): (number, number)
	return id % MAX_INDEX, floor(id / MAX_INDEX) % MAX_GENERATION
end

function EntityManager.new()
	return setmetatable({
		_generations = {} :: { [number]: number },
		_free = {} :: { number },
		_freeCount = 0,
		_alive = {} :: { [number]: true },
		_count = 0,
		_next = 1,
	}, EntityManager)
end

function EntityManager:Spawn(): number
	local index: number
	local generation: number

	if self._freeCount > 0 then
		index = self._free[self._freeCount]
		self._free[self._freeCount] = nil
		self._freeCount -= 1
		generation = self._generations[index]
	else
		index = self._next
		assert(index <= MAX_INDEX, "EntityManager: entity limit reached")
		self._next += 1
		generation = 0
		self._generations[index] = generation
	end

	local id = pack(index, generation)
	self._alive[id] = true
	self._count += 1
	return id
end

function EntityManager:Despawn(id: number)
	assert(self._alive[id], "EntityManager: dead entity")

	local index, generation = unpack(id)
	self._generations[index] = (generation + 1) % MAX_GENERATION
	self._alive[id] = nil
	self._count -= 1

	self._freeCount += 1
	self._free[self._freeCount] = index
end

function EntityManager:IsAlive(id: number): boolean
	return self._alive[id] == true
end

function EntityManager:Count(): number
	return self._count
end

function EntityManager:All()
	return pairs(self._alive)
end

function EntityManager:Snapshot(): any
	local generations = {}
	local free = {}
	local alive = {}

	for index, generation in pairs(self._generations) do
		generations[index] = generation
	end
	for i = 1, self._freeCount do
		free[i] = self._free[i]
	end
	for id in pairs(self._alive) do
		alive[id] = true
	end

	return {
		generations = generations,
		free = free,
		freeCount = self._freeCount,
		alive = alive,
		count = self._count,
		next = self._next,
	}
end

function EntityManager:Restore(snapshot: any)
	table.clear(self._generations)
	table.clear(self._free)
	table.clear(self._alive)

	for index, generation in pairs(snapshot.generations or {}) do
		local n = tonumber(index)
		if n then
			self._generations[n] = generation
		end
	end
	for i = 1, snapshot.freeCount or 0 do
		self._free[i] = snapshot.free[i]
	end
	for id in pairs(snapshot.alive or {}) do
		local n = tonumber(id)
		if n then
			self._alive[n] = true
		end
	end

	self._freeCount = snapshot.freeCount or 0
	self._count = snapshot.count or 0
	self._next = snapshot.next or 1
end

return EntityManager