--!strict

local CommandBuffer = {}
CommandBuffer.__index = CommandBuffer

function CommandBuffer.new(world: any)
	return setmetatable({
		_world = world,
		_queue = {},
	}, CommandBuffer)
end

function CommandBuffer:Spawn(...: any)
	self._queue[#self._queue + 1] = { op = "spawn", args = { ... } }
end

function CommandBuffer:Despawn(id: number)
	self._queue[#self._queue + 1] = { op = "despawn", id = id }
end

function CommandBuffer:Add(id: number, component: any, value: unknown?)
	self._queue[#self._queue + 1] = {
		op = "add",
		id = id,
		component = component,
		value = value,
	}
end

function CommandBuffer:Set(id: number, component: any, value: unknown)
	self._queue[#self._queue + 1] = {
		op = "set",
		id = id,
		component = component,
		value = value,
	}
end

function CommandBuffer:Remove(id: number, component: any)
	self._queue[#self._queue + 1] = {
		op = "remove",
		id = id,
		component = component,
	}
end

function CommandBuffer:Pending(): number
	return #self._queue
end

function CommandBuffer:Flush()
	local world = self._world
	local queue = self._queue

	for i = 1, #queue do
		local cmd = queue[i]
		local op = cmd.op

		if op == "spawn" then
			world:Spawn(table.unpack(cmd.args))
		elseif op == "despawn" then
			if world:IsAlive(cmd.id) then
				world:Despawn(cmd.id)
			end
		elseif op == "add" then
			if world:IsAlive(cmd.id) then
				world:Add(cmd.id, cmd.component, cmd.value)
			end
		elseif op == "set" then
			if world:IsAlive(cmd.id) then
				world:Set(cmd.id, cmd.component, cmd.value)
			end
		elseif op == "remove" then
			if world:IsAlive(cmd.id) then
				world:Remove(cmd.id, cmd.component)
			end
		end
	end

	table.clear(queue)
end

return CommandBuffer
