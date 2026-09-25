--!strict
-- PARADE SQUARE centrepiece: raised dais with the theatre map table, a
-- semicircle of flags (landmark silhouette), live status pylons, the
-- assembly point with the spawn pads, and direction signposts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Ground = require(World.Ground)
local Kit = require(World.Kit)
local Signage = require(World.Signage)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Plaza = {}

Plaza.TableSize = Vector2.new(30, 18)
Plaza.TableTopY = Ground.PavedTop + 1.2 + 2.9

function Plaza.tableFrame(): CFrame
	return CFrame.new(Layout.Dais.Center + Vector3.new(0, Plaza.TableTopY, 0))
end

local function dais(parent: Instance)
	local cfg = Layout.Dais
	local base = CFrame.new(cfg.Center + Vector3.new(0, Ground.PavedTop, 0))
	for step = 1, cfg.Steps do
		Kit.post(
			parent,
			base,
			cfg.StepHeight * step,
			cfg.Radius * 2 - (step - 1) * 4,
			if step == 1 then W.Concrete else W.ConcreteLight,
			Enum.Material.Concrete,
			{ Name = "DaisStep" .. step }
		)
	end
	-- dark granite ring inlay on the upper step, the light centre disc 0.06
	-- above it (each top 0.06 proud of the one below)
	Kit.post(
		parent,
		base * CFrame.new(0, cfg.StepHeight * cfg.Steps, 0),
		0.06,
		cfg.Radius * 2 - 6,
		W.DarkGrey,
		Enum.Material.Granite,
		{
			Name = "DaisInlay",
			Decor = true,
		}
	)
	Kit.post(
		parent,
		base * CFrame.new(0, cfg.StepHeight * cfg.Steps, 0),
		0.12,
		cfg.Radius * 2 - 7.6,
		W.ConcreteLight,
		Enum.Material.Concrete,
		{
			Name = "DaisCenter",
			Decor = true,
		}
	)
end

local function mapTable(parent: Instance)
	local model = Kit.model(parent, "TheaterMapTable")
	local top = Plaza.tableFrame()
	local size = Plaza.TableSize
	-- legs stand on the centre disc (0.12 above the top step)
	local daisTop = Ground.PavedTop + Layout.Dais.StepHeight * Layout.Dais.Steps + 0.12
	local legH = Plaza.TableTopY - 1.1 - daisTop
	for _, x in { -size.X / 2 + 1.2, 0, size.X / 2 - 1.2 } do
		for _, z in { -size.Y / 2 + 1.2, size.Y / 2 - 1.2 } do
			Kit.box(
				model,
				top,
				Vector3.new(x - 0.5, -1.1 - legH, z - 0.5),
				Vector3.new(x + 0.5, -1.1, z + 0.5),
				W.SteelDark,
				Enum.Material.Metal,
				{
					Name = "Leg",
				}
			)
		end
	end
	Kit.box(
		model,
		top,
		Vector3.new(-size.X / 2, -1.1, -size.Y / 2),
		Vector3.new(size.X / 2, -0.3, size.Y / 2),
		W.OliveDark,
		Enum.Material.Metal,
		{
			Name = "TableBody",
		}
	)
	local surface = Kit.box(
		model,
		top,
		Vector3.new(-size.X / 2 + 0.6, -0.3, -size.Y / 2 + 0.6),
		Vector3.new(size.X / 2 - 0.6, 0, size.Y / 2 - 0.6),
		Color3.fromRGB(26, 34, 32),
		Enum.Material.SmoothPlastic,
		{
			Name = "MapSurface",
		}
	)
	surface:SetAttribute("MapSurface", "Theater")
	-- rim: long sides take the corners, short sides fit between them
	for _, seg in
		{
			{ Vector3.new(-size.X / 2, -0.3, -size.Y / 2), Vector3.new(size.X / 2, 0.35, -size.Y / 2 + 0.6) },
			{ Vector3.new(-size.X / 2, -0.3, size.Y / 2 - 0.6), Vector3.new(size.X / 2, 0.35, size.Y / 2) },
			{
				Vector3.new(-size.X / 2, -0.3, -size.Y / 2 + 0.6),
				Vector3.new(-size.X / 2 + 0.6, 0.35, size.Y / 2 - 0.6),
			},
			{ Vector3.new(size.X / 2 - 0.6, -0.3, -size.Y / 2 + 0.6), Vector3.new(size.X / 2, 0.35, size.Y / 2 - 0.6) },
		}
	do
		Kit.box(model, top, seg[1], seg[2], W.Steel, Enum.Material.Metal, { Name = "Rim" })
	end
	return model
