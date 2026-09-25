--!strict
-- Recreation grounds on the open lawns inside the fence: the post softball
-- diamond south of the winter yard (infield, mound, bases, backstop,
-- dugouts, bleachers, outfield fence, scoreboard), the assault course
-- behind the Map Room, and groups of old broadleaf trees.
--
-- Everything stands on the grass (y = 0). Layers on the ground are at
-- least 0.06 apart so nothing shares a plane.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Nature = require(World.Nature)
local Props = require(World.Props)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Grounds = {}

-- Home plate; the diamond opens toward -Z (north).
Grounds.HomePlate = Vector3.new(-118, 0, 168)
Grounds.BaseSpacing = 20
Grounds.FenceRadius = 40

local DIRT = Color3.fromRGB(150, 116, 84)
local CHALK = Color3.fromRGB(232, 230, 222)

local function grounded<T>(model: T): T
	(model :: any):SetAttribute("Grounded", true)
	return model
end

-- A strip on the ground from a to b (world XZ), `top` its top height.
local function strip(parent: Instance, a: Vector3, b: Vector3, width: number, y0: number, top: number, color: Color3)
	local mid = (a + b) / 2
	return Kit.part(
		parent,
		Vector3.new(width, top - y0, (b - a).Magnitude),
		CFrame.lookAt(Vector3.new(mid.X, (y0 + top) / 2, mid.Z), Vector3.new(b.X, (y0 + top) / 2, b.Z)),
		color,
		Enum.Material.SmoothPlastic,
		{ Name = "Chalk", Decor = true }
	)
end

-- Chain-link panel between two posts (world points on the ground).
local function meshPanel(parent: Instance, a: Vector3, b: Vector3, height: number, railColor: Color3)
	local mid = (a + b) / 2
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local along = CFrame.fromMatrix(Vector3.new(mid.X, 0, mid.Z), dir.Unit, Vector3.new(0, 1, 0))
	Kit.part(
		parent,
		Vector3.new(dir.Magnitude, height - 0.4, 0.06),
		along * CFrame.new(0, 0.2 + (height - 0.4) / 2, 0),
		Color3.fromRGB(150, 152, 146),
		Enum.Material.Fabric,
		{ Name = "ChainLink", Transparency = 0.55, Collide = false, Query = false, Shadow = false }
	):SetAttribute("ChainLink", true)
	Kit.cylinder(parent, dir.Magnitude, 0.16, along * CFrame.new(0, height, 0), railColor, Enum.Material.Metal, {
		Name = "TopRail",
		Decor = true,
	})
	Kit.part(
		parent,
		Vector3.new(dir.Magnitude, height, 0.3),
		along * CFrame.new(0, height / 2, 0),
		W.Steel,
		Enum.Material.SmoothPlastic,
		{ Name = "FenceCollider", Transparency = 1, Shadow = false, Query = false }
	)
end

local function post(parent: Instance, p: Vector3, height: number, diameter: number?)
	Kit.post(parent, CFrame.new(p.X, 0, p.Z), height, diameter or 0.3, W.Steel, Enum.Material.Metal, { Name = "Post" })
end

-- Stepped bleachers (four tiers) facing -Z of `cf`, seats on each tier.
local function bleachers(parent: Instance, cf: CFrame, width: number): Model
	local model = Kit.model(parent, "Bleachers")
	for i = 0, 3 do
		local top = 0.7 + i * 0.7
		local z = 1.6 - i * 1.3 -- the front tier nearest the field (-Z)
		Kit.part(
			model,
			Vector3.new(width, top, 1.3),
			cf * CFrame.new(0, top / 2, -z),
			W.ConcreteLight,
			Enum.Material.Concrete,
			{ Name = "Tier", Shadow = true }
		)
		Kit.part(
			model,
			Vector3.new(width - 0.4, 0.14, 0.6),
			cf * CFrame.new(0, top + 0.07, -z + 0.25),
			W.Steel,
			Enum.Material.Metal,
			{ Name = "Seat", Decor = true }
		)
	end
	-- hand rails at both ends
	for _, x in { -width / 2 - 0.15, width / 2 + 0.15 } do
		Kit.part(
			model,
			Vector3.new(0.12, 0.12, 5.6),
			cf * CFrame.new(x, 3.8, 0) * CFrame.Angles(math.rad(-26), 0, 0),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Rail", Decor = true }
		)
	end
	return model
