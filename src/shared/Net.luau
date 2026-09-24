--!strict
-- Remote definitions. The server creates every remote at startup under
-- ReplicatedStorage.Lobby.Remotes; clients wait for them by name.

local RunService = game:GetService("RunService")

local Net = {}

Net.FolderName = "Remotes"

-- Client -> server request/response (RemoteFunction per service).
Net.Functions = {
	"Profile",
	"Matchmaking",
	"Missions",
	"Leaderboards",
	"Event",
	"Garage",
}

-- Server -> client pushes.
Net.Events = {
	"ProfileChanged",
	"MatchmakingChanged",
	"LeaderboardsChanged",
	"LobbyStatus",
	"Notify",
}

local function folder(): Instance
	local root = script.Parent
	assert(root, "Net must live inside the Lobby folder")
	if RunService:IsServer() then
		local existing = root:FindFirstChild(Net.FolderName)
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = Net.FolderName
		created.Parent = root
		return created
	end
	return root:WaitForChild(Net.FolderName)
end

-- Server only: create all remotes (idempotent).
function Net.setup(): Instance
	local remotes = folder()
	for _, name in Net.Functions do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = remotes
		end
	end
	for _, name in Net.Events do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end
	return remotes
end

function Net.fn(name: string): RemoteFunction
	local remote = folder():WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), name .. " is not a RemoteFunction")
	return remote
end

function Net.event(name: string): RemoteEvent
	local remote = folder():WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	return remote
end

return Net