end

-- Two flag groups either side of the dais, clear of the central axis so
-- they never stand between the spawn and the Operations Center sign.
Plaza.FlagPlan = {
	{ Angle = 166, Height = 29, Design = "WestGermany" },
	{ Angle = 150, Height = 33, Design = "Usa" },
	{ Angle = 30, Height = 31, Design = "Nato" },
	{ Angle = 14, Height = 28, Design = "Cavalry" },
}

local function flags(parent: Instance)
	local folder = Kit.folder(parent, "Flags")
	local center = Layout.Dais.Center
	local radius = Layout.Dais.Radius + 1.8
	for _, f in Plaza.FlagPlan do
		local a = math.rad(f.Angle)
		local pos = center + Vector3.new(math.cos(a) * radius, Ground.PavedTop, -math.sin(a) * radius)
		-- flags stream toward the east (prevailing wind)
		Architecture.flagpole(folder, CFrame.new(pos), f.Height, Architecture.Flags[f.Design], 8)
	end
end

-- Board 12.4 x 7 studs with a screen on each face. The posts stand
-- outside the board (the screen text runs almost edge to edge) and hold it
-- with short brackets; a thin bezel frames each face.
local function statusPylon(parent: Instance, x: number)
	local model = Kit.model(parent, "StatusPylon")
	local c = Layout.Dais.Center
	local base = CFrame.new(x, Ground.PavedTop, c.Z)
	local half, bottom, top = 6.2, 5.6, 12.6
	Kit.box(
		model,
		base,
		Vector3.new(-7.7, 0, -1.3),
		Vector3.new(7.7, 0.6, 1.3),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Footing" }
	)
	for _, side in { -1, 1 } do
		Kit.box(
			model,
			base,
			Vector3.new(side * (half + 0.15), 0.6, -0.4),
			Vector3.new(side * (half + 0.95), top, 0.4),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Post" }
		)
		for _, y in { bottom + 0.6, top - 0.6 } do
			Kit.box(
				model,
				base,
				Vector3.new(side * (half - 0.1), y - 0.15, -0.15),
				Vector3.new(side * (half + 0.2), y + 0.15, 0.15),
				W.Steel,
				Enum.Material.Metal,
				{ Name = "Bracket" }
			)
		end
	end
	local board = Kit.box(
		model,
		base,
		Vector3.new(-half, bottom, -0.35),
		Vector3.new(half, top, 0.35),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{
			Name = "StatusBoard",
		}
	)
	board:SetAttribute("StatusBoard", true)
	-- bezel strips, 0.25 wide, in front of the screen margins
	for _, face in { -1, 1 } do
		local z0, z1 = face * 0.35, face * 0.43
		for _, strip in
			{
				{ Vector3.new(-half, top - 0.25, z0), Vector3.new(half, top, z1) },
				{ Vector3.new(-half, bottom, z0), Vector3.new(half, bottom + 0.25, z1) },
				{ Vector3.new(-half, bottom + 0.25, z0), Vector3.new(-half + 0.25, top - 0.25, z1) },
				{ Vector3.new(half - 0.25, bottom + 0.25, z0), Vector3.new(half, top - 0.25, z1) },
			}
		do
			Kit.box(model, base, strip[1], strip[2], W.SteelDark, Enum.Material.Metal, { Name = "Bezel" })
		end
	end
	Kit.box(
		model,
		base,
		Vector3.new(-(half + 1.1), top, -0.6),
		Vector3.new(half + 1.1, top + 0.5, 0.6),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "Cap" }
	)
	return model
end

