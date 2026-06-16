--!strict

export type Handler = (world: any, ...unknown) -> unknown

export type Catalog = {
	Name: string,
	Register: (self: Catalog, key: string, handler: Handler) -> Catalog,
	RegisterAll: (self: Catalog, entries: { [string]: Handler }) -> Catalog,
	Has: (self: Catalog, key: string) -> boolean,
	Run: (self: Catalog, key: string, world: any, ...unknown) -> unknown,
	Keys: (self: Catalog) -> { string },
}

local Catalog = {}
Catalog.__index = Catalog

function Catalog.new(name: string, entries: { [string]: Handler }?): Catalog
	local self = setmetatable({
		Name = name,
		_entries = {} :: { [string]: Handler },
	}, Catalog)

	if entries then
		self:RegisterAll(entries)
	end

	return self :: any
end

function Catalog:Register(key: string, handler: Handler): Catalog
	assert(key ~= "", "Catalog: empty key")
	assert(typeof(handler) == "function", "Catalog: handler must be a function")
	self._entries[key] = handler
	return self :: any
end

function Catalog:RegisterAll(entries: { [string]: Handler }): Catalog
	for key, handler in pairs(entries) do
		self:Register(key, handler)
	end
	return self :: any
end

function Catalog:Has(key: string): boolean
	return self._entries[key] ~= nil
end

function Catalog:Run(key: string, world: any, ...: unknown): unknown
	local handler = self._entries[key]
	assert(handler, ("Catalog %s: unknown key %s"):format(self.Name, key))
	return handler(world, ...)
end

function Catalog:Keys(): { string }
	local keys = {}
	for key in pairs(self._entries) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

return Catalog
