--!strict
-- Base perimeter and outlying landmarks: fence + invisible boundary, main
-- gate checkpoint, guard towers, barracks, vehicle sheds, water tower, the
-- comms compound with the radio mast and troposcatter antennas, helipad,
-- forest belt, hills and a distant village skyline.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Architecture = require(script.Parent.Architecture)
local Ground = require(script.Parent.Ground)
local Kit = require(script.Parent.Kit)
local Nature = require(script.Parent.Nature)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Perimeter = {}

Perimeter.GameTitle = "FULDA GAP"
Perimeter.BaseName = "FORWARD COMMAND BASE"

local UP = Vector3.new(0, 1, 0)

local function beam(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?,
	opts: Kit.Opts?
): Part
	local delta = b - a
	local length = delta.Magnitude
	local mid = (a + b) / 2
	local dir = delta.Unit
	local ref = if math.abs(dir.Y) > 0.95 then Vector3.new(1, 0, 0) else UP
	local right = dir:Cross(ref).Unit
	local up = right:Cross(dir).Unit
	-- length along local Z
	local cf = CFrame.fromMatrix(mid, right, up, -dir)
	return Kit.part(parent, Vector3.new(thickness, thickness, length), cf, color, material, opts)
end
Perimeter.beam = beam

-- Security fence between two ground points: concrete posts, wire rails,
-- barbed-wire outriggers and a tall invisible collider.
local function fenceRun(parent: Instance, a: Vector3, b: Vector3, spacing: number)
	local delta = b - a
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local count = math.max(1, math.floor(length / spacing))
	for i = 0, count do
		local p = a + delta * (i / count)
		Kit.box(
			parent,
			CFrame.new(p),
			Vector3.new(-0.4, 0, -0.4),
			Vector3.new(0.4, 9, 0.4),
			W.ConcreteLight,
			Enum.Material.Concrete,
			{
				Name = "FencePost",
			}
		)
		local arm = Kit.part(
			parent,
			Vector3.new(0.25, 2.2, 0.25),
			CFrame.lookAt(p + Vector3.new(0, 9.6, 0), p + Vector3.new(0, 9.6, 0) + dir)
				* CFrame.Angles(0, 0, math.rad(35)),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Outrigger", Decor = true }
		)
		arm.CastShadow = false
	end
	for _, y in { 2, 4.5, 7, 8.8 } do
		beam(
			parent,
			a + Vector3.new(0, y, 0),
			b + Vector3.new(0, y, 0),
			0.14,
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Wire", Decor = true }
		)
	end
	beam(
		parent,
		a + Vector3.new(0, 10.4, 0),
		b + Vector3.new(0, 10.4, 0),
		0.3,
		W.Steel,
		Enum.Material.Metal,
		{ Name = "Barbed", Decor = true }
	)
	local mid = (a + b) / 2
	local collider = Kit.part(
		parent,
		Vector3.new(length, 34, 1),
		CFrame.fromMatrix(mid + Vector3.new(0, 17, 0), dir, UP),
		W.Steel,
		Enum.Material.SmoothPlastic,
		{ Name = "BoundaryCollider", Transparency = 1, Shadow = false, Query = false }
	)
	collider:SetAttribute("Boundary", true)
end

local function fence(parent: Instance)
	local folder = Kit.folder(parent, "Fence")
	local p = Layout.Perimeter
	local gate = Layout.Gate
	local y = 0
	local nw = Vector3.new(p.MinX, y, p.MinZ)
	local ne = Vector3.new(p.MaxX, y, p.MinZ)
	local se = Vector3.new(p.MaxX, y, p.MaxZ)
	local sw = Vector3.new(p.MinX, y, p.MaxZ)
	fenceRun(folder, nw, ne, 10)
	fenceRun(folder, ne, Vector3.new(p.MaxX, y, gate.Center.Z - gate.Width / 2 - 2), 10)
	fenceRun(folder, Vector3.new(p.MaxX, y, gate.Center.Z + gate.Width / 2 + 2), se, 10)
	fenceRun(folder, se, sw, 10)
	fenceRun(folder, sw, nw, 10)
	-- invisible barrier across the gate so players stay in the lobby
	local barrier = Kit.part(
		folder,
		Vector3.new(1, 34, gate.Width + 4),
		CFrame.new(gate.Center + Vector3.new(0.5, 17, 0)),
		W.Steel,
		Enum.Material.SmoothPlastic,
		{ Name = "GateBarrier", Transparency = 1, Shadow = false, Query = false }
	)
	barrier:SetAttribute("Boundary", true)
