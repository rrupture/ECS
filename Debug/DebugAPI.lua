--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugAPI = {}
DebugAPI.__index = DebugAPI

local function stringValue(name: string): StringValue
	local found = ReplicatedStorage:FindFirstChild(name)
	if found and found:IsA("StringValue") then
		return found
	end

	local value = Instance.new("StringValue")
	value.Name = name
	value.Parent = ReplicatedStorage
	return value
end

local function formatValue(value: unknown): string
	local kind = typeof(value)

	if kind == "Vector3" then
		local v = value :: Vector3
		return string.format("%.2f, %.2f, %.2f", v.X, v.Y, v.Z)
	elseif kind == "Color3" then
		local v = value :: Color3
		return string.format("%.2f, %.2f, %.2f", v.R, v.G, v.B)
	elseif kind == "CFrame" then
		local p = (value :: CFrame).Position
		return string.format("CFrame %.2f, %.2f, %.2f", p.X, p.Y, p.Z)
	elseif kind == "number" then
		return string.format("%.3f", value :: number)
	elseif kind == "table" then
		local parts = {}
		for k, v in pairs(value :: any) do
			parts[#parts + 1] = tostring(k) .. "=" .. formatValue(v)
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end

	return tostring(value)
end

local function parseVector3(text: string): Vector3?
	local nums = {}
	for n in string.gmatch(text, "[-+]?%d+%.?%d*") do
		nums[#nums + 1] = tonumber(n)
	end
	if #nums >= 3 then
		return Vector3.new(nums[1], nums[2], nums[3])
	end
	return nil
end

local function parseColor3(text: string): Color3?
	local nums = {}
	for n in string.gmatch(text, "[-+]?%d+%.?%d*") do
		nums[#nums + 1] = tonumber(n)
	end
	if #nums >= 3 then
		return Color3.new(nums[1], nums[2], nums[3])
	end
	return nil
end

local function parseValue(kind: string, text: string): (boolean, unknown)
	if kind == "number" then
		local n = tonumber(text)
		return n ~= nil, n
	elseif kind == "boolean" or kind == "tag" then
		local lower = string.lower(text)
		if lower == "true" or lower == "1" or lower == "yes" then
			return true, true
		elseif lower == "false" or lower == "0" or lower == "no" then
			return true, false
		end
		return false, nil
	elseif kind == "Vector3" then
		local v = parseVector3(text)
		return v ~= nil, v
	elseif kind == "Color3" then
		local v = parseColor3(text)
		return v ~= nil, v
	elseif kind == "string" then
		return true, text
	end

	return false, nil
end

function DebugAPI.new(world: any)
	return setmetatable({
		_world = world,
		_snapshot = nil :: any,
		_bridge = nil :: StringValue?,
		_queryIn = nil :: StringValue?,
		_queryOut = nil :: StringValue?,
		_editIn = nil :: StringValue?,
		_lastQuery = nil :: string?,
		_lastEdit = nil :: string?,
	}, DebugAPI)
end

function DebugAPI:_ensureBridge()
	if self._bridge then
		return
	end

	self._bridge = stringValue("ECSDebugBridge")
	self._queryIn = stringValue("ECSQueryInput")
	self._queryOut = stringValue("ECSQueryOutput")
	self._editIn = stringValue("ECSEditInput")
end

function DebugAPI:GetSnapshot(): any
	return self._snapshot
end

function DebugAPI:_answerQuery()
	local input = self._queryIn
	local output = self._queryOut
	if not input or not output then
		return
	end

	local text = input.Value
	if text == self._lastQuery then
		return
	end
	self._lastQuery = text

	local ok, result = pcall(function()
		return self._world:QueryText(text)
	end)

	output.Value = HttpService:JSONEncode(if ok then result else {
		error = tostring(result),
		count = 0,
		entities = {},
	})
end

function DebugAPI:_applyEdit()
	local input = self._editIn
	if not input or input.Value == "" or input.Value == self._lastEdit then
		return
	end
	self._lastEdit = input.Value

	local ok, edit = pcall(HttpService.JSONDecode, HttpService, input.Value)
	if not ok or typeof(edit) ~= "table" then
		return
	end

	local world = self._world
	local entity = tonumber(edit.entity)
	local component = tostring(edit.component)
	local store = world.stores[component]
	if not entity or not store or not world:IsAlive(entity) then
		return
	end

	local current = store:Get(entity)
	local kind = if store.isTag then "tag" else typeof(current)
	local parsed, value = parseValue(kind, tostring(edit.value))
	if not parsed then
		return
	end

	if kind == "tag" and value == false then
		world:Remove(entity, component)
	else
		world:Set(entity, component, value)
	end
end

function DebugAPI:Capture()
	self:_ensureBridge()
	self:_answerQuery()
	self:_applyEdit()

	local world = self._world
	local snap = {
		name = "bsECS",
		entityCount = world.entities:Count(),
		systemCount = world._sc:Count(),
		components = {},
		memory = {},
		systemTimings = world._sc:GetTimings(),
		systemOrder = world._sc:GetOrder(),
		entities = {},
	}

	for name, store in pairs(world.stores) do
		local count = store:Count()
		if not world._pairMeta[name] then
			snap.components[name] = count
			snap.memory[name] = count * 64
		end
	end

	for id in world.entities:All() do
		local components = {}
		local types = {}
		local editable = {}
		local relationships = {}
		local names = {}

		for name, store in pairs(world.stores) do
			if store:Has(id) then
				local value = store:Get(id)
				local meta = world._pairMeta[name]
				if meta then
					relationships[#relationships + 1] = meta.relation .. " -> " .. meta.targetKey
				else
					components[name] = formatValue(value)
					types[name] = if store.isTag then "tag" else typeof(value)
					editable[name] = not store.isTag and typeof(value) ~= "table" and typeof(value) ~= "CFrame"
					names[#names + 1] = name
				end
			end
		end

		table.sort(names)
		table.sort(relationships)
		snap.entities[tostring(id)] = {
			id = id,
			label = components.Name or ("Entity #" .. tostring(id)),
			signature = table.concat(names, "  "),
			components = components,
			types = types,
			editable = editable,
			relationships = relationships,
			parent = world:Parent(id),
		}
	end

	self._snapshot = snap
	if self._bridge then
		self._bridge.Value = HttpService:JSONEncode(snap)
	end
end

return DebugAPI
