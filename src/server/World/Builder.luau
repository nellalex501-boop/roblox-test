--!strict
-- Builds the whole lobby into Workspace.ColdWarLobby.
--
-- Runtime: LobbyServer builds it on start unless a baked copy exists.
-- Edit mode (bake it into the place so you can see/edit it in Studio):
--   require(game.ServerScriptService.LobbyServer.World.Builder).Build()
-- Blockout mode (layout iteration):
--   require(game.ServerScriptService.LobbyServer.World.Builder).Build({ Mode = "Blockout" })

local World = script.Parent
local Blockout = require(World.Blockout)
local Ground = require(World.Ground)
local Kit = require(World.Kit)
local LightingSetup = require(World.LightingSetup)
local Perimeter = require(World.Perimeter)
local Zones = World.Zones
local CommandHQ = require(Zones.CommandHQ)
local EventArea = require(Zones.EventArea)
local Garage = require(Zones.Garage)
local Leaderboards = require(Zones.Leaderboards)
local MapRoom = require(Zones.MapRoom)
local MissionBoard = require(Zones.MissionBoard)
local OperationsCenter = require(Zones.OperationsCenter)
local Plaza = require(Zones.Plaza)
local SocialArea = require(Zones.SocialArea)

export type Mode = "Full" | "Blockout"

export type Options = {
	Mode: Mode?,
	Parent: Instance?,
	SkipLighting: boolean?,
}

local Builder = {}

Builder.RootName = "ColdWarLobby"
Builder.Version = 2

local ZONE_BUILDERS: { [string]: (Instance) -> (Model, CFrame) } = {
	OperationsCenter = OperationsCenter.build,
	MapRoom = MapRoom.build,
	CommandHQ = CommandHQ.build,
	Garage = Garage.build,
	Leaderboards = Leaderboards.build,
	EventArea = EventArea.build,
	MissionBoard = MissionBoard.build,
	SocialArea = SocialArea.build,
}

local function buildFull(root: Model)
	Ground.build(root, true)
	Ground.markings(root)
	Plaza.build(root)
	local zones = Kit.folder(root, "Zones")
	for zoneId, build in ZONE_BUILDERS do
		local model, frame = build(zones)
		Blockout.placePoints(model, frame, zoneId)
	end
	Perimeter.build(root)
end

function Builder.Build(options: Options?): Model
	local opts: Options = options or {}
	local mode: Mode = opts.Mode or "Full"
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

	if mode == "Blockout" then
		Ground.build(root, false)
		Blockout.build(root)
	else
		buildFull(root)
		if not opts.SkipLighting then
			LightingSetup.apply()
		end
	end

	root.Parent = parent
	return root
end

return Builder