end

local function gate(parent: Instance)
	local folder = Kit.folder(parent, "MainGate")
	local g = Layout.Gate
	local x = g.Center.X
	local roadMinZ, roadMaxZ = g.Center.Z - 6, g.Center.Z + 6

	-- arch over the road with the base name, readable from inside
	for _, z in { roadMinZ - 3, roadMaxZ + 3 } do
		Kit.box(
			folder,
			CFrame.new(x - 3, 0, z),
			Vector3.new(-0.8, 0, -0.8),
			Vector3.new(0.8, 13, 0.8),
			W.SteelDark,
			Enum.Material.Metal,
			{
				Name = "ArchPost",
			}
		)
	end
	Kit.box(
		folder,
		CFrame.new(x - 3, 0, g.Center.Z),
		Vector3.new(-0.7, 11.6, roadMinZ - 3.6 - g.Center.Z),
		Vector3.new(0.7, 13, roadMaxZ + 3.6 - g.Center.Z),
		W.SteelDark,
		Enum.Material.Metal,
		{
			Name = "ArchBeam",
		}
	)
	local signCf = CFrame.lookAt(Vector3.new(x - 3.8, 9.6, g.Center.Z), Vector3.new(x - 10, 9.6, g.Center.Z))
	Kit.sign(folder, signCf, Vector2.new(17, 3.4), Perimeter.GameTitle, {
		Background = W.SignGreen,
		Subtitle = Perimeter.BaseName,
		Stripe = W.MutedRed,
		PixelsPerStud = 30,
	})

	-- guard booth north of the road
	local booth = CFrame.new(x - 10, 0, roadMinZ - 8)
	Kit.box(
		folder,
		booth,
		Vector3.new(-4, 0, -4),
		Vector3.new(4, 0.6, 4),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "BoothBase" }
	)
	Kit.box(
		folder,
		booth,
		Vector3.new(-3.6, 0.6, -3.6),
		Vector3.new(3.6, 3.4, 3.6),
		W.OffWhite,
		Enum.Material.Concrete,
		{ Name = "BoothWall" }
	)
	Kit.box(folder, booth, Vector3.new(-3.6, 3.4, -3.6), Vector3.new(3.6, 6.8, 3.6), W.Glass, Enum.Material.Glass, {
		Name = "BoothGlass",
		Reflectance = 0.1,
	})
	Kit.box(
		folder,
		booth,
		Vector3.new(-4.4, 6.8, -4.4),
		Vector3.new(4.4, 7.6, 4.4),
		W.MutedRed,
		Enum.Material.SmoothPlastic,
		{ Name = "BoothRoof" }
	)
	Kit.box(
		folder,
		booth,
		Vector3.new(-4.6, 7.6, -4.6),
		Vector3.new(4.6, 7.9, 4.6),
		W.OffWhite,
		Enum.Material.SmoothPlastic,
		{ Name = "BoothRoofTrim" }
	)

	-- boom barrier across the road (red/white)
	local pivot = Vector3.new(x - 1, 0, roadMinZ - 1)
	Kit.box(
		folder,
		CFrame.new(pivot),
		Vector3.new(-0.6, 0, -0.6),
		Vector3.new(0.6, 3.6, 0.6),
		W.OffWhite,
		Enum.Material.SmoothPlastic,
		{ Name = "BarrierPost" }
	)
	local armLength = roadMaxZ - roadMinZ + 1
	local segments = 6
	for i = 0, segments - 1 do
		local z0 = pivot.Z + 0.6 + i * armLength / segments
		Kit.box(
			folder,
			CFrame.new(),
			Vector3.new(pivot.X - 0.25, 3.0, z0),
			Vector3.new(pivot.X + 0.25, 3.5, z0 + armLength / segments),
			if i % 2 == 0 then W.MutedRed else W.OffWhite,
			Enum.Material.SmoothPlastic,
			{ Name = "BarrierArm", Collide = false }
		)
	end

	-- speed bump + warning plaque inside the gate
	for i = 0, 5 do
		local z0 = roadMinZ + i * 2
		Kit.box(
			folder,
			CFrame.new(),
			Vector3.new(x - 18, Ground.RoadTop, z0),
			Vector3.new(x - 16.6, Ground.RoadTop + 0.3, z0 + 2),
			if i % 2 == 0 then W.HazardYellow else W.Charcoal,
			nil,
			{
				Name = "SpeedBump",
				Shadow = false,
			}
		)
	end
	local plaque = Kit.model(folder, "HaltSign")
	local pp = Vector3.new(x - 14, 0, roadMaxZ + 2.5)
	Kit.post(plaque, CFrame.new(pp), 6.4, 0.35, W.Steel, Enum.Material.Metal, { Name = "Post" })
	Kit.sign(
		plaque,
		CFrame.lookAt(pp + Vector3.new(-0.3, 5.2, 0), pp + Vector3.new(-5, 5.2, 0)),
		Vector2.new(4, 2.4),
		"HALT",
		{
			Background = W.MutedRed,
			Subtitle = "CHECKPOINT · AUSWEISKONTROLLE",
			PixelsPerStud = 40,
		}
	)
