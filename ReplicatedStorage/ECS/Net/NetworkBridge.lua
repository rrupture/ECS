--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type ActionContext = {
	player: Player,
	entity: number?,
	payload: unknown,
	commands: any,
	world: any,
}

export type ServerAction = (context: ActionContext) -> ()
export type ClientHandler = (entity: number?, payload: unknown) -> ()

export type NetworkBridge = {
	BindAction: (self: NetworkBridge, name: string, handler: ServerAction) -> RBXScriptConnection,
	BindCatalog: (self: NetworkBridge, catalogName: string) -> RBXScriptConnection,
	SendAction: (self: NetworkBridge, name: string, entity: number?, payload: unknown?) -> (),
	FireClient: (self: NetworkBridge, player: Player, name: string, entity: number?, payload: unknown?) -> (),
	Broadcast: (self: NetworkBridge, name: string, entity: number?, payload: unknown?) -> (),
	OnClientEvent: (self: NetworkBridge, name: string, handler: ClientHandler) -> RBXScriptConnection,
}

local REMOTE_ACTION = "Action"
local REMOTE_STATE = "State"

local NetworkBridge = {}
NetworkBridge.__index = NetworkBridge

local function getFolder(name: string): Folder
	local folder = ReplicatedStorage:FindFirstChild(name)
	if folder then
		return folder :: Folder
	end

	if RunService:IsClient() then
		return ReplicatedStorage:WaitForChild(name) :: Folder
	end

	assert(RunService:IsServer(), "NetworkBridge: server must create remotes before clients bind")

	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = ReplicatedStorage
	return created
end

local function getRemote(folder: Folder, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if remote then
		return remote :: RemoteEvent
	end

	if RunService:IsClient() then
		return folder:WaitForChild(name) :: RemoteEvent
	end

	assert(RunService:IsServer(), "NetworkBridge: server must create remote " .. name)

	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

local function isSafeEntity(world: any?, entity: unknown): boolean
	return entity == nil or (typeof(entity) == "number" and (world == nil or world:IsAlive(entity :: number)))
end

function NetworkBridge.new(world: any?, options: { FolderName: string? }?): NetworkBridge
	local folder = getFolder(options and options.FolderName or "ECSNetwork")

	return setmetatable({
		_world = world,
		_action = getRemote(folder, REMOTE_ACTION),
		_state = getRemote(folder, REMOTE_STATE),
	}, NetworkBridge) :: any
end

function NetworkBridge:BindAction(name: string, handler: ServerAction): RBXScriptConnection
	assert(RunService:IsServer(), "NetworkBridge: BindAction is server-only")
	assert(self._world ~= nil, "NetworkBridge: BindAction requires a server world")
	assert(name ~= "", "NetworkBridge: empty action")

	return self._action.OnServerEvent:Connect(function(player: Player, actionName: unknown, entity: unknown, payload: unknown)
		if actionName ~= name then
			return
		end
		if not isSafeEntity(self._world, entity) then
			return
		end

		handler({
			player = player,
			entity = entity :: number?,
			payload = payload,
			commands = self._world:Commands(),
			world = self._world,
		})
	end)
end

function NetworkBridge:BindCatalog(catalogName: string): RBXScriptConnection
	assert(RunService:IsServer(), "NetworkBridge: BindCatalog is server-only")
	assert(self._world ~= nil, "NetworkBridge: BindCatalog requires a server world")
	assert(catalogName ~= "", "NetworkBridge: empty catalog")

	return self._action.OnServerEvent:Connect(function(player: Player, actionName: unknown, entity: unknown, payload: unknown)
		if typeof(actionName) ~= "string" then
			return
		end
		if not isSafeEntity(self._world, entity) then
			return
		end
		if not self._world:CanDispatch(catalogName, actionName) then
			return
		end

		self._world:Dispatch(catalogName, actionName, {
			player = player,
			entity = entity :: number?,
			payload = payload,
			commands = self._world:Commands(),
			world = self._world,
		})
	end)
end

function NetworkBridge:SendAction(name: string, entity: number?, payload: unknown?)
	assert(RunService:IsClient(), "NetworkBridge: SendAction is client-only")
	self._action:FireServer(name, entity, payload)
end

function NetworkBridge:FireClient(player: Player, name: string, entity: number?, payload: unknown?)
	assert(RunService:IsServer(), "NetworkBridge: FireClient is server-only")
	self._state:FireClient(player, name, entity, payload)
end

function NetworkBridge:Broadcast(name: string, entity: number?, payload: unknown?)
	assert(RunService:IsServer(), "NetworkBridge: Broadcast is server-only")
	self._state:FireAllClients(name, entity, payload)
end

function NetworkBridge:OnClientEvent(name: string, handler: ClientHandler): RBXScriptConnection
	assert(RunService:IsClient(), "NetworkBridge: OnClientEvent is client-only")

	return self._state.OnClientEvent:Connect(function(eventName: unknown, entity: unknown, payload: unknown)
		if eventName == name and (entity == nil or typeof(entity) == "number") then
			handler(entity :: number?, payload)
		end
	end)
end

return NetworkBridge
