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

-- Chain-link security fence between two ground points: round steel posts,
-- a woven mesh panel with a top rail and bottom tension wire, outriggers
-- leaning outward with three strands of barbed wire, and a tall invisible
-- collider. `skipFirst` / `skipLast` leave out the posts a neighbouring run
-- already stands at the corners (no doubled corner posts).
local function fenceRun(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	spacing: number,
	skipFirst: boolean?,
	skipLast: boolean?
)
	local delta = b - a
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local mid = (a + b) / 2
	-- outriggers lean away from the base
	local outward = Vector3.new(-dir.Z, 0, dir.X)
	if outward:Dot(Vector3.new(mid.X, 0, mid.Z)) < 0 then
		outward = -outward
	end
	local count = math.max(1, math.floor(length / spacing))
	for i = if skipFirst then 1 else 0, if skipLast then count - 1 else count do
		local p = a + delta * (i / count)
		Kit.post(parent, CFrame.new(p), 8.4, 0.45, W.Steel, Enum.Material.Metal, { Name = "FencePost" })
		local arm = beam(
			parent,
			p + Vector3.new(0, 8.2, 0),
			p + Vector3.new(0, 8.2, 0) + outward * 1.5 + Vector3.new(0, 1.5, 0),
			0.16,
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Outrigger", Decor = true }
		)
		arm.CastShadow = false
	end
	local along = CFrame.fromMatrix(mid, dir, UP)
	local mesh = Kit.part(
		parent,
		Vector3.new(length, 7.8, 0.08),
		along * CFrame.new(0, 4, 0),
		Color3.fromRGB(150, 152, 146),
		Enum.Material.Fabric,
		{ Name = "ChainLink", Transparency = 0.55, Collide = false, Query = false, Shadow = false }
	)
	mesh:SetAttribute("ChainLink", true)
	Kit.cylinder(parent, length, 0.18, along * CFrame.new(0, 7.9, 0), W.Steel, Enum.Material.Metal, {
		Name = "TopRail",
		Decor = true,
	})
	local low = Vector3.new(0, 0.3, 0) + outward * 0.12
	beam(parent, a + low, b + low, 0.06, W.SteelDark, Enum.Material.Metal, {
		Name = "TensionWire",
		Decor = true,
	})
	for k = 1, 3 do
		local offset = Vector3.new(0, 8.2 + k * 0.45, 0) + outward * (k * 0.45)
		beam(parent, a + offset, b + offset, 0.06, W.SteelDark, Enum.Material.Metal, {
			Name = "Barbed",
			Decor = true,
		})
	end
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
	fenceRun(folder, ne, Vector3.new(p.MaxX, y, gate.Center.Z - gate.Width / 2 - 2), 10, true)
	fenceRun(folder, Vector3.new(p.MaxX, y, gate.Center.Z + gate.Width / 2 + 2), se, 10)
	fenceRun(folder, se, sw, 10, true)
	fenceRun(folder, sw, nw, 10, true, true)
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
			Vector3.new(0.8, 12.9, 0.8),
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
	-- the name hangs under the arch, readable from both sides: one board
	-- faces the base, a second faces arriving traffic
	for _, side in { -1, 1 } do
		local sx = x - 3 + side * 0.8
		local signCf = CFrame.lookAt(Vector3.new(sx, 9.6, g.Center.Z), Vector3.new(sx + side * 10, 9.6, g.Center.Z))
		Kit.sign(folder, signCf, Vector2.new(17, 3.4), Perimeter.GameTitle, {
			Background = W.SignGreen,
			Subtitle = if side > 0 then "VISITORS REPORT TO THE GUARD" else Perimeter.BaseName,
			Stripe = W.MutedRed,
			PixelsPerStud = 30,
		})
	end
	for _, dz in { -6, 6 } do
		Kit.box(
			folder,
			CFrame.new(x - 3, 0, g.Center.Z + dz),
			Vector3.new(-1.1, 11.3, -0.1),
			Vector3.new(1.1, 11.6, 0.1),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "SignHanger", Decor = true }
		)
	end

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
	-- HALT stands outside the gate, facing the traffic arriving from the
	-- public road
	local plaque = Kit.model(folder, "HaltSign")
	local pp = Vector3.new(x + 7, 0, roadMaxZ + 2.5)
	Kit.post(plaque, CFrame.new(pp), 6.4, 0.35, W.Steel, Enum.Material.Metal, { Name = "Post" })
	Kit.sign(
		plaque,
		CFrame.lookAt(pp + Vector3.new(0.4, 5.2, 0), pp + Vector3.new(5, 5.2, 0)),
		Vector2.new(5.4, 2.4),
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
		-- the X braces sit 0.45 above the Z braces so they never share faces
		local yz = y + 0.45
		for _, seg in
			{
				{ Vector3.new(-s, yz, -s), Vector3.new(s, yz, -s) },
				{ Vector3.new(-s, yz, s), Vector3.new(s, yz, s) },
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
			{ Vector3.new(-4.4, h + 0.6, -4), Vector3.new(-4, h + 3, 4) },
			{ Vector3.new(4, h + 0.6, -4), Vector3.new(4.4, h + 3, 4) },
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

local function barracks(parent: Instance, spec: Layout.Barrack)
	local model = Kit.model(parent, "Barracks")
	local frame = CFrame.lookAt(spec.Facade, spec.Facade + spec.Inward)
	local length, depth = spec.Length, spec.Depth
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
	-- ground floor: window runs between the three doors (and their canopies)
	local doors = { -halfL / 2, 0, halfL / 2 }
	local edges = {
		-halfL + 1,
		doors[1] - 3.6,
		doors[1] + 3.6,
		doors[2] - 3.6,
		doors[2] + 3.6,
		doors[3] - 3.6,
		doors[3] + 3.6,
		halfL - 1,
	}
	for i = 1, #edges, 2 do
		local a, b = edges[i], edges[i + 1]
		local n = math.floor((b - a) / 7)
		if n > 0 then
			Architecture.windowRow(model, frame, a, b, 0, 1, 3.6, 7.4, n, 2.8, style)
		end
	end
	Architecture.windowRow(model, frame, -halfL + 1, halfL - 1, 0, 1, 9.6, 13.2, count, 2.8, style)
	Architecture.windowRow(model, frame, -halfL + 1, halfL - 1, -depth, -1, 9.6, 13.2, count, 2.8, style)
	-- the ground floor at the back gets plain windows (no doors there)
	Architecture.plainWindows(model, frame, -halfL + 1, halfL - 1, -depth, -1, 3.6, 7.4, count, 2.8, style)
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
		-- white frame (jambs and head), a glazed upper panel and a handle
		for _, side in { -1, 1 } do
			Kit.box(
				model,
				frame,
				Vector3.new(x + side * 2, 0.6, 0),
				Vector3.new(x + side * 2.35, 7.6, 0.35),
				W.OffWhite,
				Enum.Material.Wood,
				{ Name = "DoorFrame", Decor = true }
			)
		end
		Kit.box(
			model,
			frame,
			Vector3.new(x - 2.35, 7.6, 0),
			Vector3.new(x + 2.35, 7.95, 0.35),
			W.OffWhite,
			Enum.Material.Wood,
			{ Name = "DoorFrame", Decor = true }
		)
		Kit.box(
			model,
			frame,
			Vector3.new(x - 1.2, 5, 0.24),
			Vector3.new(x + 1.2, 6.9, 0.3),
			W.Glass,
			Enum.Material.Glass,
			{ Name = "DoorGlass", Decor = true }
		)
		Kit.box(
			model,
			frame,
			Vector3.new(x + 1.35, 3.7, 0.24),
			Vector3.new(x + 1.6, 4.1, 0.42),
			W.Steel,
			Enum.Material.Metal,
			{ Name = "DoorHandle", Decor = true }
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
	-- the number plate on the solid wall between the corner and the first
	-- ground-floor window (the run laid out above: 2.8 wide windows with
	-- 0.3 surrounds), or on the windowless gable beside that corner
	local runSpan = edges[2] - edges[1]
	local runCount = math.floor(runSpan / 7)
	local firstWindow = if runCount > 0 then edges[1] + (runSpan - runCount * 2.8) / (runCount + 1) - 0.3 else edges[2]
	local left, right = -halfL + 0.5, firstWindow - 0.2
	local plateW = math.min(3.4, right - left)
	local plateAt = if spec.NumberOnGable
		then frame * CFrame.new(-halfL - 0.055, 6, -plateW / 2 - 1.5) * CFrame.Angles(0, math.pi / 2, 0)
		else Kit.facingOut(frame, Vector3.new((left + right) / 2, 6, 0.055))
	local plate = Kit.sign(model, plateAt, Vector2.new(plateW, plateW * 0.6), spec.Number, {
		Background = W.OffWhite,
		TextColor = W.Charcoal,
		Depth = 0.15,
		PixelsPerStud = 40,
	})
	plate.Name = "BuildingNumber"
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
	-- head beam across the two A-frames' apexes; the reflector hangs from it
	beam(
		model,
		(frame * CFrame.new(-6.4, 16, -1)).Position,
		(frame * CFrame.new(6.4, 16, -1)).Position,
		0.6,
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "HeadBeam" }
	)
	-- slightly curved reflector made of three panels, their backs against
	-- the head beam
	for i, a in { -0.28, 0, 0.28 } do
		Kit.part(
			model,
			Vector3.new(6.4, 18, 0.5),
			frame * CFrame.new(math.sin(a) * 6.6, 12, -0.9 + (1 - math.cos(a)) * 6) * CFrame.Angles(math.rad(-8), a, 0),
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
	-- the horn is held in front of the reflector on a boom and a stay
	beam(
		model,
		(frame * CFrame.new(0, 12, -1.0)).Position,
		(frame * CFrame.new(0, 12, -4.8)).Position,
		0.4,
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "FeedBoom" }
	)
	beam(
		model,
		(frame * CFrame.new(0, 5.6, -0.1)).Position,
		(frame * CFrame.new(0, 11.5, -6.4)).Position,
		0.3,
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "FeedStay" }
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
	-- 6-stud chain-link runs; skipFirst / skipLast leave out the posts a
	-- neighbouring run already stands at the corners
	local function run(a: Vector3, b: Vector3, skipFirst: boolean?, skipLast: boolean?)
		local delta = b - a
		local count = math.max(1, math.floor(delta.Magnitude / 8))
		for i = if skipFirst then 1 else 0, if skipLast then count - 1 else count do
			local p = a + delta * (i / count)
			Kit.post(fenceFolder, CFrame.new(p), 6.2, 0.4, W.Steel, Enum.Material.Metal, { Name = "Post" })
		end
		local mid = (a + b) / 2
		local along = CFrame.fromMatrix(mid, delta.Unit, UP)
		Kit.part(
			fenceFolder,
			Vector3.new(delta.Magnitude, 5.6, 0.08),
			along * CFrame.new(0, 3.05, 0),
			Color3.fromRGB(150, 152, 146),
			Enum.Material.Fabric,
			{ Name = "ChainLink", Transparency = 0.55, Collide = false, Query = false, Shadow = false }
		)
		Kit.cylinder(fenceFolder, delta.Magnitude, 0.16, along * CFrame.new(0, 5.9, 0), W.Steel, Enum.Material.Metal, {
			Name = "TopRail",
			Decor = true,
		})
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
	run(Vector3.new(x1, 0, z1), Vector3.new(x1, 0, z0), true)
	run(Vector3.new(x1, 0, z0), Vector3.new(x0, 0, z0), true)
	run(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), true, true)

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
	-- one window each side of the door
	Architecture.windowRow(folder, shack, -7, -2.4, 0, 1, 4, 7, 1, 2.6, { Frame = W.DarkGrey })
	Architecture.windowRow(folder, shack, 2.4, 7, 0, 1, 4, 7, 1, 2.6, { Frame = W.DarkGrey })
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
	-- lattice mast in the aviation bands: seven sections, red at the foot
	-- and the top (truss lengths stay multiples of 2)
	local bottom = 1.2
	for i = 0, 6 do
		local h = if i == 6 then 14 else 12
		local truss = Instance.new("TrussPart")
		truss.Name = "RadioMast"
		truss.Anchored = true
		truss.CanCollide = false
		truss.CanTouch = false
		truss.Size = Vector3.new(2, h, 2)
		truss.CFrame = CFrame.new(mastBase + Vector3.new(0, bottom + h / 2, 0))
		truss.Color = if i % 2 == 0 then Color3.fromRGB(176, 74, 60) else Color3.fromRGB(220, 218, 208)
		truss.Material = Enum.Material.Metal
		truss.Parent = folder
		bottom += h
	end
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
	-- three guy anchors, placed clear of the shack and the dish footings
	for _, a in { -0.35, 1.744, 3.3 } do
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
	-- painted ring and H, each layer 0.06 above the one below
	Kit.post(folder, CFrame.new(c + Vector3.new(0, 0.3, 0)), 0.11, 29, W.OffWhite, nil, { Name = "Ring", Decor = true })
	Kit.post(
		folder,
		CFrame.new(c + Vector3.new(0, 0.3, 0)),
		0.17,
		27.4,
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "RingInner", Decor = true }
	)
	local y = 0.43
	Kit.box(
		folder,
		CFrame.new(c),
		Vector3.new(-5, y, -6),
		Vector3.new(-3, y + 0.1, 6),
		W.OffWhite,
		nil,
		{ Name = "H", Decor = true }
	)
	Kit.box(
		folder,
		CFrame.new(c),
		Vector3.new(3, y, -6),
		Vector3.new(5, y + 0.1, 6),
		W.OffWhite,
		nil,
		{ Name = "H", Decor = true }
	)
	Kit.box(
		folder,
		CFrame.new(c),
		Vector3.new(-3, y, -1),
		Vector3.new(3, y + 0.1, 1),
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

-- The public road beyond the gate: the straight stretch past the gate
-- (Layout "OutsideRoad") bends east at both ends and runs off into the
-- woods, instead of stopping in the grass. Returns the centre lines.
local function publicRoad(parent: Instance): { { Vector3 } }
	local folder = Kit.folder(parent, "PublicRoad")
	local straight = Layout.Roads[#Layout.Roads]
	local x = (straight.MinX + straight.MaxX) / 2
	local width = straight.MaxX - straight.MinX
	-- (a wide bend: the north branch passes south of the village hill)
	local radius = 200
	local lines: { { Vector3 } } = { { Vector3.new(x, 0, straight.MinZ), Vector3.new(x, 0, straight.MaxZ) } }
	for _, dir in { -1, 1 } do
		local z0 = if dir < 0 then straight.MinZ else straight.MaxZ
		local center = Vector3.new(x + radius, 0, z0)
		local points: { Vector3 } = {}
		local steps = 9
		for i = 0, steps do
			-- from the road end (pointing away from the gate) round to east
			local a = math.pi - (i / steps) * (math.pi / 2)
			table.insert(points, center + Vector3.new(math.cos(a), 0, dir * math.sin(a)) * radius)
		end
		table.insert(points, points[#points] + Vector3.new(480, 0, 0))
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			-- consecutive slabs overlap a little at the bends and alternate
			-- 0.06 in height, so no two share a top face
			local top = if i % 2 == 0 then 0.1 else 0.16
			local mid = (a + b) / 2
			Kit.part(
				folder,
				Vector3.new(width, top, (b - a).Magnitude + 1.2),
				CFrame.lookAt(Vector3.new(mid.X, top / 2, mid.Z), Vector3.new(b.X, top / 2, b.Z)),
				W.Asphalt,
				Enum.Material.Asphalt,
				{ Name = "Road", Collide = false, Query = false, Shadow = false }
			)
		end
		table.insert(lines, points)
	end
	return lines
end

-- Shortest distance from (x, z) to any of the road centre lines.
local function distanceToRoad(lines: { { Vector3 } }, x: number, z: number): number
	local best = math.huge
	local p = Vector3.new(x, 0, z)
	for _, line in lines do
		for i = 1, #line - 1 do
			local a, b = line[i], line[i + 1]
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			best = math.min(best, (a + ab * t - p).Magnitude)
		end
	end
	return best
end

-- Trees along the public road's bends and the first stretch beyond, on
-- alternating sides, so the road disappears into the woods (the far
-- stretches are behind the hills).
local function roadsideWoods(parent: Instance, lines: { { Vector3 } }, rng: Random)
	local folder = Kit.folder(parent, "RoadsideWoods")
	for index, line in lines do
		-- (the straight stretch past the gate stays open)
		if index > 1 then
			local travelled = 0
			local side = 1
			for i = 1, #line - 1 do
				local a, b = line[i], line[i + 1]
				local ab = b - a
				local len = math.min(ab.Magnitude, 140)
				local dir = ab.Unit
				local across = Vector3.new(-dir.Z, 0, dir.X)
				local d = 0
				while d < len do
					d += rng:NextNumber(18, 30)
					side = -side
					local p = a + dir * math.min(d, len) + across * side * rng:NextNumber(13, 30)
					travelled += 1
					if distanceToRoad(lines, p.X, p.Z) > 11 then
						local base = CFrame.new(p.X, 0, p.Z)
						if rng:NextNumber() < 0.8 then
							Nature.pine(folder, base, rng:NextNumber(16, 30), rng)
						else
							Nature.leafy(folder, base, rng:NextNumber(15, 22), rng)
						end
					end
				end
			end
		end
	end
end

local function village(parent: Instance)
	local folder = Kit.folder(parent, "DistantVillage")
	local rng = Random.new(1961)
	local center = Vector3.new(360, 0, -330)
	Nature.hill(folder, center.X, center.Z, 150, 26, W.Grass)
	local placed: { Vector3 } = { center + Vector3.new(10, 22, 2) } -- the church
	for _ = 1, 9 do
		local p = center + Vector3.new(rng:NextNumber(-60, 60), 22, rng:NextNumber(-40, 40))
		for _ = 1, 20 do
			local clear = true
			for _, q in placed do
				if (q - p).Magnitude < 24 then
					clear = false
				end
			end
			if clear then
				break
			end
			p = center + Vector3.new(rng:NextNumber(-60, 60), 22, rng:NextNumber(-40, 40))
		end
		table.insert(placed, p)
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
	for _, spec in Layout.Barracks do
		barracks(housing, spec)
	end

	vehicleShed(folder)
	waterTower(folder, Vector3.new(-162, 0, -128))
	commsCompound(folder)
	helipad(folder)

	-- landscape outside the fence
	local rng = Random.new(1983)
	local nature = Kit.folder(folder, "Landscape")
	local road = publicRoad(nature)
	Nature.forest(nature, Layout.Perimeter, 55, 125, {
		{ MinX = 196, MaxX = 224, MinZ = -400, MaxZ = 400 },
	}, rng)
	roadsideWoods(nature, road, rng)
	-- two rings of irregular hills close the view on every side (the ground
	-- plane's edge stays hidden behind them), kept clear of the road
	for ring, spec in { { 0, 12, 360, 430, 90, 140, 18, 32 }, { 1, 16, 560, 700, 120, 190, 30, 55 } } do
		local count = spec[2]
		for i = 0, count - 1 do
			local a = (i + ring * 0.5) * math.pi * 2 / count + 0.2
			local r = rng:NextNumber(spec[3], spec[4])
			local radius = rng:NextNumber(spec[5], spec[6])
			local x, z = math.cos(a) * r, math.sin(a) * r
			if distanceToRoad(road, x, z) > radius + 30 then
				Nature.ridge(nature, x, z, radius, rng:NextNumber(spec[7], spec[8]), rng)
			end
		end
	end
	village(folder)
	return folder
end

return Perimeter