end

local function guardTower(parent: Instance, position: Vector3, facing: number)
	local model = Kit.model(parent, "GuardTower")
	local base = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	local h = 16
	local s = 3.4
	for _, c in { Vector3.new(-s, 0, -s), Vector3.new(s, 0, -s), Vector3.new(-s, 0, s), Vector3.new(s, 0, s) } do
		Kit.box(
			model,
			base * CFrame.new(c),
			Vector3.new(-0.4, 0, -0.4),
			Vector3.new(0.4, h, 0.4),
			W.Wood,
			Enum.Material.Wood,
			{ Name = "Leg" }
		)
	end
	for _, y in { 5, 10.5 } do
		for _, seg in
			{
				{ Vector3.new(-s, y, -s), Vector3.new(s, y, -s) },
				{ Vector3.new(-s, y, s), Vector3.new(s, y, s) },
				{ Vector3.new(-s, y, -s), Vector3.new(-s, y, s) },
				{ Vector3.new(s, y, -s), Vector3.new(s, y, s) },
			}
		do
			beam(
				model,
				(base * CFrame.new(seg[1])).Position,
				(base * CFrame.new(seg[2])).Position,
				0.35,
				W.Wood,
				Enum.Material.Wood,
				{
					Name = "Brace",
					Decor = true,
				}
			)
		end
	end
	Kit.box(
		model,
		base,
		Vector3.new(-4.4, h, -4.4),
		Vector3.new(4.4, h + 0.6, 4.4),
		W.Wood,
		Enum.Material.WoodPlanks,
		{ Name = "Platform" }
	)
	for _, seg in
		{
			{ Vector3.new(-4.4, h + 0.6, -4.4), Vector3.new(4.4, h + 3, -4) },
			{ Vector3.new(-4.4, h + 0.6, 4), Vector3.new(4.4, h + 3, 4.4) },
			{ Vector3.new(-4.4, h + 0.6, -4.4), Vector3.new(-4, h + 3, 4.4) },
			{ Vector3.new(4, h + 0.6, -4.4), Vector3.new(4.4, h + 3, 4.4) },
		}
	do
		Kit.box(model, base, seg[1], seg[2], W.OliveDark, Enum.Material.WoodPlanks, { Name = "Parapet" })
	end
	for _, c in
		{ Vector3.new(-4.1, 0, -4.1), Vector3.new(4.1, 0, -4.1), Vector3.new(-4.1, 0, 4.1), Vector3.new(4.1, 0, 4.1) }
	do
		Kit.box(
			model,
			base * CFrame.new(c),
			Vector3.new(-0.25, h + 3, -0.25),
			Vector3.new(0.25, h + 6.6, 0.25),
			W.Wood,
			Enum.Material.Wood,
			{
				Name = "RoofPost",
				Decor = true,
			}
		)
	end
	Kit.box(
		model,
		base,
		Vector3.new(-5.2, h + 6.6, -5.2),
		Vector3.new(5.2, h + 7.3, 5.2),
		W.OliveDark,
		Enum.Material.CorrodedMetal,
		{ Name = "Roof" }
	)
	local light = Kit.cylinder(
		model,
		1.6,
		1.4,
		base * CFrame.new(3.4, h + 7.9, -3.4) * CFrame.Angles(0, math.rad(-45), 0),
		W.SteelDark,
		Enum.Material.Metal,
		{
			Name = "Searchlight",
			Decor = true,
		}
	)
	light.CastShadow = false
	-- ladder rails
	for _, x in { -0.8, 0.8 } do
		Kit.box(
			model,
			base * CFrame.new(x, 0, s + 0.6),
			Vector3.new(-0.12, 0, -0.12),
			Vector3.new(0.12, h, 0.12),
			W.SteelDark,
			Enum.Material.Metal,
			{
				Name = "Ladder",
				Decor = true,
			}
		)
	end
	return model
