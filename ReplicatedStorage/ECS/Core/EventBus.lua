--!strict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type Listener = {
	callback: (...unknown) -> (),
	connected: boolean,
}

type EventPacket = {
	n: number,
	[string | number]: unknown,
}

local EventBus = {}
EventBus.__index = EventBus

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	self._listener.connected = false
end

function EventBus.new()
	return setmetatable({
		_events = {} :: { [string]: { Listener } },
		_added = {} :: { [string]: { Listener } },
		_changed = {} :: { [string]: { Listener } },
		_removed = {} :: { [string]: { Listener } },
		_queue = {} :: { [string]: { EventPacket } },
	}, EventBus)
end

local function connect(bucketMap: { [string]: { Listener } }, key: string, fn: (...unknown) -> ()): Connection
	local bucket = bucketMap[key]
	if not bucket then
		bucket = {}
		bucketMap[key] = bucket
	end

	local listener = {
		callback = fn,
		connected = true,
	}
	bucket[#bucket + 1] = listener

	return setmetatable({
		Connected = true,
		_listener = listener,
	}, Connection) :: any
end

local function fire(bucketMap: { [string]: { Listener } }, key: string, ...: unknown)
	local bucket = bucketMap[key]
	if not bucket then
		return
	end

	local write = 1
	for read = 1, #bucket do
		local listener = bucket[read]
		if listener.connected then
			bucket[write] = listener
			write += 1
			listener.callback(...)
		end
	end

	for i = write, #bucket do
		bucket[i] = nil
	end
end

function EventBus:On(name: string, fn: (...unknown) -> ()): Connection
	return connect(self._events, name, fn)
end

function EventBus:Once(name: string, fn: (...unknown) -> ()): Connection
	local connection: Connection?
	connection = self:On(name, function(...: unknown)
		(connection :: Connection):Disconnect()
		fn(...)
	end)
	return connection
end

function EventBus:Emit(name: string, ...: unknown)
	fire(self._events, name, ...)
end

function EventBus:Queue(name: string, ...: unknown)
	local bucket = self._queue[name]
	if not bucket then
		bucket = {}
		self._queue[name] = bucket
	end

	local argc = select("#", ...)
	local packet = table.create(argc)
	packet.n = argc
	for i = 1, argc do
		packet[i] = select(i, ...)
	end
	bucket[#bucket + 1] = packet
end

function EventBus:Drain(name: string): { EventPacket }
	local bucket = self._queue[name]
	if not bucket or #bucket == 0 then
		return {}
	end

	self._queue[name] = {}
	return bucket
end

function EventBus:Pending(name: string): number
	local bucket = self._queue[name]
	return if bucket then #bucket else 0
end

function EventBus:OnAdded(name: string, fn: (number, unknown) -> ()): Connection
	return connect(self._added, name, fn :: any)
end

function EventBus:OnChanged(name: string, fn: (number, unknown, unknown) -> ()): Connection
	return connect(self._changed, name, fn :: any)
end

function EventBus:OnRemoved(name: string, fn: (number, unknown) -> ()): Connection
	return connect(self._removed, name, fn :: any)
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
