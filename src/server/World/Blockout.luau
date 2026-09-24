--!strict
-- PHASE 1 blockout: every zone from Layout as a plain massing volume with
-- its entrances cut out, plus placeholder interaction points at the planned
-- terminal positions. Used to validate navigation, scale, distances and
-- sightlines before any architecture exists. Kept as a build mode
-- (Builder.Build({ Mode = "Blockout" })) for future layout iteration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ground = require(script.Parent.Ground)
local Kit = require(script.Parent.Kit)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Blockout = {}

type Point = { Kind: string, Id: string, Pos: Vector3, Label: string }

local function p(kind: string, id: string, x: number, z: number, label: string): Point
	return { Kind = kind, Id = id, Pos = Vector3.new(x, 0, z), Label = label }
end

-- Planned interaction points (zone-local; -Z = into the zone).
Blockout.Points = {
	OperationsCenter = {
		p("Matchmaking", "PRIVATE", -26, -28, "PRIVATE"),
		p("Matchmaking", "1V1", -13, -24, "1v1"),
		p("Matchmaking", "QUICK", 0, -22, "QUICK"),
		p("Matchmaking", "2V2", 13, -24, "2v2"),
		p("Matchmaking", "4V4", 26, -28, "4v4"),
	},
	MapRoom = {
		p("MapInfo", "TRAIN_STATION", -23, -14, "TRAIN"),
		p("MapInfo", "CATHEDRAL", -23, -32, "CATHEDRAL"),
		p("MapInfo", "RIVER_CROSSING", -16, -45, "RIVER"),
		p("MapInfo", "INDUSTRIAL_HEART", 0, -45, "INDUSTRIAL"),
		p("MapInfo", "AIRBASE", 16, -45, "AIRBASE"),
		p("MapInfo", "DAM", 23, -32, "DAM"),
		p("MapInfo", "HIGHWAY", 23, -14, "HIGHWAY"),
	},
	CommandHQ = {
		p("Profile", "PROFILE", -10, -34, "PROFILE"),
		p("Statistics", "RECORDS", 12, -30, "RECORDS"),
		p("Customize", "LOCKERS", 14, -14, "LOCKERS"),
		p("Achievements", "TROPHIES", -14, -14, "TROPHIES"),
	},
	Garage = {
		p("UnitInspect", "M1_ABRAMS", -32, -9, "M1"),
		p("UnitInspect", "T72", -6, -9, "T-72"),
		p("UnitInspect", "M2_BRADLEY", 20, -9, "M2"),
		p("UnitInspect", "BMP2", -32, -33, "BMP-2"),
		p("UnitInspect", "BTR70", -6, -33, "BTR-70"),
		p("UnitInspect", "ZSU234", 20, -33, "ZSU"),
		p("UnitCollection", "REGISTRY", -30, -58, "REGISTRY"),
		p("UnitCosmetics", "PAINT", 30, -58, "PAINT"),
	},
	Leaderboards = {
		p("Leaderboard", "TOP_COMMANDERS", -28, -30, "TOP"),
		p("Leaderboard", "MOST_VICTORIES", -14, -30, "WINS"),
		p("Leaderboard", "MOST_MATCHES", 0, -30, "MATCHES"),
		p("Leaderboard", "MOST_TERRITORY", 14, -30, "TERRITORY"),
		p("Leaderboard", "CURRENT_SEASON", 28, -30, "SEASON"),
	},
	EventArea = {
		p("Event", "CURRENT", 0, -30, "EVENT"),
		p("UnitInspect", "T80BV_ZIMA", 16, -18, "ZIMA"),
	},
	MissionBoard = {
		p("Missions", "BOARD", 0, -2, "MISSIONS"),
	},
} :: { [string]: { Point } }

local ZONE_COLORS = {
	OperationsCenter = W.MutedBlue,
	MapRoom = W.BeigeDark,
	CommandHQ = W.Brick,
	Garage = W.Olive,
	Leaderboards = W.SteelDark,
	EventArea = W.Snow,
	MissionBoard = W.Cork,
	SocialArea = W.Wood,
}

local function label(parent: Instance, cf: CFrame, text: string, width: number)
	Kit.sign(parent, cf, Vector2.new(width, width * 0.22), text, { Background = W.Charcoal })
end