end

local function barracks(
	parent: Instance,
	facade: Vector3,
	inward: Vector3,
	length: number,
	depth: number,
	number: string
)
	local model = Kit.model(parent, "Barracks")
	local frame = CFrame.lookAt(facade, facade + inward)
	local halfL = length / 2
	local eave = 15
	local plaster = Color3.fromRGB(196, 186, 160)
	Kit.box(
		model,
		frame,
		Vector3.new(-halfL, 0, -depth),
		Vector3.new(halfL, 0.6, 0),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Floor" }
	)
	Kit.box(
		model,
		frame,
		Vector3.new(-halfL, 0.6, -depth),
		Vector3.new(halfL, eave, 0),
		plaster,
		Enum.Material.Concrete,
		{ Name = "Block" }
	)
	Kit.box(
		model,
		frame,
		Vector3.new(-halfL - 0.2, 0, -depth - 0.2),
		Vector3.new(halfL + 0.2, 1.8, 0.2),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Plinth" }
	)
	Architecture.gableRoof(
		model,
		frame,
		-halfL - 0.3,
		halfL + 0.3,
		-depth - 0.3,
		0.3,
		eave,
		6,
		1.4,
		W.BrickDark,
		plaster,
		Enum.Material.Slate,
		Enum.Material.Concrete
	)
	local style: Architecture.WindowStyle = { Frame = W.OffWhite, Sill = W.OffWhite }
	local count = math.floor(length / 7)
	Architecture.windowRow(model, frame, -halfL + 1, halfL - 1, 0, 1, 3.6, 7.4, count, 2.8, style)
	Architecture.windowRow(model, frame, -halfL + 1, halfL - 1, 0, 1, 9.6, 13.2, count, 2.8, style)
	Architecture.windowRow(model, frame, -halfL + 1, halfL - 1, -depth, -1, 9.6, 13.2, count, 2.8, style)
	for _, x in { -halfL / 2, 0, halfL / 2 } do
		Kit.box(
			model,
			frame,
			Vector3.new(x - 2, 0.6, 0),
			Vector3.new(x + 2, 7.6, 0.25),
			W.BrownDark,
			Enum.Material.Wood,
			{ Name = "Door" }
		)
		Kit.box(
			model,
			frame,
			Vector3.new(x - 3, 8.2, 0),
			Vector3.new(x + 3, 8.6, 3),
			W.ConcreteDark,
			Enum.Material.Concrete,
			{ Name = "DoorCanopy" }
		)
		Kit.box(
			model,
			frame,
			Vector3.new(x - 3, 0, 0),
			Vector3.new(x + 3, 0.6, 2.6),
			W.Concrete,
			Enum.Material.Concrete,
			{ Name = "DoorStep" }
		)
	end
	Kit.sign(model, Kit.facingOut(frame, Vector3.new(-halfL + 4, 6, 0.25)), Vector2.new(3.4, 2), number, {
		Background = W.OffWhite,
		TextColor = W.Charcoal,
		Depth = 0.15,
		PixelsPerStud = 40,
	})
	return model
end

local function vehicleShed(parent: Instance)
	local model = Kit.model(parent, "VehicleShed")
	local x0, x1, z0, z1 = -54, 54, -166, -146
	local h = 14
	Kit.box(
		model,
		CFrame.new(),
		Vector3.new(x0, 0, z0),
		Vector3.new(x1, 0.3, z1),
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "Slab", Shadow = false }
	)
	Kit.box(
		model,
		CFrame.new(),
		Vector3.new(x0, 0.3, z0),
		Vector3.new(x1, h, z0 + 1),
		W.ConcreteLight,
		Enum.Material.Concrete,
		{ Name = "BackWall" }
	)
	for x = x0, x1, 12 do
		Kit.box(
			model,
			CFrame.new(),
			Vector3.new(x - 0.5, 0.3, z1 - 1.5),
			Vector3.new(x + 0.5, h - 1, z1 - 0.5),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Column" }
		)
	end
	Kit.part(
		model,
		Vector3.new(x1 - x0 + 3, 0.8, z1 - z0 + 3),
		CFrame.new((x0 + x1) / 2, h - 0.6, (z0 + z1) / 2) * CFrame.Angles(math.rad(-6), 0, 0),
		W.SteelDark,
		Enum.Material.CorrodedMetal,
		{ Name = "Roof" }
	)
	return model
