--!strict

local ComponentStore = {}
ComponentStore.__index = ComponentStore

function ComponentStore.new(name: string, isTag: boolean?)
	return setmetatable({
		name = name,
		isTag = isTag == true,
		_sparse = {} :: { [number]: number },
		_dense = {} :: { number },
		_data = {} :: { unknown },
		_changed = {} :: { [number]: true },
		_size = 0,
	}, ComponentStore)
end

function ComponentStore:Set(id: number, value: unknown)
	local index = self._sparse[id]
	if index then
		self._data[index] = value
		self._changed[id] = true
		return
	end

	local nextIndex = self._size + 1
	self._size = nextIndex
	self._sparse[id] = nextIndex
	self._dense[nextIndex] = id
	self._data[nextIndex] = value
end

function ComponentStore:Get(id: number): unknown
	local index = self._sparse[id]
	return if index then self._data[index] else nil
end

function ComponentStore:Has(id: number): boolean
	return self._sparse[id] ~= nil
end

function ComponentStore:Remove(id: number)
	local index = self._sparse[id]
	if not index then
		return
	end

	local tail = self._size
	local tailId = self._dense[tail]

	self._dense[index] = tailId
	self._data[index] = self._data[tail]
	self._sparse[tailId] = index

	self._dense[tail] = nil
	self._data[tail] = nil
	self._sparse[id] = nil
	self._changed[id] = nil
	self._size = tail - 1
end

function ComponentStore:Count(): number
	return self._size
end

function ComponentStore:RawDense(): { number }
	return self._dense
end

function ComponentStore:Changed(id: number): boolean
	return self._changed[id] == true
end

function ComponentStore:FlushChanges()
	table.clear(self._changed)
end

function ComponentStore:Each()
	local i = 0
	local dense = self._dense
	local data = self._data

	return function()
		i += 1
		local id = dense[i]
		if id then
			return id, data[i]
		end
	end
end

function ComponentStore:Snapshot(): any
	local out = {}
	for i = 1, self._size do
		out[self._dense[i]] = self._data[i]
	end
	return out
end

function ComponentStore:Restore(data: any)
	table.clear(self._sparse)
	table.clear(self._dense)
	table.clear(self._data)
	table.clear(self._changed)
	self._size = 0

	for id, value in pairs(data or {}) do
		local n = tonumber(id)
		if n then
			self:Set(n, value)
		end
	end

	table.clear(self._changed)
end

return ComponentStore
