--!strict

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
	return setmetatable({
		_events = {} :: { [string]: { (...unknown) -> () } },
		_added = {} :: { [string]: { (number, unknown) -> () } },
		_changed = {} :: { [string]: { (number, unknown, unknown) -> () } },
		_removed = {} :: { [string]: { (number, unknown) -> () } },
	}, EventBus)
end

local function push(bucketMap: any, key: string, fn: any)
	local bucket = bucketMap[key]
	if not bucket then
		bucket = {}
		bucketMap[key] = bucket
	end
	bucket[#bucket + 1] = fn
end

local function fire(bucketMap: any, key: string, ...: unknown)
	local bucket = bucketMap[key]
	if not bucket then
		return
	end
	for i = 1, #bucket do
		bucket[i](...)
	end
end

function EventBus:On(name: string, fn: (...unknown) -> ())
	push(self._events, name, fn)
end

function EventBus:Emit(name: string, ...: unknown)
	fire(self._events, name, ...)
end

function EventBus:OnAdded(name: string, fn: (number, unknown) -> ())
	push(self._added, name, fn)
end

function EventBus:OnChanged(name: string, fn: (number, unknown, unknown) -> ())
	push(self._changed, name, fn)
end

function EventBus:OnRemoved(name: string, fn: (number, unknown) -> ())
	push(self._removed, name, fn)
end

function EventBus:FireAdded(name: string, id: number, value: unknown)
	fire(self._added, name, id, value)
end

function EventBus:FireChanged(name: string, id: number, value: unknown, previous: unknown)
	fire(self._changed, name, id, value, previous)
end

function EventBus:FireRemoved(name: string, id: number, value: unknown)
	fire(self._removed, name, id, value)
end

return EventBus