end

local function waterTower(parent: Instance, position: Vector3)
	local model = Kit.model(parent, "WaterTower")
	local base = CFrame.new(position)
	local legH = 32
	local s = 5.5
	for _, c in { Vector3.new(-s, 0, -s), Vector3.new(s, 0, -s), Vector3.new(-s, 0, s), Vector3.new(s, 0, s) } do
		Kit.post(model, base * CFrame.new(c), legH, 1.1, W.SteelDark, Enum.Material.Metal, { Name = "Leg" })
		Kit.box(
			model,
			base * CFrame.new(c),
			Vector3.new(-1, 0, -1),
			Vector3.new(1, 1, 1),
			W.Concrete,
			Enum.Material.Concrete,
			{ Name = "Footing" }
		)
	end
	for _, y in { 11, 22 } do
		for _, seg in
			{
				{ Vector3.new(-s, y, -s), Vector3.new(s, y, -s) },
				{ Vector3.new(-s, y, s), Vector3.new(s, y, s) },
				{ Vector3.new(-s, y, -s), Vector3.new(-s, y, s) },
				{ Vector3.new(s, y, -s), Vector3.new(s, y, s) },
			}
		do
			beam(
				model,
				(base * CFrame.new(seg[1])).Position,
				(base * CFrame.new(seg[2])).Position,
				0.5,
				W.SteelDark,
				Enum.Material.Metal,
				{
					Name = "Brace",
					Decor = true,
				}
			)
		end
	end
	Kit.post(model, base * CFrame.new(0, legH, 0), 0.5, 19, W.SteelDark, Enum.Material.Metal, { Name = "Walkway" })
	Kit.post(model, base * CFrame.new(0, legH + 0.5, 0), 11, 16, W.OliveLight, Enum.Material.Metal, { Name = "Tank" })
	Kit.post(
		model,
		base * CFrame.new(0, legH + 11.5, 0),
		1.6,
		12,
		W.OliveDark,
		Enum.Material.Metal,
		{ Name = "RoofStep" }
	)
	Kit.post(
		model,
		base * CFrame.new(0, legH + 13.1, 0),
		1.4,
		7,
		W.OliveDark,
		Enum.Material.Metal,
		{ Name = "RoofStep" }
	)
	Kit.post(
		model,
		base * CFrame.new(0, legH + 14.5, 0),
		1.2,
		2.4,
		W.OliveDark,
		Enum.Material.Metal,
		{ Name = "RoofCap" }
	)
	Kit.post(
		model,
		base * CFrame.new(0, legH + 5.2, 0),
		0.8,
		16.2,
		W.OliveDark,
		Enum.Material.Metal,
		{ Name = "TankBand", Decor = true }
	)
	local light = Kit.ball(
		model,
		0.7,
		base * CFrame.new(0, legH + 16.1, 0),
		W.LampRed,
		Enum.Material.Neon,
		{ Name = "WarningLight", Decor = true }
	)
	Kit.anchor(light, "BlinkRed")
	return model
end

local function troposcatter(parent: Instance, position: Vector3, facing: Vector3)
	local model = Kit.model(parent, "TroposcatterAntenna")
	local frame = CFrame.lookAt(position, position + facing)
	-- A-frame support
	for _, x in { -6, 6 } do
		beam(
			model,
			(frame * CFrame.new(x, 0, 4)).Position,
			(frame * CFrame.new(x, 16, -1)).Position,
			0.8,
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Strut" }
		)
		beam(
			model,
			(frame * CFrame.new(x, 0, -4)).Position,
			(frame * CFrame.new(x, 16, -1)).Position,
			0.8,
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Strut" }
		)
	end
	Kit.box(
		model,
		frame,
		Vector3.new(-8, 0, -5),
		Vector3.new(8, 0.8, 5),
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "Footing" }
	)
	-- slightly curved reflector made of three panels
	for i, a in { -0.28, 0, 0.28 } do
		Kit.part(
			model,
			Vector3.new(6.4, 18, 0.5),
			frame * CFrame.new(math.sin(a) * 6.6, 12, -2 + (1 - math.cos(a)) * 6) * CFrame.Angles(math.rad(-8), a, 0),
			Color3.fromRGB(206, 204, 194),
			Enum.Material.SmoothPlastic,
			{ Name = "Reflector" .. i }
		)
	end
	Kit.part(
		model,
		Vector3.new(1.4, 1.4, 5),
		frame * CFrame.new(0, 12, -7),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "FeedHorn", Decor = true }
	)
	return model