local function assemblyPoint(root: Instance, parent: Instance)
	local cfg = Layout.Spawn
	local spawns = Kit.folder(root, "Spawns")
	local y = Ground.PavedTop
	-- painted outline around the pads
	local halfSpan = (cfg.Count / 2) * cfg.Spacing + 1
	local z0, z1 = cfg.Center.Z - cfg.ArcDepth - 4, cfg.Center.Z + 4
	for _, seg in
		{
			{ Vector3.new(-halfSpan, y - 0.04, z0), Vector3.new(halfSpan, y + 0.06, z0 + 0.5) },
			{ Vector3.new(-halfSpan, y - 0.04, z1 - 0.5), Vector3.new(halfSpan, y + 0.06, z1) },
			{ Vector3.new(-halfSpan, y - 0.04, z0 + 0.5), Vector3.new(-halfSpan + 0.5, y + 0.06, z1 - 0.5) },
			{ Vector3.new(halfSpan - 0.5, y - 0.04, z0 + 0.5), Vector3.new(halfSpan, y + 0.06, z1 - 0.5) },
		}
	do
		Kit.box(parent, CFrame.new(), seg[1], seg[2], W.HazardYellow, nil, { Name = "AssemblyLine", Decor = true })
	end
	for i = 1, cfg.Count do
		local offset = (i - (cfg.Count + 1) / 2) * cfg.Spacing
		local arc = (math.abs(offset) / (cfg.Spacing * cfg.Count / 2)) ^ 2 * cfg.ArcDepth
		local pos = cfg.Center + Vector3.new(offset, y + 0.1, -arc)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0
		spawn.CanTouch = false
		spawn.Size = Vector3.new(4, 0.2, 4)
		spawn.CFrame = CFrame.new(pos)
		spawn.Color = W.ConcreteDark
		spawn.Material = Enum.Material.Concrete
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.BottomSurface = Enum.SurfaceType.Smooth
		spawn.CastShadow = false
		spawn.Parent = spawns
		-- painted square border on each pad
		for _, seg in
			{
				{ Vector3.new(-2, 0.1, -2), Vector3.new(2, 0.16, -1.6) },
				{ Vector3.new(-2, 0.1, 1.6), Vector3.new(2, 0.16, 2) },
				{ Vector3.new(-2, 0.1, -1.6), Vector3.new(-1.6, 0.16, 1.6) },
				{ Vector3.new(1.6, 0.1, -1.6), Vector3.new(2, 0.16, 1.6) },
			}
		do
			Kit.box(parent, CFrame.new(pos), seg[1], seg[2], W.HazardYellow, nil, { Name = "PadBorder", Decor = true })
		end
	end
	Signage.plaque(
		parent,
		Vector3.new(halfSpan + 3.5, y, cfg.Center.Z - 1),
		Vector3.new(-1, 0, 0),
		"ASSEMBLY POINT",
		{ Background = W.HazardYellow, TextColor = W.Charcoal, Subtitle = "SAMMELPLATZ", PixelsPerStud = 40 },
		Vector2.new(6, 3)
	)
end

function Plaza.build(root: Instance): Folder
	local folder = Kit.folder(root, "Plaza")
	dais(folder)
	mapTable(folder)
	flags(folder)
	statusPylon(folder, -36)
	statusPylon(folder, 36)
	assemblyPoint(root, folder)

	-- direction signposts
	local signs = Kit.folder(folder, "Signposts")
	Signage.post(
		signs,
		Vector3.new(26, Ground.PavedTop, 20),
		Vector3.new(0, 0, 1),
		{ "OperationsCenter", "MapRoom", "CommandHQ", "Garage" }
	)
	Signage.post(
		signs,
		Vector3.new(-58, Ground.PavedTop, 44),
		Vector3.new(0.7, 0, -0.7).Unit,
		{ "EventArea", "Garage", "MapRoom" }
	)
	Signage.post(
		signs,
		Vector3.new(58, Ground.PavedTop, 44),
		Vector3.new(-0.7, 0, -0.7).Unit,
		{ "Leaderboards", "CommandHQ", "SocialArea" }
	)
	Signage.post(
		signs,
		Vector3.new(-58, Ground.PavedTop, -44),
		Vector3.new(0.7, 0, 0.7).Unit,
		{ "MapRoom", "OperationsCenter", "Garage" }
	)
	Signage.post(
		signs,
		Vector3.new(14, Ground.PavedTop, 46),
		Vector3.new(0, 0, -1),
		{ "SocialArea", "MissionBoard", "Leaderboards", "EventArea" }
	)
	return folder
end

return Plaza
