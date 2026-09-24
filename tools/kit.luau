--!nocheck
-- Insert kit: the baked lobby split into one model file per service, for
-- adding it to an existing place in Studio (right-click the service in the
-- Explorer → Insert from File…). Written by tools/bake.luau and checked by
-- tests/specs/08_release.

local Kit = {}

Kit.Dir = "dist/InsertKit"

-- `into` is where the file goes: a service, then child names
Kit.Files = {
	{ file = "1_Workspace_ColdWarLobby.rbxm", into = "Workspace", name = "ColdWarLobby" },
	{ file = "2_ReplicatedStorage_Lobby.rbxm", into = "ReplicatedStorage", name = "Lobby" },
	{ file = "3_ServerScriptService_LobbyServer.rbxm", into = "ServerScriptService", name = "LobbyServer" },
	{
		file = "4_StarterPlayerScripts_LobbyClient.rbxm",
		into = "StarterPlayer.StarterPlayerScripts",
		name = "LobbyClient",
	},
	{ file = "5_ServerStorage_LobbyAssets.rbxm", into = "ServerStorage", name = "LobbyAssets" },
}

-- Resolves an `into` path in a DataModel (nil when a child is missing).
function Kit.resolve(game, path: string)
	local names = string.split(path, ".")
	local node = game:GetService(names[1])
	for i = 2, #names do
		node = node and node:FindFirstChild(names[i])
	end
	return node
end

return Kit