end

local function commsCompound(parent: Instance)
	local folder = Kit.folder(parent, "CommsCompound")
	local x0, x1, z0, z1 = 96, 152, -154, -84
	Kit.box(
		folder,
		CFrame.new(),
		Vector3.new(x0, 0, z0),
		Vector3.new(x1, 0.2, z1),
		Color3.fromRGB(120, 118, 108),
		Enum.Material.Pavement,
		{
			Name = "Gravel",
			Shadow = false,
		}
	)
	-- low fence with a gate toward the north road
	local fenceFolder = Kit.folder(folder, "Fence")
	local function run(a: Vector3, b: Vector3)
		local delta = b - a
		local count = math.max(1, math.floor(delta.Magnitude / 8))
		for i = 0, count do
			local p = a + delta * (i / count)
			Kit.post(fenceFolder, CFrame.new(p), 6, 0.4, W.Steel, Enum.Material.Metal, { Name = "Post" })
		end
		for _, y in { 2, 4, 5.8 } do
			beam(
				fenceFolder,
				a + Vector3.new(0, y, 0),
				b + Vector3.new(0, y, 0),
				0.14,
				W.SteelDark,
				Enum.Material.Metal,
				{ Name = "Wire", Decor = true }
			)
		end
		local mid = (a + b) / 2
		Kit.part(
			fenceFolder,
			Vector3.new(delta.Magnitude, 7, 0.4),
			CFrame.fromMatrix(mid + Vector3.new(0, 3.5, 0), delta.Unit, UP),
			W.Steel,
			Enum.Material.SmoothPlastic,
			{ Name = "FenceCollider", Transparency = 1, Shadow = false, Query = false }
		)
	end
	run(Vector3.new(x0, 0, z1), Vector3.new(118, 0, z1))
	run(Vector3.new(126, 0, z1), Vector3.new(x1, 0, z1))
	run(Vector3.new(x1, 0, z1), Vector3.new(x1, 0, z0))
	run(Vector3.new(x1, 0, z0), Vector3.new(x0, 0, z0))
	run(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1))

	-- comms shack
	local shack = CFrame.lookAt(Vector3.new(108, 0, -92), Vector3.new(108, 0, -93))
	Kit.box(
		folder,
		shack,
		Vector3.new(-8, 0, -12),
		Vector3.new(8, 0.6, 0),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "ShackFloor" }
	)
	Kit.box(
		folder,
		shack,
		Vector3.new(-8, 0.6, -12),
		Vector3.new(8, 9, 0),
		W.OliveLight,
		Enum.Material.Concrete,
		{ Name = "Shack" }
	)
	Architecture.flatRoof(folder, shack, -8, 8, -12, 0, 9, 0.8, W.OliveLight)
	Architecture.windowRow(folder, shack, -7, 7, 0, 1, 4, 7, 3, 2.6, { Frame = W.DarkGrey })
	Kit.box(
		folder,
		shack,
		Vector3.new(-1.6, 0.6, 0),
		Vector3.new(1.6, 7.4, 0.3),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "Door" }
	)
	for i, pos in { Vector3.new(-5, 10, -3), Vector3.new(0, 10, -9), Vector3.new(5, 10, -5) } do
		Kit.post(folder, shack * CFrame.new(pos), 8 + i * 2, 0.3, W.Steel, Enum.Material.Metal, { Name = "Whip" })
	end
	local hum = Kit.part(
		folder,
		Vector3.new(4, 5, 3),
		CFrame.new(140, 2.7, -92),
		W.OliveDark,
		Enum.Material.Metal,
		{ Name = "Generator" }
	)
	Kit.anchor(hum, "Sound", "Transformer")

	-- radio mast with guy wires and warning lights
	local mastBase = Vector3.new(126, 0, -118)
	Kit.box(
		folder,
		CFrame.new(mastBase),
		Vector3.new(-3, 0, -3),
		Vector3.new(3, 1.2, 3),
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "MastFooting" }
	)
	local truss = Instance.new("TrussPart")
	truss.Name = "RadioMast"
	truss.Anchored = true
	truss.CanCollide = false
	truss.CanTouch = false
	truss.Size = Vector3.new(2, 86, 2)
	truss.CFrame = CFrame.new(mastBase + Vector3.new(0, 1.2 + 43, 0))
	truss.Color = Color3.fromRGB(176, 74, 60)
	truss.Material = Enum.Material.Metal
	truss.Parent = folder
	for _, h in { 30, 58, 87.6 } do
		local light = Kit.ball(
			folder,
			0.9,
			CFrame.new(mastBase + Vector3.new(1.2, h, 0)),
			W.LampRed,
			Enum.Material.Neon,
			{ Name = "WarningLight", Decor = true }
		)
		Kit.anchor(light, "BlinkRed")
	end
	Kit.post(
		folder,
		CFrame.new(mastBase + Vector3.new(0, 87.2, 0)),
		8,
		0.3,
		W.Steel,
		Enum.Material.Metal,
		{ Name = "TopWhip" }
	)
	for _, a in { 0, 2.094, 4.189 } do
		local anchor = mastBase + Vector3.new(math.cos(a) * 22, 0.2, math.sin(a) * 22)
		for _, h in { 32, 60 } do
			beam(
				folder,
				mastBase + Vector3.new(0, h, 0),
				anchor,
				0.12,
				W.Steel,
				Enum.Material.Metal,
				{ Name = "GuyWire", Decor = true }
			)
		end
		Kit.box(
			folder,
			CFrame.new(anchor),
			Vector3.new(-1, -0.2, -1),
			Vector3.new(1, 0.8, 1),
			W.Concrete,
			Enum.Material.Concrete,
			{ Name = "GuyAnchor" }
		)
	end

	troposcatter(folder, Vector3.new(106, 0.2, -138), Vector3.new(1, 0, -0.3))
	troposcatter(folder, Vector3.new(138, 0.2, -140), Vector3.new(1, 0, 0.2))
	return folder
