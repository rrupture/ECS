--!strict

local EntityManager = require(script.Parent.EntityManager)
local ComponentStore = require(script.Parent.ComponentStore)
local QueryEngine = require(script.Parent.QueryEngine)
local Scheduler = require(script.Parent.Scheduler)
local CommandBuffer = require(script.Parent.CommandBuffer)
local EventBus = require(script.Parent.EventBus)
local DebugAPI = require(script.Parent.Parent.Debug.DebugAPI)

local World = {}
World.__index = World

World.All = QueryEngine.All
World.Any = QueryEngine.Any
World.None = QueryEngine.None
World.Changed = QueryEngine.Changed
World.Wildcard = "*"

local INIT_KEY = {}
local META = {}

local function clone(value: unknown): unknown
	if typeof(value) ~= "table" then
		return value
	end

	local out = {}
	for k, v in pairs(value :: any) do
		out[k] = v
	end
	return out
end

local function valueOf(def: any, ...: any): unknown
	if def.isTag or def.isPair then
		return select("#", ...) > 0 and ... or true
	end

	local argc = select("#", ...)
	if argc == 0 then
		return clone(def.default)
	end
	if argc == 1 then
		return ...
	end

	local out = table.create(argc)
	for i = 1, argc do
		out[i] = select(i, ...)
	end
	return out
end

function META.__call(def: any, ...: any): any
	return {
		[INIT_KEY] = true,
		name = def.name,
		value = valueOf(def, ...),
	}
end

function META.__tostring(def: any): string
	return def.name
end

local function isInit(value: any): boolean
	return typeof(value) == "table" and rawget(value, INIT_KEY) == true
end

function World.new()
	local self = setmetatable({
		entities = EntityManager.new(),
		stores = {} :: { [string]: any },
		_defs = {} :: { [string]: any },
		_relations = {} :: { [string]: any },
		_pairMeta = {} :: { [string]: any },
		_pairs = {} :: { [string]: any },
		_entityPairs = {} :: { [number]: any },
		_parents = {} :: { [number]: number },
		_children = {} :: { [number]: { [number]: true } },
		_qe = QueryEngine.new(),
		_sc = Scheduler.new(),
		_events = EventBus.new(),
		_res = {} :: { [string]: unknown },
		_cmds = nil :: any,
		debug = nil :: any,
		ChildOf = nil :: any,
	}, World)

	self._cmds = CommandBuffer.new(self)
	self.debug = DebugAPI.new(self)
	self.ChildOf = self:Relation("ChildOf", { Exclusive = true })
	return self
end

function World:_def(name: string, isTag: boolean, default: unknown?): any
	assert(self.stores[name] == nil, "World: component exists: " .. name)

	local def = setmetatable({
		name = name,
		isTag = isTag,
		isPair = false,
		default = default,
	}, META)

	local store = ComponentStore.new(name, isTag)
	self._defs[name] = def
	self.stores[name] = store
	self._qe:Register(name, store)
	return def
end

function World:Component(name: string, default: unknown?): any
	return self:_def(name, false, default)
end

function World:Tag(name: string): any
	return self:_def(name, true, true)
end

function World:Relation(name: string, options: any?): any
	local existing = self._relations[name]
	if existing then
		return existing
	end

	local relation = setmetatable({
		name = name,
		isRelation = true,
		exclusive = options and options.Exclusive == true or false,
	}, META)

	self._relations[name] = relation
	return relation
end

function World:_targetKey(target: any): string
	if target == World.Wildcard then
		return World.Wildcard
	end
	if typeof(target) == "table" then
		return target.name
	end
	return tostring(target)
end

function World:_relationName(relation: any): string
	if typeof(relation) == "table" then
		return relation.name
	end
	return tostring(relation)
end

