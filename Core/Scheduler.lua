--!strict

local Scheduler = {}
Scheduler.__index = Scheduler

local PHASES = { "PreUpdate", "Update", "PostUpdate" }

function Scheduler.new()
	return setmetatable({
		_phases = {
			PreUpdate = {},
			Update = {},
			PostUpdate = {},
		} :: { [string]: { any } },
		_timings = {} :: { [string]: number },
	}, Scheduler)
end

function Scheduler:Add(run: (number) -> (), options: any?)
	options = options or {}

	local phase = options.Phase or "Update"
	assert(self._phases[phase], "Scheduler: unknown phase " .. tostring(phase))

	table.insert(self._phases[phase], {
		name = options.Name or "System",
		priority = options.Priority or 0,
		after = options.After or {},
		before = options.Before or {},
		run = run,
	})

	self:_sort(phase)
end

function Scheduler:Update(dt: number)
	local timings = self._timings
	for _, phase in ipairs(PHASES) do
		for _, system in ipairs(self._phases[phase]) do
			local t0 = os.clock()
			system.run(dt)
			timings[system.name] = (os.clock() - t0) * 1000
		end
	end
end

function Scheduler:Count(): number
	local n = 0
	for _, phase in ipairs(PHASES) do
		n += #self._phases[phase]
	end
	return n
end

function Scheduler:GetTimings(): { { name: string, ms: number } }
	local out = {}
	for name, ms in pairs(self._timings) do
		out[#out + 1] = { name = name, ms = ms }
	end
	table.sort(out, function(a, b)
		return a.ms > b.ms
	end)
	return out
end

function Scheduler:GetOrder(): { { phase: string, name: string, priority: number } }
	local out = {}
	for _, phase in ipairs(PHASES) do
		for _, system in ipairs(self._phases[phase]) do
			out[#out + 1] = {
				phase = phase,
				name = system.name,
				priority = system.priority,
			}
		end
	end
	return out
end

function Scheduler:_sort(phase: string)
	local list = self._phases[phase]
	local byName = {}
	local edges = {}
	local indegree = {}

	for _, system in ipairs(list) do
		byName[system.name] = system
		edges[system] = {}
		indegree[system] = 0
	end

	local function link(before: any, after: any)
		if not before or not after or before == after then
			return
		end
		local bucket = edges[before]
		if bucket[after] then
			return
		end
		bucket[after] = true
		indegree[after] += 1
	end

	for _, system in ipairs(list) do
		for _, dep in ipairs(system.after) do
			link(byName[dep], system)
		end
		for _, dep in ipairs(system.before) do
			link(system, byName[dep])
		end
	end

	local ready = {}
	for _, system in ipairs(list) do
		if indegree[system] == 0 then
			ready[#ready + 1] = system
		end
	end

	local out = {}
	while #ready > 0 do
		table.sort(ready, function(a, b)
			if a.priority == b.priority then
				return a.name < b.name
			end
			return a.priority > b.priority
		end)

		local system = table.remove(ready, 1)
		out[#out + 1] = system

		for nextSystem in pairs(edges[system]) do
			indegree[nextSystem] -= 1
			if indegree[nextSystem] == 0 then
				ready[#ready + 1] = nextSystem
			end
		end
	end

	assert(#out == #list, "Scheduler: dependency cycle in " .. phase)

	table.clear(list)
	for i = 1, #out do
		list[i] = out[i]
	end
end

return Scheduler