end

local function helipad(parent: Instance)
	local folder = Kit.folder(parent, "Helipad")
	local c = Vector3.new(118, 0, 29)
	Kit.post(folder, CFrame.new(c), 0.35, 34, W.Concrete, Enum.Material.Concrete, { Name = "Pad" })
	Kit.post(
		folder,
		CFrame.new(c + Vector3.new(0, 0.35, 0)),
		0.02,
		29,
		W.OffWhite,
		nil,
		{ Name = "Ring", Decor = true }
	)
	Kit.post(
		folder,
		CFrame.new(c + Vector3.new(0, 0.35, 0)),
		0.04,
		27.4,
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "RingInner", Decor = true }
	)
	local y = 0.39
	Kit.box(
		folder,
		CFrame.new(c),
		Vector3.new(-5, y, -6),
		Vector3.new(-3, y + 0.03, 6),
		W.OffWhite,
		nil,
		{ Name = "H", Decor = true }
	)
	Kit.box(
		folder,
		CFrame.new(c),
		Vector3.new(3, y, -6),
		Vector3.new(5, y + 0.03, 6),
		W.OffWhite,
		nil,
		{ Name = "H", Decor = true }
	)
	Kit.box(
		folder,
		CFrame.new(c),
		Vector3.new(-3, y, -1),
		Vector3.new(3, y + 0.03, 1),
		W.OffWhite,
		nil,
		{ Name = "H", Decor = true }
	)
	for i = 0, 7 do
		local a = i * math.pi / 4
		Kit.box(
			folder,
			CFrame.new(c + Vector3.new(math.cos(a) * 16.2, 0.35, math.sin(a) * 16.2)),
			Vector3.new(-0.4, 0, -0.4),
			Vector3.new(0.4, 0.5, 0.4),
			W.HazardYellow,
			Enum.Material.SmoothPlastic,
			{
				Name = "EdgeLight",
				Decor = true,
			}
		)
	end
	return folder
end

