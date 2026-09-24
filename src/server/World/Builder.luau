--!strict
-- Builds the whole lobby into Workspace.ColdWarLobby.
--
-- Runtime: LobbyServer builds it on start unless a baked copy exists.
-- Edit mode (bake it into the place so you can see/edit it in Studio):
--   require(game.ServerScriptService.LobbyServer.World.Builder).Build()
-- Blockout mode (layout iteration):
--   require(game.ServerScriptService.LobbyServer.World.Builder).Build({ Mode = "Blockout" })

local Blockout = require(script.Parent.Blockout)
local Ground = require(script.Parent.Ground)

export type Mode = "Full" | "Blockout"

export type Options = {
	Mode: Mode?,
	Parent: Instance?,
}

local Builder = {}

Builder.RootName = "ColdWarLobby"
Builder.Version = 1

function Builder.Build(options: Options?): Model
	local opts: Options = options or {}
	local mode: Mode = opts.Mode or "Blockout"
	local parent = opts.Parent or workspace

	local previous = parent:FindFirstChild(Builder.RootName)
	if previous then
		previous:Destroy()
	end

	-- Build unparented, then parent once: one replication batch, no partial world.
	local root = Instance.new("Model")
	root.Name = Builder.RootName
	root:SetAttribute("LobbyVersion", Builder.Version)
	root:SetAttribute("BuildMode", mode)

	Ground.build(root, mode ~= "Blockout")
	Blockout.build(root)

	root.Parent = parent
	return root
end

return Builder