end

-- Dugout: back wall, bench, roof on two posts; open toward -Z of `cf`.
local function dugout(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "Dugout")
	Kit.part(model, Vector3.new(8, 2.8, 0.3), cf * CFrame.new(0, 1.4, 1.2), W.Olive, Enum.Material.WoodPlanks, {
		Name = "BackWall",
		Shadow = true,
	})
	Kit.part(model, Vector3.new(7.4, 0.45, 1), cf * CFrame.new(0, 1.1, 0.5), W.Wood, Enum.Material.Wood, {
		Name = "Bench",
	})
	for _, x in { -3.4, 3.4 } do
		Kit.post(model, cf * CFrame.new(x, 0, -1), 2.9, 0.25, W.SteelDark, Enum.Material.Metal, { Name = "RoofPost" })
	end
	Kit.part(
		model,
		Vector3.new(8.6, 0.25, 2.9),
		cf * CFrame.new(0, 3.03, 0.1) * CFrame.Angles(math.rad(4), 0, 0),
		W.OliveDark,
		Enum.Material.CorrodedMetal,
		{ Name = "Roof", Shadow = true }
	)
	return model
end

local function softballField(parent: Instance)
	local folder = Kit.folder(parent, "SoftballField")
	local H = Grounds.HomePlate
	local s = Grounds.BaseSpacing
	local d = s / math.sqrt(2)
	local mound = H + Vector3.new(0, 0, -d)
	local bases = {
		H + Vector3.new(d, 0, -d), -- first
		H + Vector3.new(0, 0, -2 * d), -- second
		H + Vector3.new(-d, 0, -d), -- third
	}
	local turn = CFrame.Angles(0, math.pi / 4, 0)
	-- infield dirt (top 0.06), the grass cut-out inside the base paths
	-- (top 0.12) and the mound (top 0.4)
	Kit.part(
		folder,
		Vector3.new(s + 4, 0.06, s + 4),
		CFrame.new(mound.X, 0.03, mound.Z) * turn,
		DIRT,
		Enum.Material.Ground,
		{ Name = "Infield", Collide = false, Query = false, Shadow = false }
	)
	Kit.part(
		folder,
		Vector3.new(s - 7, 0.06, s - 7),
		CFrame.new(mound.X, 0.09, mound.Z) * turn,
		Color3.fromRGB(96, 116, 64),
		Enum.Material.Grass,
		{ Name = "InfieldGrass", Collide = false, Query = false, Shadow = false }
	)
	Kit.post(folder, CFrame.new(mound.X, 0, mound.Z), 0.4, 4.4, DIRT, Enum.Material.Ground, {
		Name = "Mound",
		Collide = false,
		Query = false,
	})
	Kit.part(
		folder,
		Vector3.new(1.4, 0.1, 0.35),
		CFrame.new(mound.X, 0.45, mound.Z),
		CHALK,
		Enum.Material.SmoothPlastic,
		{ Name = "Rubber", Decor = true }
	)
	for i, b in bases do
		Kit.part(
			folder,
			Vector3.new(1.3, 0.16, 1.3),
			CFrame.new(b.X, 0.06 + 0.08, b.Z) * turn,
			CHALK,
			Enum.Material.Fabric,
			{ Name = "Base" .. i, Decor = true }
		)
	end
	Kit.part(
		folder,
		Vector3.new(1.2, 0.1, 1.2),
		CFrame.new(H.X, 0.06 + 0.05, H.Z) * turn,
		CHALK,
		Enum.Material.SmoothPlastic,
		{ Name = "HomePlate", Decor = true }
	)
	-- foul lines to the outfield fence (top 0.14: over the dirt and grass)
	local r = Grounds.FenceRadius
	for _, side in { -1, 1 } do
		local tip = H + Vector3.new(side * r * math.sin(math.rad(45)), 0, -r * math.cos(math.rad(45)))
		strip(folder, H, tip, 0.25, 0.06, 0.14, CHALK)
	end
	-- batter's boxes either side of home
	for _, side in { -1, 1 } do
		local c = H + Vector3.new(side * 2.1, 0, -0.4)
		for _, edge in { { -0.9, 0 }, { 0.9, 0 } } do
			local a = c + Vector3.new(edge[1], 0, -1.6)
			local b = c + Vector3.new(edge[1], 0, 1.6)
			strip(folder, a, b, 0.12, 0.06, 0.14, CHALK)
		end
	end
	-- backstop behind home: three chain-link panels in a shallow arc
	local backstop = Kit.model(folder, "Backstop")
	local points = {
		H + Vector3.new(-9, 0, 2.5),
		H + Vector3.new(-4, 0, 5.5),
		H + Vector3.new(4, 0, 5.5),
		H + Vector3.new(9, 0, 2.5),
	}
	for _, p in points do
		post(backstop, p, 8.4, 0.35)
	end
	for i = 1, #points - 1 do
		meshPanel(backstop, points[i], points[i + 1], 8, W.Steel)
	end
	grounded(backstop)
	-- dugouts along the baselines behind the backstop wings, facing the field
	grounded(dugout(folder, CFrame.new(H.X - 15, 0, H.Z + 1) * CFrame.Angles(0, math.rad(-25), 0)))
	grounded(dugout(folder, CFrame.new(H.X + 15, 0, H.Z + 1) * CFrame.Angles(0, math.rad(25), 0)))
	-- bleachers behind the dugouts, facing the diamond
	grounded(bleachers(folder, CFrame.new(H.X - 29, 0, H.Z - 8) * CFrame.Angles(0, math.rad(-65), 0), 11))
	grounded(bleachers(folder, CFrame.new(H.X + 29, 0, H.Z - 8) * CFrame.Angles(0, math.rad(65), 0), 11))
	-- low outfield fence on a 40-stud arc, a yellow home-run rail on top
	local fence = Kit.model(folder, "OutfieldFence")
	local arc: { Vector3 } = {}
	for i = 0, 4 do
		local a = math.rad(-45 + i * 22.5)
		table.insert(arc, H + Vector3.new(r * math.sin(a), 0, -r * math.cos(a)))
	end
	for _, p in arc do
		post(fence, p, 4.3)
	end
	for i = 1, #arc - 1 do
		meshPanel(fence, arc[i], arc[i + 1], 4, W.HazardYellow)
	end
	grounded(fence)
	-- scoreboard past left-centre field, facing home plate
	local boardPos = H + Vector3.new(-26, 0, -38)
	local look = CFrame.lookAt(Vector3.new(boardPos.X, 0, boardPos.Z), Vector3.new(H.X, 0, H.Z))
	local score = Kit.model(folder, "Scoreboard")
	for _, x in { -3.2, 3.2 } do
		Kit.post(score, look * CFrame.new(x, 0, 0), 5.2, 0.4, W.SteelDark, Enum.Material.Metal, { Name = "Post" })
	end
	local board = Kit.part(
		score,
		Vector3.new(8, 3.6, 0.3),
		look * CFrame.new(0, 6.8, 0),
		W.SignGreen,
		Enum.Material.SmoothPlastic,
		{ Name = "Board", Shadow = true }
	)
	local gui = Kit.surface(board, Enum.NormalId.Front, 30, 1, 200)
	Kit.text(gui, {
		Name = "Title",
		Text = "BLACKHORSE LEAGUE",
		Color = W.OffWhite,
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.9, 0.22),
	})
	for i, row in { { "HHT TROOP", "7" }, { "1ST SQDN", "4" } } do
		local y = 0.32 + (i - 1) * 0.3
		Kit.text(gui, {
			Name = "Team" .. i,
			Text = row[1],
			Color = W.OffWhite,
			Font = Theme.font("Mono", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.06, y),
			Size = UDim2.fromScale(0.62, 0.26),
			XAlign = Enum.TextXAlignment.Left,
		})
		Kit.text(gui, {
			Name = "Runs" .. i,
			Text = row[2],
			Color = W.CrtAmber,
			Font = Theme.font("Mono", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.72, y),
			Size = UDim2.fromScale(0.22, 0.26),
		})
	end
	grounded(score)
