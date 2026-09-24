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
	-- dark granite ring inlay on the upper step
	Kit.post(
		parent,
		base * CFrame.new(0, cfg.StepHeight * cfg.Steps, 0),
		0.04,
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
		0.06,
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
	local daisTop = Ground.PavedTop + Layout.Dais.StepHeight * Layout.Dais.Steps
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
	for _, seg in
		{
			{ Vector3.new(-size.X / 2, -0.3, -size.Y / 2), Vector3.new(size.X / 2, 0.35, -size.Y / 2 + 0.6) },
			{ Vector3.new(-size.X / 2, -0.3, size.Y / 2 - 0.6), Vector3.new(size.X / 2, 0.35, size.Y / 2) },
			{ Vector3.new(-size.X / 2, -0.3, -size.Y / 2), Vector3.new(-size.X / 2 + 0.6, 0.35, size.Y / 2) },
			{ Vector3.new(size.X / 2 - 0.6, -0.3, -size.Y / 2), Vector3.new(size.X / 2, 0.35, size.Y / 2) },
		}
	do
		Kit.box(model, top, seg[1], seg[2], W.Steel, Enum.Material.Metal, { Name = "Rim" })
	end
	return model
end

local function flags(parent: Instance)
	local folder = Kit.folder(parent, "Flags")
	local center = Layout.Dais.Center
	local radius = Layout.Dais.Radius + 1.8
	local plan = {
		{ Angle = 160, Height = 26, Design = Architecture.Flags.Nato },
		{ Angle = 134, Height = 29, Design = Architecture.Flags.WestGermany },
		{ Angle = 106, Height = 33, Design = Architecture.Flags.Base },
		{ Angle = 74, Height = 33, Design = Architecture.Flags.Base },
		{ Angle = 46, Height = 29, Design = Architecture.Flags.Regiment },
		{ Angle = 20, Height = 26, Design = Architecture.Flags.Pact },
	}
	for _, f in plan do
		local a = math.rad(f.Angle)
		local pos = center + Vector3.new(math.cos(a) * radius, Ground.PavedTop, -math.sin(a) * radius)
		-- flags stream toward the east (prevailing wind)
		Architecture.flagpole(folder, CFrame.new(pos), f.Height, f.Design, 8)
	end
end

local function statusPylon(parent: Instance, x: number)
	local model = Kit.model(parent, "StatusPylon")
	local c = Layout.Dais.Center
	local base = CFrame.new(x, Ground.PavedTop, c.Z)
	Kit.box(
		model,
		base,
		Vector3.new(-6.6, 0, -1.2),
		Vector3.new(6.6, 0.6, 1.2),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Footing" }
	)
	for _, px in { -5.4, 5.4 } do
		Kit.box(
			model,
			base,
			Vector3.new(px - 0.45, 0.6, -0.45),
			Vector3.new(px + 0.45, 12.8, 0.45),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Post" }
		)
	end
	local board = Kit.box(
		model,
		base,
		Vector3.new(-6.2, 5.6, -0.35),
		Vector3.new(6.2, 12.6, 0.35),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{
			Name = "StatusBoard",
		}
	)
	board:SetAttribute("StatusBoard", true)
	Kit.box(
		model,
		base,
		Vector3.new(-6.6, 12.6, -0.6),
		Vector3.new(6.6, 13.1, 0.6),
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
			{ Vector3.new(-halfSpan, y, z0), Vector3.new(halfSpan, y + 0.03, z0 + 0.5) },
			{ Vector3.new(-halfSpan, y, z1 - 0.5), Vector3.new(halfSpan, y + 0.03, z1) },
			{ Vector3.new(-halfSpan, y, z0), Vector3.new(-halfSpan + 0.5, y + 0.03, z1) },
			{ Vector3.new(halfSpan - 0.5, y, z0), Vector3.new(halfSpan, y + 0.03, z1) },
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
				{ Vector3.new(-2, 0.1, -2), Vector3.new(2, 0.13, -1.6) },
				{ Vector3.new(-2, 0.1, 1.6), Vector3.new(2, 0.13, 2) },
				{ Vector3.new(-2, 0.1, -2), Vector3.new(-1.6, 0.13, 2) },
				{ Vector3.new(1.6, 0.1, -2), Vector3.new(2, 0.13, 2) },
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