function World:Pair(relation: any, target: any): any
	local relationName = self:_relationName(relation)
	local targetKey = self:_targetKey(target)
	local name = relationName .. "@" .. targetKey

	if targetKey == World.Wildcard then
		return setmetatable({
			name = name,
			isPair = true,
			isWildcard = true,
			relation = relationName,
			target = target,
			targetKey = targetKey,
		}, META)
	end

	local existing = self._pairs[name]
	if existing then
		return existing
	end

	local rel = self._relations[relationName] or self:Relation(relationName)
	local def = setmetatable({
		name = name,
		isTag = true,
		isPair = true,
		relation = relationName,
		target = target,
		targetKey = targetKey,
		exclusive = rel.exclusive == true,
		default = true,
	}, META)

	self._pairs[name] = def
	self._pairMeta[name] = def
	self._defs[name] = def
	self.stores[name] = ComponentStore.new(name, true)
	self._qe:Register(name, self.stores[name])
	return def
end

function World:_name(component: any): string
	if typeof(component) == "string" then
		assert(self.stores[component], "World: unknown component: " .. component)
		return component
	end

	local name = component.name
	assert(typeof(name) == "string", "World: invalid component")
	if component.isPair and component.isWildcard then
		return name
	end
	assert(self.stores[name], "World: unknown component: " .. name)
	return name
end