end

local function assaultCourse(parent: Instance)
	local folder = Kit.folder(parent, "AssaultCourse")
	local z = -158
	local timber = W.BrownDark
	grounded(Props.roadSign(
		folder,
		-- facing south, toward the Map Room and the plaza
		CFrame.new(-151, 0, z + 3) * CFrame.Angles(0, math.pi, 0),
		"ASSAULT COURSE",
		"START · 7 OBSTACLES",
		"white"
	))
	-- the running track: trodden dirt along the obstacles (top 0.06) with a
	-- chalk start and finish line across it (top 0.12)
	Kit.part(
		folder,
		Vector3.new(79, 0.06, 7),
		CFrame.new(-109.5, 0.03, z),
		DIRT,
		Enum.Material.Ground,
		{ Name = "Track", Collide = false, Query = false, Shadow = false }
	)
	for _, x in { -147, -71 } do
		strip(folder, Vector3.new(x, 0, z - 3.2), Vector3.new(x, 0, z + 3.2), 0.4, 0.03, 0.12, CHALK)
	end
	-- a numbered marker beside each obstacle, facing the path from the Map Room
	for i, x in { -142, -130.5, -118.5, -106, -95, -84, -74.6 } do
		local marker = Kit.model(folder, "ObstacleMarker")
		local zs = z + 4.6
		Kit.post(marker, CFrame.new(x, 0, zs), 3.2, 0.3, timber, Enum.Material.Wood, { Name = "Post" })
		Kit.sign(
			marker,
			CFrame.new(x, 2.4, zs + 0.2) * CFrame.Angles(0, math.pi, 0),
			Vector2.new(1.1, 1.1),
			tostring(i),
			{ Background = W.OffWhite, TextColor = W.Charcoal, Depth = 0.12, PixelsPerStud = 32 }
		)
		grounded(marker)
	end
	-- 1 hurdles
	for _, x in { -144, -140 } do
		local hurdle = Kit.model(folder, "Hurdle")
		for _, dz in { -2, 2 } do
			Kit.post(hurdle, CFrame.new(x, 0, z + dz), 2.4, 0.3, timber, Enum.Material.Wood, { Name = "Post" })
		end
		Kit.cylinder(
			hurdle,
			4.4,
			0.25,
			CFrame.new(x, 2.2, z) * CFrame.Angles(0, math.pi / 2, 0),
			timber,
			Enum.Material.Wood,
			{
				Name = "Bar",
			}
		)
		grounded(hurdle)
	end
	-- 2 tire run: two rows of tires lying flat
	local tires = Kit.model(folder, "TireRun")
	for i = 0, 3 do
		for _, dz in { -1.2, 1.2 } do
			Kit.post(
				tires,
				CFrame.new(-134 + i * 2.3, 0, z + dz + (i % 2) * 0.3),
				0.7,
				2,
				W.Rubber,
				Enum.Material.SmoothPlastic,
				{
					Name = "Tire",
				}
			)
		end
	end
	grounded(tires)
	-- 3 balance beam: a log on two trestles
	local beam = Kit.model(folder, "BalanceBeam")
	for _, x in { -122, -115 } do
		for _, side in { -1, 1 } do
			Kit.part(
				beam,
				Vector3.new(0.35, 2, 0.35),
				CFrame.new(x, 0.95, z + side * 0.5) * CFrame.Angles(side * math.rad(18), 0, 0),
				timber,
				Enum.Material.Wood,
				{ Name = "Trestle" }
			)
		end
	end
	Kit.cylinder(beam, 9, 0.6, CFrame.new(-118.5, 2.05, z), W.Wood, Enum.Material.Wood, { Name = "Log" })
	grounded(beam)
	-- 4 climbing wall with back struts
	local wall = Kit.model(folder, "ClimbingWall")
	Kit.part(wall, Vector3.new(0.6, 6, 6), CFrame.new(-106, 3, z), W.Wood, Enum.Material.WoodPlanks, { Name = "Wall" })
	for _, dz in { -2.4, 2.4 } do
		Kit.part(
			wall,
			Vector3.new(4.6, 0.35, 0.35),
			CFrame.new(-104, 2.9, z + dz) * CFrame.Angles(0, 0, math.rad(52)),
			timber,
			Enum.Material.Wood,
			{ Name = "Strut" }
		)
	end
	grounded(wall)
	-- 5 crawl net: camouflage net low over four posts
	grounded(Props.camoNet(folder, CFrame.new(-95, 0, z), Vector2.new(6, 4), 1.5))
	-- 6 rope frame: two A-frames, a top beam and three ropes
	local frame = Kit.model(folder, "RopeFrame")
	for _, dz in { -2.6, 2.6 } do
		for _, dx in { -1, 1 } do
			Kit.part(
				frame,
				Vector3.new(0.35, 7.4, 0.35),
				CFrame.new(-84 + dx * 1.2, 3.6, z + dz) * CFrame.Angles(0, 0, dx * math.rad(-10)),
				timber,
				Enum.Material.Wood,
				{ Name = "Leg" }
			)
		end
	end
	Kit.cylinder(
		frame,
		5.8,
		0.4,
		CFrame.new(-84, 7.2, z) * CFrame.Angles(0, math.pi / 2, 0),
		timber,
		Enum.Material.Wood,
		{
			Name = "TopBeam",
		}
	)
	for _, dz in { -1.4, 0, 1.4 } do
		Kit.post(frame, CFrame.new(-84, 1.4, z + dz), 5.6, 0.14, Color3.fromRGB(176, 156, 112), Enum.Material.Fabric, {
			Name = "Rope",
			Decor = true,
		})
	end
	grounded(frame)
	-- 7 log step-ups of rising height
	local logs = Kit.model(folder, "StepLogs")
	for i = 0, 3 do
		Kit.post(
			logs,
			CFrame.new(-77 + i * 1.6, 0, z + (i % 2) * 0.6),
			0.8 + i * 0.5,
			1.1,
			W.Wood,
			Enum.Material.Wood,
			{
				Name = "Stump",
			}
		)
	end
	grounded(logs)
	grounded(Props.bench(folder, CFrame.new(-146, 0, z - 5) * CFrame.Angles(0, math.pi, 0), 6))
end

local function treeGroups(parent: Instance)
	local folder = Kit.folder(parent, "Trees")
	local rng = Random.new(1958)
	for _, spot in
		{
			-- behind the third-base bleachers and along the south fence
			{ -168, 148 },
			{ -174, 160 },
			{ -163, 166 },
			{ -178, 136 },
			-- beyond first base, toward the canteen
			{ -72, 158 },
			{ -64, 168 },
			-- by the assault course and the water tower
			{ -157, -136 },
			{ -122, -136 },
			-- south-east lawn
			{ 124, 168 },
			{ 136, 164 },
		}
	do
		Nature.leafy(folder, CFrame.new(spot[1], 0, spot[2]), rng:NextNumber(14, 20), rng)
	end
end

function Grounds.build(parent: Instance)
	local folder = Kit.folder(parent, "Grounds")
	softballField(folder)
	assaultCourse(folder)
	treeGroups(folder)
end

return Grounds