local function village(parent: Instance)
	local folder = Kit.folder(parent, "DistantVillage")
	local rng = Random.new(1961)
	local center = Vector3.new(360, 0, -330)
	Nature.hill(folder, center.X, center.Z, 150, 26, W.Grass)
	for i = 1, 9 do
		local p = center + Vector3.new(rng:NextNumber(-60, 60), 22, rng:NextNumber(-40, 40))
		local house = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local w, d, h = rng:NextNumber(10, 16), rng:NextNumber(10, 14), rng:NextNumber(8, 12)
		Kit.box(
			folder,
			house,
			Vector3.new(-w / 2, 0, -d / 2),
			Vector3.new(w / 2, h, d / 2),
			Color3.fromRGB(214, 206, 186),
			Enum.Material.Concrete,
			{
				Name = "House",
				Collide = false,
				Query = false,
			}
		)
		Architecture.gableRoof(
			folder,
			house,
			-w / 2,
			w / 2,
			-d / 2,
			d / 2,
			h,
			h * 0.7,
			0.8,
			Color3.fromRGB(128, 62, 48),
			Color3.fromRGB(214, 206, 186)
		)
	end
	-- church with a tall spire
	local church = CFrame.new(center + Vector3.new(10, 22, -6))
	Kit.box(
		folder,
		church,
		Vector3.new(-6, 0, -14),
		Vector3.new(6, 16, 14),
		Color3.fromRGB(224, 218, 200),
		Enum.Material.Concrete,
		{ Name = "Nave", Collide = false }
	)
	Architecture.gableRoof(
		folder,
		church,
		-6,
		6,
		-14,
		14,
		16,
		8,
		0.6,
		Color3.fromRGB(70, 74, 72),
		Color3.fromRGB(224, 218, 200)
	)
	Kit.box(
		folder,
		church,
		Vector3.new(-4, 0, 14),
		Vector3.new(4, 34, 22),
		Color3.fromRGB(224, 218, 200),
		Enum.Material.Concrete,
		{ Name = "Tower", Collide = false }
	)
	Kit.post(
		folder,
		church * CFrame.new(0, 34, 18),
		4,
		7,
		Color3.fromRGB(70, 74, 72),
		Enum.Material.Slate,
		{ Name = "Spire" }
	)
	Kit.post(
		folder,
		church * CFrame.new(0, 38, 18),
		5,
		4,
		Color3.fromRGB(70, 74, 72),
		Enum.Material.Slate,
		{ Name = "Spire" }
	)
	Kit.post(
		folder,
		church * CFrame.new(0, 43, 18),
		8,
		1.4,
		Color3.fromRGB(70, 74, 72),
		Enum.Material.Slate,
		{ Name = "Spire" }
	)
	return folder
end

function Perimeter.build(root: Instance)
	local folder = Kit.folder(root, "Perimeter")
	fence(folder)
	gate(folder)

	local towers = Kit.folder(folder, "GuardTowers")
	local p = Layout.Perimeter
	guardTower(towers, Vector3.new(p.MinX + 8, 0, p.MinZ + 8), math.rad(45))
	guardTower(towers, Vector3.new(p.MinX + 8, 0, p.MaxZ - 8), math.rad(-45))
	guardTower(towers, Vector3.new(p.MaxX - 8, 0, p.MaxZ - 8), math.rad(45))

	local housing = Kit.folder(folder, "Barracks")
	barracks(housing, Vector3.new(150, 0, -8), Vector3.new(1, 0, 0), 70, 26, "BLDG 201")
	barracks(housing, Vector3.new(-164, 0, -12), Vector3.new(-1, 0, 0), 80, 22, "BLDG 202")
	barracks(housing, Vector3.new(150, 0, 124), Vector3.new(1, 0, 0), 60, 24, "BLDG 203")

	vehicleShed(folder)
	waterTower(folder, Vector3.new(-162, 0, -128))
	commsCompound(folder)
	helipad(folder)

	-- landscape outside the fence
	local rng = Random.new(1983)
	local nature = Kit.folder(folder, "Landscape")
	Nature.forest(nature, Layout.Perimeter, 70, 170, {
		{ MinX = 196, MaxX = 224, MinZ = -400, MaxZ = 400 },
	}, rng)
	for i = 0, 11 do
		local a = i * math.pi / 6 + 0.2
		local r = rng:NextNumber(360, 430)
		Nature.hill(nature, math.cos(a) * r, math.sin(a) * r, rng:NextNumber(90, 150), rng:NextNumber(18, 34))
	end
	village(folder)
	return folder
end

return Perimeter