local function buildingVolume(parent: Instance, zone: Layout.Zone)
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local color = ZONE_COLORS[zone.Id] or W.Concrete
	local w, d, h = zone.Width, zone.Depth, zone.Height
	local floor = Ground.FloorTop

	Kit.box(
		model,
		frame,
		Vector3.new(-w / 2, 0, -d),
		Vector3.new(w / 2, floor, 0),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Floor" }
	)

	local openings = {}
	for _, entrance in zone.Entrances do
		table.insert(
			openings,
			{ Center = w / 2 + entrance.Offset, Width = entrance.Width, Bottom = 0, Top = entrance.Height }
		)
	end
	local t = 1
	Kit.wall(
		model,
		frame,
		Vector2.new(-w / 2, -t / 2),
		Vector2.new(w / 2, -t / 2),
		floor,
		h,
		t,
		color,
		Enum.Material.Concrete,
		openings
	)
	Kit.wall(
		model,
		frame,
		Vector2.new(-w / 2, -d + t / 2),
		Vector2.new(w / 2, -d + t / 2),
		floor,
		h,
		t,
		color,
		Enum.Material.Concrete
	)
	Kit.wall(
		model,
		frame,
		Vector2.new(-w / 2 + t / 2, -t),
		Vector2.new(-w / 2 + t / 2, -d + t),
		floor,
		h,
		t,
		color,
		Enum.Material.Concrete
	)
	Kit.wall(
		model,
		frame,
		Vector2.new(w / 2 - t / 2, -t),
		Vector2.new(w / 2 - t / 2, -d + t),
		floor,
		h,
		t,
		color,
		Enum.Material.Concrete
	)
	Kit.box(
		model,
		frame,
		Vector3.new(-w / 2, h, -d),
		Vector3.new(w / 2, h + 1, 0),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Roof" }
	)

	label(
		model,
		Kit.facingOut(frame, Vector3.new(0, math.min(h - 3, 16), 0.8)),
		zone.DisplayName,
		math.min(w * 0.6, 34)
	)
	return model, frame
end

local function openVolume(parent: Instance, zone: Layout.Zone)
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local color = ZONE_COLORS[zone.Id] or W.Concrete
	local w, d = zone.Width, zone.Depth
	Kit.box(
		model,
		frame,
		Vector3.new(-w / 2, 0, -d),
		Vector3.new(w / 2, Ground.PavedTop, 0),
		color,
		Enum.Material.SmoothPlastic,
		{
			Name = "Pad",
			Shadow = false,
		}
	)
	for _, corner in
		{ Vector3.new(-w / 2, 0, 0), Vector3.new(w / 2, 0, 0), Vector3.new(-w / 2, 0, -d), Vector3.new(w / 2, 0, -d) }
	do
		Kit.box(
			model,
			frame,
			corner + Vector3.new(-0.5, 0, -0.5),
			corner + Vector3.new(0.5, 6, 0.5),
			W.Charcoal,
			nil,
			{ Name = "Marker" }
		)
	end
	label(model, Kit.facingOut(frame, Vector3.new(0, 8, -d + 1)), zone.DisplayName, math.min(w * 0.5, 24))
	return model, frame
end

local function interactionPoint(parent: Instance, frame: CFrame, point: Point)
	local marker = Kit.part(
		parent,
		Vector3.new(1.4, 4, 1.4),
		frame * CFrame.new(point.Pos + Vector3.new(0, Ground.FloorTop + 2, 0)),
		W.HazardYellow,
		Enum.Material.SmoothPlastic,
		{ Name = "Point_" .. point.Kind .. "_" .. point.Id }
	)
	Interactions.attach(marker, point.Kind, point.Id, point.Label)
end

function Blockout.build(root: Instance)
	local zones = Kit.folder(root, "Zones")
	for _, zoneId in Layout.ZoneOrder do
		local zone = Layout.Zones[zoneId]
		local model, frame
		if zone.Kind == "Building" then
			model, frame = buildingVolume(zones, zone)
		else
			model, frame = openVolume(zones, zone)
		end
		local points: { Point } = Blockout.Points[zoneId] or {}
		for _, point in points do
			interactionPoint(model, frame, point)
		end
	end

	-- Central dais + theatre map block + spawn pads.
	local plaza = Kit.folder(root, "Plaza")
	local dais = Layout.Dais
	local height = dais.StepHeight * dais.Steps
	for step = 1, dais.Steps do
		Kit.post(
			plaza,
			CFrame.new(dais.Center + Vector3.new(0, Ground.PavedTop, 0)),
			dais.StepHeight * step,
			dais.Radius * 2 - (step - 1) * 4,
			W.ConcreteLight,
			Enum.Material.Concrete,
			{ Name = "DaisStep" .. step }
		)
	end
	local map = Kit.part(
		plaza,
		Vector3.new(30, 3, 20),
		CFrame.new(dais.Center + Vector3.new(0, Ground.PavedTop + height + 1.5, 0)),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{ Name = "TheaterMap" }
	)
	Interactions.attach(map, "TheaterMap", "THEATER", "THEATRE MAP")

	local spawns = Kit.folder(root, "Spawns")
	local spawnCfg = Layout.Spawn
	for i = 1, spawnCfg.Count do
		local offset = (i - (spawnCfg.Count + 1) / 2) * spawnCfg.Spacing
		local arc = (math.abs(offset) / (spawnCfg.Spacing * spawnCfg.Count / 2)) ^ 2 * spawnCfg.ArcDepth
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(4, 0.4, 4)
		spawn.CFrame = CFrame.new(spawnCfg.Center + Vector3.new(offset, Ground.PavedTop + 0.2, -arc))
		spawn.Color = W.HazardYellow
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = spawns
	end
end

return Blockout
