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
local Stations = World.Stations
local CommandHQStations = require(Stations.CommandHQ)
local EventAreaStations = require(Stations.EventArea)
local GarageStations = require(Stations.Garage)
local LeaderboardStations = require(Stations.Leaderboards)
local MapRoomStations = require(Stations.MapRoom)
local MissionBoardStations = require(Stations.MissionBoard)
local OperationsStations = require(Stations.Operations)
local PlazaStations = require(Stations.Plaza)

export type Mode = "Full" | "Blockout"

export type Options = {
	Mode: Mode?,
	Parent: Instance?,
	SkipLighting: boolean?,
	Now: number?, -- unix time used to pick the active event (default os.time())
}

local Builder = {}

Builder.RootName = "ColdWarLobby"
Builder.Version = 3

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

local STATION_BUILDERS: { [string]: (Instance, CFrame, number) -> () } = {
	OperationsCenter = OperationsStations.build,
	MapRoom = MapRoomStations.build,
	CommandHQ = CommandHQStations.build,
	Garage = GarageStations.build,
	Leaderboards = LeaderboardStations.build,
	EventArea = EventAreaStations.build,
	MissionBoard = MissionBoardStations.build,
}

local function buildFull(root: Model, now: number)
	Ground.build(root, true)
	Ground.markings(root)
	Plaza.build(root)
	local zones = Kit.folder(root, "Zones")
	for zoneId, build in ZONE_BUILDERS do
		local model, frame = build(zones)
		local stations = STATION_BUILDERS[zoneId]
		if stations then
			stations(model, frame, now)
		end
	end
	PlazaStations.build(root)
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
		buildFull(root, opts.Now or os.time())
		if not opts.SkipLighting then
			LightingSetup.apply()
		end
	end

	root.Parent = parent
	return root
end

return Builder
