--!strict

local Query = {}
Query.__index = Query

local QueryEngine = {}
QueryEngine.__index = QueryEngine

local function filter(kind: string, ...: any): any
	return { kind = kind, components = { ... } }
end

function QueryEngine.All(...: any): any
	return filter("all", ...)
end

function QueryEngine.Any(...: any): any
	return filter("any", ...)
end

function QueryEngine.None(...: any): any
	return filter("none", ...)
end

function QueryEngine.Changed(...: any): any
	return filter("changed", ...)
end

function QueryEngine.new()
	return setmetatable({
		_stores = {} :: { [string]: any },
	}, QueryEngine)
end

function QueryEngine:Register(name: string, store: any)
	self._stores[name] = store
end

function QueryEngine:Query(...: any): any
	return Query.new(self, { ... })
end

function Query.new(engine: any, filters: { any }): any
	return setmetatable({
		_engine = engine,
		_filters = filters,
		_compiled = nil,
		_cached = false,
		_fetch = nil,
	}, Query)
end

function Query:With(...: any): any
	self._filters[#self._filters + 1] = QueryEngine.All(...)
	self._compiled = nil
	return self
end

function Query:Any(...: any): any
	self._filters[#self._filters + 1] = QueryEngine.Any(...)
	self._compiled = nil
	return self
end

function Query:Without(...: any): any
	self._filters[#self._filters + 1] = QueryEngine.None(...)
	self._compiled = nil
	return self
end

function Query:Changed(...: any): any
	self._filters[#self._filters + 1] = QueryEngine.Changed(...)
	self._compiled = nil
	return self
end

function Query:Cached(): any
	self._cached = true
	self._compiled = self._compiled or self._engine:_compile(self._filters)
	self._fetch = self._compiled.fetch
	return self
end

function Query:Run(): { number }
	return self._engine:Run(self)
end

function Query:iter()
	return self._engine:Each(self)
end

function Query:__iter()
	return self:iter()
end

local function nameOf(component: any): string
	if typeof(component) == "table" then
		return component.name
	end
	return component
end

local function normalize(names: { any }): { string }
	local out = table.create(#names)
	for i = 1, #names do
		out[i] = nameOf(names[i])
	end
	return out
end

local function bind(stores: any, names: { any }): { any }
	local out = table.create(#names)
	for i = 1, #names do
		local name = nameOf(names[i])
		local store = stores[name]
		assert(store, "QueryEngine: unknown component " .. name)
		out[i] = store
	end
	return out
end

function QueryEngine:_compile(filters: { any }): any
	local stores = self._stores
	local checks = {}
	local seed = nil
	local seedSize = math.huge
	local anyStores = {}
	local fetch = nil

	for _, f in ipairs(filters) do
		local kind = f.kind
		local names = normalize(f.components)
		local bound = bind(stores, names)

		if kind == "all" then
			fetch = fetch or names
			for _, store in ipairs(bound) do
				local n = store:Count()
				if n < seedSize then
					seed = store
					seedSize = n
				end
			end
			checks[#checks + 1] = function(id: number): boolean
				for i = 1, #bound do
					if not bound[i]:Has(id) then
						return false
					end
				end
				return true
			end
		elseif kind == "any" then
			for _, store in ipairs(bound) do
				anyStores[#anyStores + 1] = store
			end
			checks[#checks + 1] = function(id: number): boolean
				for i = 1, #bound do
					if bound[i]:Has(id) then
						return true
					end
				end
				return false
			end
		elseif kind == "none" then
			checks[#checks + 1] = function(id: number): boolean
				for i = 1, #bound do
					if bound[i]:Has(id) then
						return false
					end
				end
				return true
			end
		elseif kind == "changed" then
			checks[#checks + 1] = function(id: number): boolean
				for i = 1, #bound do
					if not bound[i]:Changed(id) then
						return false
					end
				end
				return true
			end
		else
			error("QueryEngine: bad filter " .. tostring(kind))
		end
	end

	local nChecks = #checks
	local function test(id: number): boolean
		for i = 1, nChecks do
			if not checks[i](id) then
				return false
			end
		end
		return true
	end

	return {
		seed = seed,
		any = anyStores,
		test = test,
		fetch = fetch or {},
	}
end

function QueryEngine:_compiled(query: any): any
	if query._compiled then
		return query._compiled
	end

	local compiled = self:_compile(query._filters)
	query._fetch = compiled.fetch
	if query._cached then
		query._compiled = compiled
	end
	return compiled
end

function QueryEngine:Run(query: any): { number }
	local compiled = if query._test then query else self:_compiled(query)
	local out = {}
	local n = 0
	local test = compiled.test or compiled._test
	local seed = compiled.seed or compiled._seed

	if seed then
		local dense = seed:RawDense()
		for i = 1, seed:Count() do
			local id = dense[i]
			if test(id) then
				n += 1
				out[n] = id
			end
		end
		return out
	end

	local any = compiled.any or compiled._any or {}
	if #any > 0 then
		local seen = {}
		for _, store in ipairs(any) do
			local dense = store:RawDense()
			for i = 1, store:Count() do
				local id = dense[i]
				if not seen[id] and test(id) then
					seen[id] = true
					n += 1
					out[n] = id
				end
			end
		end
	end

	return out
end

function QueryEngine:Each(query: any, ...: string)
	local names = { ... }
	local stores = self._stores
	local entities = self:Run(query)
	local index = 0

	return function()
		index += 1
		local id = entities[index]
		if not id then
			return nil
		end

		local values = table.create(#names + 1)
		values[1] = id
		for i = 1, #names do
			values[i + 1] = stores[names[i]]:Get(id)
		end
		return table.unpack(values)
	end
end

return QueryEngine