function World:_filter(f: any): any
	local names = {}
	for i = 1, #f.components do
		local component = f.components[i]
		if typeof(component) == "table" and component.isPair and component.isWildcard then
			for pairName, meta in pairs(self._pairMeta) do
				if meta.relation == component.relation then
					names[#names + 1] = pairName
				end
			end
		else
			names[#names + 1] = self:_name(component)
		end
	end

	return {
		kind = if f.kind == "all" and #names > 1 and typeof(f.components[1]) == "table" and f.components[1].isWildcard then "any" else f.kind,
		components = names,
	}
end

function World:IsAlive(id: number): boolean
	return self.entities:IsAlive(id)
end

function World:Spawn(...: any): number
	local id = self.entities:Spawn()
	local argc = select("#", ...)

	if argc == 1 then
		local first = select(1, ...)
		if typeof(first) == "table" and not isInit(first) and first[1] ~= nil then
			for _, init in ipairs(first) do
				self:Add(id, init)
			end
			return id
		end
	end

	for i = 1, argc do
		self:Add(id, select(i, ...))
	end

	return id
end

function World:Clear(id: number)
	assert(self.entities:IsAlive(id), "World: dead entity")

	local removed = {}
	for name, store in pairs(self.stores) do
		if store:Has(id) then
			removed[#removed + 1] = name
		end
	end

	for _, name in ipairs(removed) do
		self:Remove(id, name)
	end
end

function World:Despawn(id: number)
	assert(self.entities:IsAlive(id), "World: dead entity")

	for pairName, meta in pairs(self._pairMeta) do
		if tonumber(meta.targetKey) == id then
			local store = self.stores[pairName]
			local victims = {}
			for entity in store:Each() do
				victims[#victims + 1] = entity
			end
			for _, entity in ipairs(victims) do
				self:Remove(entity, pairName)
			end
		end
	end

	self:Clear(id)
	self.entities:Despawn(id)
end

function World:_trackPair(id: number, name: string)
	local meta = self._pairMeta[name]
	if not meta then
		return
	end

	if meta.exclusive then
		local bucket = self._entityPairs[id]
		if bucket and bucket[meta.relation] then
			local toRemove = {}
			for pairName in pairs(bucket[meta.relation]) do
				if pairName ~= name then
					toRemove[#toRemove + 1] = pairName
				end
			end
			for _, pairName in ipairs(toRemove) do
				self:Remove(id, pairName)
			end
		end
	end

	local byRelation = self._entityPairs[id]
	if not byRelation then
		byRelation = {}
		self._entityPairs[id] = byRelation
	end
	byRelation[meta.relation] = byRelation[meta.relation] or {}
	byRelation[meta.relation][name] = true

	if meta.relation == "ChildOf" then
		local parent = tonumber(meta.targetKey)
		if parent then
			self._parents[id] = parent
			self._children[parent] = self._children[parent] or {}
			self._children[parent][id] = true
		end
	end
end

function World:_untrackPair(id: number, name: string)
	local meta = self._pairMeta[name]
	if not meta then
		return
	end

	local byRelation = self._entityPairs[id]
	if byRelation and byRelation[meta.relation] then
		byRelation[meta.relation][name] = nil
	end

	if meta.relation == "ChildOf" then
		local parent = tonumber(meta.targetKey)
		if parent and self._children[parent] then
			self._children[parent][id] = nil
		end
		if self._parents[id] == parent then
			self._parents[id] = nil
		end
	end
end

function World:Add(id: number, componentOrInit: any, value: unknown?): unknown
	assert(self.entities:IsAlive(id), "World: dead entity")

	local name: string
	local data: unknown

	if isInit(componentOrInit) then
		name = componentOrInit.name
		data = componentOrInit.value
	elseif typeof(componentOrInit) == "table" and componentOrInit[1] ~= nil then
		name = self:_name(componentOrInit[1])
		data = if componentOrInit[2] ~= nil then componentOrInit[2] else true
	else
		name = self:_name(componentOrInit)
		local def = self._defs[name]
		data = if value ~= nil then value else valueOf(def)
	end

	local store = self.stores[name]
	local existed = store:Has(id)
	local previous = store:Get(id)
	store:Set(id, data)

	if existed then
		self._events:FireChanged(name, id, data, previous)
	else
		self:_trackPair(id, name)
		self._events:FireAdded(name, id, data)
	end

	return data
end

function World:Set(id: number, component: any, value: unknown)
	self:Add(id, component, value)
end

function World:Get(id: number, component: any): unknown
	return self.stores[self:_name(component)]:Get(id)
end

function World:Has(id: number, component: any): boolean
	return self.stores[self:_name(component)]:Has(id)
end

function World:Remove(id: number, component: any)
	local name = self:_name(component)
	local store = self.stores[name]
	if store:Has(id) then
		local value = store:Get(id)
		self:_untrackPair(id, name)
		store:Remove(id)
		self._events:FireRemoved(name, id, value)
	end
end

function World:SetParent(child: number, parent: number?)
	if self._parents[child] then
		self:Remove(child, self:Pair(self.ChildOf, self._parents[child]))
	end
	if parent then
		self:Add(child, self:Pair(self.ChildOf, parent))
	end
end

function World:Parent(child: number): number?
	return self._parents[child]
end

function World:Children(parent: number)
	local ids = {}
	for child in pairs(self._children[parent] or {}) do
		ids[#ids + 1] = child
	end
	table.sort(ids)

	local i = 0
	return function()
		i += 1
		return ids[i]
	end
end

function World:Target(entity: number, relation: any, nth: number?): any
	local relationName = self:_relationName(relation)
	local bucket = self._entityPairs[entity] and self._entityPairs[entity][relationName]
	if not bucket then
		return nil
	end

	local index = 0
	local wanted = nth or 0
	for pairName in pairs(bucket) do
		if index == wanted then
			return self._pairMeta[pairName].target
		end
		index += 1
	end
	return nil
end

function World:Query(...: any): any
	local argc = select("#", ...)
	local direct = argc > 0

	for i = 1, argc do
		local item = select(i, ...)
		if typeof(item) == "table" and (item.kind ~= nil or item[1] ~= nil) then
			direct = false
			break
		end
	end

	if direct then
		return self._qe:Query(self:_filter(World.All(...)))
	end

	local filters = table.create(argc)
	for i = 1, argc do
		local f = select(i, ...)
		if f.kind == nil then
			f = World.All(table.unpack(f))
		end
		filters[i] = self:_filter(f)
	end
	return self._qe:Query(table.unpack(filters))
end

function World:Each(query: any, ...: any)
	local names = table.create(select("#", ...))
	for i = 1, select("#", ...) do
		names[i] = self:_name(select(i, ...))
	end
	return self._qe:Each(query, table.unpack(names))
end

function World:System(spec: any, fn: (...any) -> (), options: any?)
	local query: any
	local fetch: { string }

	if spec._engine then
		query = spec:Cached()
		fetch = query._fetch
	elseif spec.kind then
		query = self:Query(spec):Cached()
		fetch = query._fetch
	else
		fetch = table.create(#spec)
		for i = 1, #spec do
			fetch[i] = self:_name(spec[i])
		end
		query = self:Query(World.All(table.unpack(fetch))):Cached()
	end

	local stores = table.create(#fetch)
	for i = 1, #fetch do
		stores[i] = self.stores[fetch[i]]
	end

	local qe = self._qe
	local commands = self._cmds
	local count = #stores

	local function run(dt: number)
		local entities = qe:Run(query)

		if count == 0 then
			for i = 1, #entities do
				fn(entities[i], dt, commands)
			end
		elseif count == 1 then
			local a = stores[1]
			for i = 1, #entities do
				local id = entities[i]
				fn(id, a:Get(id), dt, commands)
			end
		elseif count == 2 then
			local a, b = stores[1], stores[2]
			for i = 1, #entities do
				local id = entities[i]
				fn(id, a:Get(id), b:Get(id), dt, commands)
			end
		elseif count == 3 then
			local a, b, c = stores[1], stores[2], stores[3]
			for i = 1, #entities do
				local id = entities[i]
				fn(id, a:Get(id), b:Get(id), c:Get(id), dt, commands)
			end
		else
			local args = table.create(count + 3)
			for i = 1, #entities do
				local id = entities[i]
				args[1] = id
				for n = 1, count do
					args[n + 1] = stores[n]:Get(id)
				end
				args[count + 2] = dt
				args[count + 3] = commands
				fn(table.unpack(args, 1, count + 3))
			end
		end
	end

	self._sc:Add(run, options)
end

function World:Commands(): any
	return self._cmds
end

function World:SetResource(name: string, value: unknown)
	self._res[name] = value
end

function World:GetResource(name: string): unknown
	return self._res[name]
end

function World:On(name: string, fn: (...unknown) -> ())
	self._events:On(name, fn)
end

function World:Emit(name: string, ...: unknown)
	self._events:Emit(name, ...)
end

function World:OnAdd(component: any, fn: (number, unknown) -> ())
	self._events:OnAdded(self:_name(component), fn)
end

function World:OnChange(component: any, fn: (number, unknown, unknown) -> ())
	self._events:OnChanged(self:_name(component), fn)
end

function World:OnRemove(component: any, fn: (number, unknown) -> ())
	self._events:OnRemoved(self:_name(component), fn)
end

function World:OnComponentAdded(component: any, fn: (number, unknown) -> ())
	self:OnAdd(component, fn)
end

function World:OnComponentRemoved(component: any, fn: (number) -> ())
	self._events:OnRemoved(self:_name(component), function(id)
		fn(id)
	end)
end

function World:Snapshot(): any
	local stores = {}
	local resources = {}

	for name, store in pairs(self.stores) do
		stores[name] = store:Snapshot()
	end
	for key, value in pairs(self._res) do
		resources[key] = value
	end

	return {
		entities = self.entities:Snapshot(),
		stores = stores,
		resources = resources,
	}
end

function World:Restore(snapshot: any)
	self.entities:Restore(snapshot.entities)

	for name, store in pairs(self.stores) do
		store:Restore(snapshot.stores[name])
	end

	table.clear(self._res)
	for key, value in pairs(snapshot.resources or {}) do
		self._res[key] = value
	end
end

local function encode(value: unknown): any
	local kind = typeof(value)

	if kind == "Vector3" then
		local v = value :: Vector3
		return { t = "Vector3", x = v.X, y = v.Y, z = v.Z }
	elseif kind == "Color3" then
		local v = value :: Color3
		return { t = "Color3", r = v.R, g = v.G, b = v.B }
	elseif kind == "CFrame" then
		return { t = "CFrame", v = { (value :: CFrame):GetComponents() } }
	elseif kind == "table" then
		local out = {}
		for k, v in pairs(value :: any) do
			out[tostring(k)] = encode(v)
		end
		return { t = "table", v = out }
	elseif kind == "number" or kind == "string" or kind == "boolean" then
		return { t = kind, v = value }
	end

	return { t = "string", v = tostring(value) }
end

local function decode(data: any): unknown
	if data.t == "Vector3" then
		return Vector3.new(data.x, data.y, data.z)
	elseif data.t == "Color3" then
		return Color3.new(data.r, data.g, data.b)
	elseif data.t == "CFrame" then
		return CFrame.new(table.unpack(data.v))
	elseif data.t == "table" then
		local out = {}
		for k, v in pairs(data.v or {}) do
			out[k] = decode(v)
		end
		return out
	elseif data.t == "number" or data.t == "string" or data.t == "boolean" then
		return data.v
	end
	return nil
end

function World:Serialize(): string
	local HttpService = game:GetService("HttpService")
	local snapshot = self:Snapshot()
	local data = {
		entities = snapshot.entities,
		stores = {},
		resources = {},
	}

	for name, values in pairs(snapshot.stores) do
		local out = {}
		for id, value in pairs(values) do
			out[tostring(id)] = encode(value)
		end
		data.stores[name] = out
	end
	for key, value in pairs(snapshot.resources) do
		data.resources[key] = encode(value)
	end

	return HttpService:JSONEncode(data)
end

function World:Deserialize(text: string)
	local HttpService = game:GetService("HttpService")
	local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
	assert(ok, "World: invalid serialized data")

	local stores = {}
	for name, values in pairs(data.stores or {}) do
		local out = {}
		for id, value in pairs(values) do
			local n = tonumber(id)
			if n then
				out[n] = decode(value)
			end
		end
		stores[name] = out
	end

	local resources = {}
	for key, value in pairs(data.resources or {}) do
		resources[key] = decode(value)
	end

	self:Restore({
		entities = data.entities,
		stores = stores,
		resources = resources,
	})
end

function World:QueryText(text: string): any
	local all = {}
	local none = {}
	local filters = {}

	for token in string.gmatch(text, "[^,%s]+") do
		if string.sub(token, 1, 1) == "!" then
			none[#none + 1] = self:_name(string.sub(token, 2))
		elseif string.find(token, "|", 1, true) then
			local anySet = {}
			for part in string.gmatch(token, "[^|]+") do
				anySet[#anySet + 1] = self:_name(part)
			end
			filters[#filters + 1] = World.Any(table.unpack(anySet))
		else
			all[#all + 1] = self:_name(token)
		end
	end

	if #all > 0 then
		filters[#filters + 1] = World.All(table.unpack(all))
	end
	if #none > 0 then
		filters[#filters + 1] = World.None(table.unpack(none))
	end
	if #filters == 0 then
		return { count = self.entities:Count(), entities = self:_entityList() }
	end

	local entities = self._qe:Run(self:Query(table.unpack(filters)))
	return { count = #entities, entities = entities }
end

function World:_entityList(): { number }
	local out = {}
	for id in self.entities:All() do
		out[#out + 1] = id
	end
	table.sort(out)
	return out
end

function World:Update(dt: number)
	self._res.DeltaTime = dt
	self._sc:Update(dt)
	self._cmds:Flush()
	self.debug:Capture()

	for _, store in pairs(self.stores) do
		store:FlushChanges()
	end
end

return World
