--!strict
-- Procedural low-poly vehicles (showcase + set dressing).
--
-- Every model is built in a local frame: origin on the ground under the
-- vehicle centre, facing -Z (LookVector). Scale is ~60% of real life so
-- vehicles read well next to Roblox characters. Real game models can
-- replace these: put a Model named after the unit id (or model key) in
-- ServerStorage.LobbyAssets.Units and Vehicles.spawn() uses it instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(script.Parent.Kit)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Vehicles = {}

export type Paint = { Base: Color3, Accent: Color3 }

local BLACK = W.Rubber
local METAL = W.SteelDark

Vehicles.DefaultPaint = {
	NATO = { Base = Color3.fromRGB(86, 94, 58), Accent = Color3.fromRGB(64, 70, 44) },
	PACT = { Base = Color3.fromRGB(80, 98, 60), Accent = Color3.fromRGB(58, 72, 44) },
	CIVIL = { Base = W.Beige, Accent = W.DarkGrey },
} :: { [string]: Paint }

-- Helpers ---------------------------------------------------------------

type Ctx = { model: Model, frame: CFrame, paint: Paint }

local function box(ctx: Ctx, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, name: string?): Part
	return Kit.part(
		ctx.model,
		size,
		ctx.frame * CFrame.new(pos),
		color,
		material or Enum.Material.SmoothPlastic,
		{ Name = name or "Hull" }
	)
end

local function boxRot(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	return Kit.part(
		ctx.model,
		size,
		ctx.frame * cf,
		color,
		material or Enum.Material.SmoothPlastic,
		{ Name = name or "Hull" }
	)
end

-- Wedge whose slope faces `dir` (-1 = front/-Z, +1 = back/+Z).
local function wedge(ctx: Ctx, size: Vector3, pos: Vector3, dir: number, color: Color3, name: string?): WedgePart
	local rot = if dir < 0 then CFrame.new() else CFrame.Angles(0, math.pi, 0)
	return Kit.wedge(
		ctx.model,
		size,
		ctx.frame * CFrame.new(pos) * rot,
		color,
		Enum.Material.SmoothPlastic,
		{ Name = name or "Glacis" }
	)
end

-- Wedge sloping down toward the front, sitting upside down (lower glacis).
local function wedgeUnder(ctx: Ctx, size: Vector3, pos: Vector3, dir: number, color: Color3)
	local rot = if dir < 0 then CFrame.Angles(0, 0, math.pi) else CFrame.Angles(0, math.pi, math.pi)
	return Kit.wedge(
		ctx.model,
		size,
		ctx.frame * CFrame.new(pos) * rot,
		color,
		Enum.Material.SmoothPlastic,
		{ Name = "LowerGlacis" }
	)
end

local function wheel(ctx: Ctx, pos: Vector3, diameter: number, width: number, hub: Color3?)
	local cf = ctx.frame * CFrame.new(pos)
	Kit.cylinder(ctx.model, width, diameter, cf, BLACK, Enum.Material.SmoothPlastic, { Name = "Wheel" })
	-- hub caps stand 0.06 proud of the tyre on both sides
	Kit.cylinder(ctx.model, width + 0.12, diameter * 0.55, cf, hub or ctx.paint.Accent, Enum.Material.SmoothPlastic, {
		Name = "Hub",
		Decor = true,
	})
end

local function barrel(ctx: Ctx, from: Vector3, length: number, diameter: number, color: Color3?)
	local cf = ctx.frame * CFrame.new(from + Vector3.new(0, 0, -length / 2)) * CFrame.Angles(0, math.pi / 2, 0)
	return Kit.cylinder(
		ctx.model,
		length,
		diameter,
		cf,
		color or ctx.paint.Accent,
		Enum.Material.SmoothPlastic,
		{ Name = "Barrel" }
	)
end

-- Track assembly on one side: belt, road wheels, sprocket/idler, skirt.
local function tracks(
	ctx: Ctx,
	side: number,
	length: number,
	width: number,
	height: number,
	halfWidth: number,
	wheels: number,
	skirt: boolean
)
	local x = side * (halfWidth - width / 2)
	-- the belt runs down under the road wheels to the ground (its lower run
	-- carries the vehicle), up to the return run at 0.86 of the height
	box(
		ctx,
		Vector3.new(width, height * 0.86, length - height * 0.7),
		Vector3.new(x, height * 0.43, 0),
		BLACK,
		Enum.Material.SmoothPlastic,
		"Track"
	)
	for _, z in { -(length / 2 - height * 0.45), length / 2 - height * 0.45 } do
		-- sprocket and idler faces 0.05 outside the belt
		Kit.cylinder(
			ctx.model,
			width + 0.1,
			height * 0.8,
			ctx.frame * CFrame.new(x, height * 0.5, z),
			BLACK,
			Enum.Material.SmoothPlastic,
			{
				Name = "Sprocket",
			}
		)
	end
	local span = length - height * 1.5
	for i = 0, wheels - 1 do
		local z = -span / 2 + span * (i / math.max(wheels - 1, 1))
		-- road wheel faces 0.15 outside the belt (0.1 beyond the sprockets)
		Kit.cylinder(
			ctx.model,
			width + 0.3,
			height * 0.62,
			ctx.frame * CFrame.new(x, height * 0.4, z),
			ctx.paint.Accent,
			Enum.Material.SmoothPlastic,
			{
				Name = "RoadWheel",
				Decor = true,
			}
		)
	end
	if skirt then
		box(
			ctx,
			Vector3.new(0.25, height * 0.45, length * 0.94),
			Vector3.new(side * (halfWidth + 0.2), height * 0.78, 0),
			ctx.paint.Base,
			nil,
			"Skirt"
		)
	end
end

local function antenna(ctx: Ctx, pos: Vector3, height: number)
	Kit.part(
		ctx.model,
		Vector3.new(0.12, height, 0.12),
		ctx.frame * CFrame.new(pos + Vector3.new(0, height / 2, 0)),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{
			Name = "Antenna",
			Decor = true,
		}
	)
end

-- Models --------------------------------------------------------------

local Builders: { [string]: (Ctx) -> () } = {}

Builders.MBT_WEST = function(ctx)
	local p = ctx.paint
	tracks(ctx, -1, 19, 2.4, 2.6, 6.2, 7, true)
	tracks(ctx, 1, 19, 2.4, 2.6, 6.2, 7, true)
	box(ctx, Vector3.new(7.4, 2, 17), Vector3.new(0, 2.6, 0.6), p.Base)
	box(ctx, Vector3.new(12.4, 0.6, 17.4), Vector3.new(0, 3.3, 0.4), p.Base, nil, "Deck")
	wedge(ctx, Vector3.new(12.3, 1.1, 2.6), Vector3.new(0, 3.1, -9.4), -1, p.Base)
	wedgeUnder(ctx, Vector3.new(7.4, 1.4, 1.8), Vector3.new(0, 1.9, -8.9), -1, p.Base)
	box(ctx, Vector3.new(12.2, 1.4, 1.2), Vector3.new(0, 3.1, 8.9), p.Accent, nil, "Rear")
	-- flat angular turret
	box(ctx, Vector3.new(8.6, 2.1, 9.6), Vector3.new(0, 4.65, 1.2), p.Base, nil, "Turret")
	wedge(ctx, Vector3.new(8.6, 2.1, 2.6), Vector3.new(0, 4.65, -4.8), -1, p.Base, "TurretFront")
	box(ctx, Vector3.new(9.6, 1.2, 3.2), Vector3.new(0, 4.4, 7.4), p.Accent, nil, "Bustle")
	box(ctx, Vector3.new(1.6, 1.3, 1.2), Vector3.new(0, 4.8, -6.4), p.Accent, nil, "Mantlet")
	barrel(ctx, Vector3.new(0, 4.8, -6.8), 11.5, 0.62)
	Kit.cylinder(
		ctx.model,
		1.6,
		0.9,
		ctx.frame * CFrame.new(0, 4.8, -11.5) * CFrame.Angles(0, math.pi / 2, 0),
		p.Accent,
		Enum.Material.SmoothPlastic,
		{
			Name = "Evacuator",
			Decor = true,
		}
	)
	box(ctx, Vector3.new(1.6, 0.9, 1.6), Vector3.new(2.4, 6.1, 1.8), p.Accent, nil, "Cupola")
	box(ctx, Vector3.new(0.3, 0.3, 2.2), Vector3.new(2.4, 6.7, 0.9), METAL, nil, "MG")
	antenna(ctx, Vector3.new(-3.6, 5.7, 5.6), 5)
	antenna(ctx, Vector3.new(3.6, 5.7, 5.6), 4)
end

Builders.MBT_EAST = function(ctx)
	local p = ctx.paint
	tracks(ctx, -1, 18, 2.4, 2.8, 5.8, 6, false)
	tracks(ctx, 1, 18, 2.4, 2.8, 5.8, 6, false)
	box(ctx, Vector3.new(7, 1.8, 15.4), Vector3.new(0, 2.6, 0.6), p.Base)
	box(ctx, Vector3.new(11.6, 0.5, 16), Vector3.new(0, 3.25, 0.5), p.Base, nil, "Deck")
	wedge(ctx, Vector3.new(11.6, 1, 2.6), Vector3.new(0, 3, -8.8), -1, p.Base)
	wedgeUnder(ctx, Vector3.new(7, 1.4, 1.8), Vector3.new(0, 1.9, -8.2), -1, p.Base)
	-- low cast turret: a turret ring, a faceted body with a sloped front
	-- and sloped cheeks, so it reads as a dome rather than a stack of discs
	local turret = ctx.frame * CFrame.new(0, 3.5, 0.6)
	Kit.cylinder(
		ctx.model,
		1,
		8.4,
		turret * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		p.Base,
		Enum.Material.SmoothPlastic,
		{ Name = "Turret" }
	)
	box(ctx, Vector3.new(4.6, 1.3, 5.2), Vector3.new(0, 5.15, 1.4), p.Base, nil, "TurretTop")
	wedge(ctx, Vector3.new(4.6, 1.3, 2.4), Vector3.new(0, 5.15, -2.4), -1, p.Base, "TurretFront")
	for _, side in { -1, 1 } do
		-- cheek wedge along the top's side, sloping down and outward (its
		-- low edge faces +-X)
		Kit.wedge(
			ctx.model,
			Vector3.new(5.2, 1.3, 1.6),
			ctx.frame * CFrame.new(side * 3.1, 5.15, 1.4) * CFrame.Angles(0, -side * math.pi / 2, 0),
			p.Base,
			Enum.Material.SmoothPlastic,
			{ Name = "TurretCheek" }
		)
	end
	box(ctx, Vector3.new(1.4, 1.1, 1.4), Vector3.new(0, 4.9, -4.2), p.Accent, nil, "Mantlet")
	barrel(ctx, Vector3.new(0, 4.9, -4.7), 12.5, 0.6)
	box(ctx, Vector3.new(1.3, 0.5, 1.3), Vector3.new(-1.2, 6.05, 2.2), p.Accent, nil, "Hatch")
	box(ctx, Vector3.new(1.0, 0.9, 1.3), Vector3.new(1.3, 6.2, 0.6), p.Accent, nil, "Sight")
	-- rear fuel drums (a classic Soviet silhouette cue)
	for _, x in { -2.2, 2.2 } do
		Kit.cylinder(
			ctx.model,
			3.2,
			1.6,
			ctx.frame * CFrame.new(x, 4.1, 8.6),
			p.Accent,
			Enum.Material.SmoothPlastic,
			{ Name = "FuelDrum" }
		)
	end
	-- side stowage boxes
	for _, side in { -1, 1 } do
		box(ctx, Vector3.new(0.9, 0.9, 5), Vector3.new(side * 5.3, 3.9, 2.4), p.Accent, nil, "Stowage")
	end
	antenna(ctx, Vector3.new(-1.8, 5.8, 3.4), 5)
end

Builders.IFV_WEST = function(ctx)
	local p = ctx.paint
	tracks(ctx, -1, 17, 2.2, 2.4, 5.6, 6, true)
	tracks(ctx, 1, 17, 2.2, 2.4, 5.6, 6, true)
	box(ctx, Vector3.new(11.2, 3.6, 13.4), Vector3.new(0, 4.1, 1.4), p.Base, nil, "Hull")
	wedge(ctx, Vector3.new(11.2, 3.6, 3.4), Vector3.new(0, 4.1, -7.1), -1, p.Base)
	box(ctx, Vector3.new(11.2, 0.4, 16.8), Vector3.new(0, 2.1, -0.3), p.Accent, nil, "Belly")
	-- offset turret with cannon and TOW launcher
	box(ctx, Vector3.new(4.6, 1.5, 5.2), Vector3.new(1.3, 6.65, 1.2), p.Base, nil, "Turret")
	wedge(ctx, Vector3.new(4.6, 1.5, 1.4), Vector3.new(1.3, 6.65, -2.1), -1, p.Base, "TurretFront")
	barrel(ctx, Vector3.new(0.6, 6.6, -2.6), 5.4, 0.36)
	box(ctx, Vector3.new(1.4, 1.1, 2.8), Vector3.new(4.3, 6.9, 1.2), p.Accent, nil, "TOW")
	box(ctx, Vector3.new(2.4, 2.6, 0.3), Vector3.new(0, 4.4, 8.2), p.Accent, nil, "Ramp")
	antenna(ctx, Vector3.new(-4, 5.9, 6.6), 4.5)
end

Builders.IFV_EAST = function(ctx)
	local p = ctx.paint
	tracks(ctx, -1, 17, 2.2, 2.2, 5.4, 6, false)
	tracks(ctx, 1, 17, 2.2, 2.2, 5.4, 6, false)
	box(ctx, Vector3.new(10.8, 2.2, 10.4), Vector3.new(0, 3.1, 3), p.Base, nil, "Hull")
	-- long, very sloped front
	wedge(ctx, Vector3.new(10.8, 2.2, 6.4), Vector3.new(0, 3.1, -5.4), -1, p.Base)
	box(ctx, Vector3.new(10.8, 0.4, 16.8), Vector3.new(0, 1.8, 0), p.Accent, nil, "Belly")
	local turret = ctx.frame * CFrame.new(0, 4.2, 0.6)
	Kit.cylinder(
		ctx.model,
		1.3,
		5,
		turret * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.pi / 2),
		p.Base,
		Enum.Material.SmoothPlastic,
		{ Name = "Turret" }
	)
	barrel(ctx, Vector3.new(0, 5, -1.4), 6.8, 0.26)
	box(ctx, Vector3.new(0.7, 0.7, 2.4), Vector3.new(1.8, 5.6, 0), p.Accent, nil, "ATGM")
	for _, x in { -2.8, 2.8 } do
		box(ctx, Vector3.new(1.2, 1, 1.2), Vector3.new(x, 4.6, 6.2), p.Accent, nil, "Hatch")
	end
	antenna(ctx, Vector3.new(-2, 5, 3.4), 4)
end

Builders.APC_TRACKED = function(ctx)
	local p = ctx.paint
	tracks(ctx, -1, 15, 2, 2.2, 5.2, 5, false)
	tracks(ctx, 1, 15, 2, 2.2, 5.2, 5, false)
	box(ctx, Vector3.new(10.4, 4, 12.2), Vector3.new(0, 4, 1.2), p.Base, nil, "Hull")
	wedge(ctx, Vector3.new(10.4, 4, 2.6), Vector3.new(0, 4, -6.2), -1, p.Base)
	box(ctx, Vector3.new(2.2, 0.7, 2.2), Vector3.new(-2.6, 6.35, -1.6), p.Accent, nil, "Cupola")
	box(ctx, Vector3.new(0.35, 0.35, 3), Vector3.new(-2.6, 6.8, -3.4), METAL, nil, "MG")
	box(ctx, Vector3.new(4.4, 3.2, 0.3), Vector3.new(0, 3.8, 7.4), p.Accent, nil, "Ramp")
	antenna(ctx, Vector3.new(4, 6, 5.6), 4.5)
end

Builders.SPAAG_WEST = function(ctx)
	Builders.APC_TRACKED(ctx)
	local p = ctx.paint
	box(ctx, Vector3.new(4.4, 2.2, 4.4), Vector3.new(0, 7.1, 1.2), p.Base, nil, "Turret")
	for i = 0, 5 do
		local a = i * math.pi / 3
		barrel(ctx, Vector3.new(math.cos(a) * 0.4, 7.4 + math.sin(a) * 0.4, -1), 5.4, 0.18, METAL)
	end
	Kit.cylinder(
		ctx.model,
		0.4,
		2.6,
		ctx.frame * CFrame.new(1.8, 8.9, 2.4) * CFrame.Angles(0, math.pi / 2, math.rad(80)),
		W.OffWhite,
		Enum.Material.SmoothPlastic,
		{
			Name = "RadarDish",
		}
	)
end

Builders.SPAAG_EAST = function(ctx)
	local p = ctx.paint
	tracks(ctx, -1, 16, 2.2, 2.4, 5.6, 6, false)
	tracks(ctx, 1, 16, 2.2, 2.4, 5.6, 6, false)
	box(ctx, Vector3.new(11.2, 2.4, 13.6), Vector3.new(0, 3.2, 0.8), p.Base, nil, "Hull")
	wedge(ctx, Vector3.new(11.2, 2.4, 2.4), Vector3.new(0, 3.2, -7.2), -1, p.Base)
	box(ctx, Vector3.new(9.8, 2.6, 8.6), Vector3.new(0, 5.7, 1.6), p.Base, nil, "Turret")
	wedge(ctx, Vector3.new(9.8, 2.6, 1.8), Vector3.new(0, 5.7, -3.5), -1, p.Base, "TurretFront")
	for _, x in { -1.6, -0.6, 0.6, 1.6 } do
		barrel(ctx, Vector3.new(x, 6.2, -3.8), 6, 0.24, METAL)
	end
	box(ctx, Vector3.new(4.4, 2.4, 0.3), Vector3.new(0, 8.6, 4.4), W.OffWhite, nil, "RadarDish")
	box(ctx, Vector3.new(0.4, 1.2, 0.4), Vector3.new(0, 7.4, 4.4), METAL, nil, "RadarMast")
end

Builders.APC_WHEELED = function(ctx)
	local p = ctx.paint
	for _, z in { -6.6, -2.4, 2.4, 6.6 } do
		for _, side in { -1, 1 } do
			wheel(ctx, Vector3.new(side * 4.6, 1.3, z), 2.6, 1.3)
		end
	end
	box(ctx, Vector3.new(8.4, 2.6, 15.2), Vector3.new(0, 3.3, 0.6), p.Base, nil, "Hull")
	wedge(ctx, Vector3.new(8.4, 2.6, 3), Vector3.new(0, 3.3, -8.4), -1, p.Base)
	wedge(ctx, Vector3.new(8.4, 1.4, 2), Vector3.new(0, 2.7, 9.2), 1, p.Base, "RearSlope")
	-- angled upper side panels (boat hull look)
	for _, side in { -1, 1 } do
		boxRot(
			ctx,
			Vector3.new(0.5, 1.6, 14),
			CFrame.new(side * 3.9, 4.9, 0.8) * CFrame.Angles(0, 0, side * math.rad(20)),
			p.Base,
			nil,
			"SidePanel"
		)
	end
	box(ctx, Vector3.new(6.8, 0.8, 13), Vector3.new(0, 5.2, 1), p.Base, nil, "Roof")
	local turret = ctx.frame * CFrame.new(0, 5.6, -2.4)
	Kit.cylinder(
		ctx.model,
		1.2,
		2.8,
		turret * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		p.Accent,
		Enum.Material.SmoothPlastic,
		{ Name = "Turret" }
	)
	barrel(ctx, Vector3.new(0, 6.3, -3.4), 3.6, 0.3)
	antenna(ctx, Vector3.new(-2.4, 5.6, 6), 4)
end

Builders.SCOUT_WHEELED = function(ctx)
	local p = ctx.paint
	for _, z in { -3.8, 3.8 } do
		for _, side in { -1, 1 } do
			wheel(ctx, Vector3.new(side * 3.9, 1.3, z), 2.6, 1.2)
		end
	end
	box(ctx, Vector3.new(7, 2.4, 10.4), Vector3.new(0, 3, 0.6), p.Base, nil, "Hull")
	wedge(ctx, Vector3.new(7, 2.4, 2.6), Vector3.new(0, 3, -5.8), -1, p.Base)
	box(ctx, Vector3.new(5.8, 1, 7), Vector3.new(0, 4.7, 1.2), p.Base, nil, "Upper")
	wedge(ctx, Vector3.new(5.8, 1, 1.6), Vector3.new(0, 4.7, -3.1), -1, p.Base, "Windscreen")
	local turret = ctx.frame * CFrame.new(0, 5.2, 1.2)
	Kit.cylinder(
		ctx.model,
		1.4,
		2.6,
		turret * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2),
		p.Accent,
		Enum.Material.SmoothPlastic,
		{ Name = "Turret" }
	)
	barrel(ctx, Vector3.new(0, 6, 0.2), 2.6, 0.24)
	antenna(ctx, Vector3.new(-2.2, 5.2, 4.2), 3.6)
end

local function truck(ctx: Ctx, cabRound: boolean)
	local p = ctx.paint
	for _, z in { -5.4, 3.2, 6.6 } do
		for _, side in { -1, 1 } do
			wheel(ctx, Vector3.new(side * 3.7, 1.6, z), 3.2, 1.3, METAL)
		end
	end
	box(ctx, Vector3.new(2.2, 0.8, 18), Vector3.new(0, 2.4, 0.8), W.Charcoal, nil, "Chassis")
	-- cab + hood
	box(ctx, Vector3.new(7, 4.4, 3.8), Vector3.new(0, 5.2, -3.4), p.Base, nil, "Cab")
	box(ctx, Vector3.new(6.4, 1.8, 0.2), Vector3.new(0, 6.3, -5.35), W.Glass, Enum.Material.Glass, "Windscreen")
	box(ctx, Vector3.new(5.6, 2.6, 4.2), Vector3.new(0, 4.1, -7.3), p.Base, nil, "Hood")
	if cabRound then
		Kit.cylinder(
			ctx.model,
			5.6,
			2.6,
			ctx.frame * CFrame.new(0, 4.1, -9.4),
			p.Base,
			Enum.Material.SmoothPlastic,
			{ Name = "HoodNose" }
		)
	else
		box(ctx, Vector3.new(5, 2.3, 0.4), Vector3.new(0, 4.05, -9.5), W.Charcoal, nil, "Grille")
	end
	for _, side in { -1, 1 } do
		box(ctx, Vector3.new(1.6, 0.4, 3.8), Vector3.new(side * 3.4, 3.4, -5.6), p.Accent, nil, "Fender")
	end
	-- cargo bed with canvas cover
	box(ctx, Vector3.new(7.4, 1.2, 10.8), Vector3.new(0, 3.4, 4.2), p.Accent, nil, "Bed")
	box(
		ctx,
		Vector3.new(7.4, 4.2, 10.4),
		Vector3.new(0, 6.1, 4.4),
		p.Base:Lerp(W.Beige, 0.15),
		Enum.Material.Fabric,
		"Canvas"
	)
	-- roof ends 0.05 inside the canvas box ends
	Kit.cylinder(
		ctx.model,
		10.3,
		7.4,
		ctx.frame * CFrame.new(0, 7.6, 4.4) * CFrame.Angles(0, math.pi / 2, 0),
		p.Base:Lerp(W.Beige, 0.15),
		Enum.Material.Fabric,
		{
			Name = "CanvasRoof",
		}
	)
end

Builders.TRUCK_WEST = function(ctx)
	truck(ctx, false)
end

Builders.TRUCK_EAST = function(ctx)
	truck(ctx, true)
end

-- Civil and light vehicles at true proportions (0.3 m per stud): a
-- saloon is ~16 studs long, a hatchback ~12, a van ~15.
local LAMP = Color3.fromRGB(222, 218, 196)
local TAIL = Color3.fromRGB(150, 44, 38)

-- Headlights, tail lights, grille and number plates on a body whose ends
-- are at +-halfL (front at -Z), lamps at height y.
local function carDetails(ctx: Ctx, halfL: number, halfW: number, y: number, grille: boolean?)
	for _, side in { -1, 1 } do
		box(ctx, Vector3.new(1, 0.5, 0.1), Vector3.new(side * (halfW - 0.8), y, -halfL - 0.05), LAMP, nil, "Headlight")
		box(
			ctx,
			Vector3.new(0.9, 0.45, 0.1),
			Vector3.new(side * (halfW - 0.75), y + 0.05, halfL + 0.05),
			TAIL,
			nil,
			"TailLight"
		)
	end
	if grille ~= false then
		box(ctx, Vector3.new(halfW, 0.5, 0.1), Vector3.new(0, y, -halfL - 0.05), W.Charcoal, nil, "Grille")
	end
	for _, z in { -halfL - 0.04, halfL + 0.04 } do
		box(ctx, Vector3.new(1.6, 0.42, 0.08), Vector3.new(0, y - 0.62, z), W.OffWhite, nil, "Plate")
	end
end

Builders.JEEP = function(ctx)
	local p = ctx.paint
	-- M151: 5.4 wide, 11.2 long, wheelbase 7.3
	for _, z in { -3.65, 3.65 } do
		for _, side in { -1, 1 } do
			wheel(ctx, Vector3.new(side * 2.3, 1.15, z), 2.3, 0.9)
		end
	end
	box(ctx, Vector3.new(5, 1.6, 11.2), Vector3.new(0, 2.3, 0), p.Base, nil, "Body")
	box(ctx, Vector3.new(4.6, 0.8, 3.6), Vector3.new(0, 3.5, -3.4), p.Base, nil, "Hood")
	-- mudguards over the wheels
	for _, z in { -3.65, 3.65 } do
		for _, side in { -1, 1 } do
			box(ctx, Vector3.new(1.1, 0.25, 2.8), Vector3.new(side * 2.3, 3.2, z), p.Accent, nil, "Fender")
		end
	end
	box(ctx, Vector3.new(4.6, 0.2, 0.2), Vector3.new(0, 5.5, -1.5), W.Charcoal, nil, "WindscreenFrame")
	box(ctx, Vector3.new(4.4, 1.6, 0.1), Vector3.new(0, 4.6, -1.5), W.Glass, Enum.Material.Glass, "Windscreen")
	for _, x in { -1.1, 1.1 } do
		box(ctx, Vector3.new(1.5, 1.3, 1.4), Vector3.new(x, 3.75, 0.6), W.BrownDark, Enum.Material.Fabric, "Seat")
	end
	box(ctx, Vector3.new(1, 2.1, 2.1), Vector3.new(0, 3.3, 6.1), W.Charcoal, nil, "Spare")
	for _, side in { -1, 1 } do
		box(ctx, Vector3.new(0.9, 0.9, 0.1), Vector3.new(side * 1.7, 2.8, -5.65), LAMP, nil, "Headlight")
	end
	antenna(ctx, Vector3.new(2.1, 3.1, 4.6), 5)
end

Builders.CAR_SEDAN = function(ctx)
	local p = ctx.paint
	-- saloon: 5.9 wide, 15.2 long over the bumpers, 4.8 high, wheelbase 8.8;
	-- the tyres stand 0.07 proud of the body sides (no shared face)
	for _, z in { -4.4, 4.4 } do
		for _, side in { -1, 1 } do
			wheel(ctx, Vector3.new(side * 2.62, 1.05, z), 2.1, 0.8, METAL)
		end
	end
	box(ctx, Vector3.new(5.9, 1.7, 14.6), Vector3.new(0, 2.15, 0), p.Base, nil, "Body")
	box(ctx, Vector3.new(5.4, 1.6, 6.6), Vector3.new(0, 3.8, 0.7), p.Base, nil, "Cabin")
	box(ctx, Vector3.new(5.5, 1.1, 6.2), Vector3.new(0, 3.85, 0.7), W.Glass, Enum.Material.Glass, "Windows")
	for _, z in { -7.45, 7.45 } do
		box(ctx, Vector3.new(6, 0.4, 0.3), Vector3.new(0, 1.5, z), W.Steel, Enum.Material.Metal, "Bumper")
	end
	carDetails(ctx, 7.3, 2.95, 2.45)
end

Builders.CAR_SMALL = function(ctx)
	local p = ctx.paint
	-- hatchback: 5.4 wide, 12.3 long, 4.7 high, wheelbase 8; the cabin runs
	-- to the tail
	for _, z in { -4, 4 } do
		for _, side in { -1, 1 } do
			wheel(ctx, Vector3.new(side * 2.37, 0.95, z), 1.9, 0.8, W.OffWhite)
		end
	end
	box(ctx, Vector3.new(5.4, 1.7, 12.3), Vector3.new(0, 1.95, 0), p.Base, nil, "Body")
	box(ctx, Vector3.new(5, 1.7, 7.9), Vector3.new(0, 3.65, 1.85), p.Base, nil, "Cabin")
	box(ctx, Vector3.new(5.1, 1.1, 7.5), Vector3.new(0, 3.7, 1.85), W.Glass, Enum.Material.Glass, "Windows")
	for _, z in { -6.3, 6.3 } do
		box(ctx, Vector3.new(5.5, 0.35, 0.3), Vector3.new(0, 1.25, z), W.OffWhite, nil, "Bumper")
	end
	carDetails(ctx, 6.15, 2.7, 2.25)
end

Builders.VAN = function(ctx)
	local p = ctx.paint
	-- bus: 5.8 wide, 15 long, 6.4 high, wheelbase 8, two-tone
	for _, z in { -4, 4 } do
		for _, side in { -1, 1 } do
			wheel(ctx, Vector3.new(side * 2.55, 1.05, z), 2.1, 0.9, W.OffWhite)
		end
	end
	box(ctx, Vector3.new(5.8, 5, 15), Vector3.new(0, 3.8, 0), p.Base, nil, "Body")
	box(ctx, Vector3.new(5.9, 2.2, 15.1), Vector3.new(0, 2, 0), p.Accent, nil, "LowerBody")
	box(ctx, Vector3.new(5.4, 1.7, 0.2), Vector3.new(0, 4.9, -7.55), W.Glass, Enum.Material.Glass, "Windscreen")
	box(ctx, Vector3.new(5.95, 1.4, 10.4), Vector3.new(0, 5, 1.6), W.Glass, Enum.Material.Glass, "SideWindows")
	for _, z in { -7.7, 7.7 } do
		box(ctx, Vector3.new(6, 0.4, 0.3), Vector3.new(0, 1.2, z), W.OffWhite, nil, "Bumper")
	end
	carDetails(ctx, 7.55, 2.9, 2.3, false)
end

Builders.HELICOPTER = function(ctx)
	local p = ctx.paint
	-- skids resting on the ground, on two struts each side
	for _, side in { -1, 1 } do
		box(ctx, Vector3.new(0.4, 0.4, 13), Vector3.new(side * 3.4, 0.2, 0), METAL, nil, "Skid")
		for _, z in { -3, 3 } do
			box(ctx, Vector3.new(0.3, 2, 0.3), Vector3.new(side * 3, 1.3, z), METAL, nil, "SkidStrut")
		end
	end
	-- cabin, cockpit with a glazed nose, door openings and windows
	box(ctx, Vector3.new(6, 4.6, 10), Vector3.new(0, 4.5, 0.5), p.Base, nil, "Fuselage")
	box(ctx, Vector3.new(5.6, 1.8, 3), Vector3.new(0, 3.1, -6), p.Base, nil, "Chin")
	wedge(ctx, Vector3.new(5.6, 2.8, 3), Vector3.new(0, 5.4, -6), -1, W.Glass, "Nose")
	for _, side in { -1, 1 } do
		box(
			ctx,
			Vector3.new(0.06, 1.5, 2.6),
			Vector3.new(side * 3.03, 5.3, -3),
			W.Glass,
			Enum.Material.Glass,
			"CockpitWindow"
		)
		box(ctx, Vector3.new(0.06, 2.8, 3.6), Vector3.new(side * 3.03, 4.4, 1.4), W.Charcoal, nil, "DoorOpening")
	end
	-- engine deck, rotor mast
	box(ctx, Vector3.new(3, 1.4, 5), Vector3.new(0, 7.5, 0.6), p.Accent, nil, "Engine")
	box(ctx, Vector3.new(1.4, 1.2, 1.6), Vector3.new(0, 7.3, 4.2), p.Accent, nil, "Exhaust")
	box(ctx, Vector3.new(0.5, 0.9, 0.5), Vector3.new(0, 8.5, 0), METAL, nil, "Mast")
	-- tapering tail boom, fin and stabiliser
	box(ctx, Vector3.new(1.9, 2, 6), Vector3.new(0, 5.6, 8.4), p.Base, nil, "TailBoom")
	box(ctx, Vector3.new(1.2, 1.3, 7.6), Vector3.new(0, 5.8, 15), p.Base, nil, "TailBoom")
	box(ctx, Vector3.new(0.4, 4, 2.4), Vector3.new(0, 7.4, 18.6), p.Base, nil, "Fin")
	box(ctx, Vector3.new(4, 0.3, 1.2), Vector3.new(0, 5.8, 15.6), p.Base, nil, "Stabiliser")
	local rotor = Kit.model(ctx.model, "Rotor")
	local hub = Kit.part(
		rotor,
		Vector3.new(0.8, 1.2, 0.8),
		ctx.frame * CFrame.new(0, 9, 0),
		METAL,
		Enum.Material.SmoothPlastic,
		{ Name = "RotorHub" }
	)
	rotor.PrimaryPart = hub
	-- the blade sits well below the hub's top (no shared plane)
	Kit.part(
		rotor,
		Vector3.new(30, 0.15, 1.2),
		ctx.frame * CFrame.new(0, 9.4, 0),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{
			Name = "Blade",
			Decor = true,
		}
	)
	-- tail rotor on a short hub out of the fin's right side
	-- the hub ends where the rotor starts (their side faces never overlap)
	box(ctx, Vector3.new(0.45, 0.35, 0.35), Vector3.new(0.425, 7.4, 18.8), METAL, nil, "TailHub")
	Kit.part(
		rotor,
		Vector3.new(0.2, 3.4, 0.4),
		ctx.frame * CFrame.new(0.75, 7.4, 18.8),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{
			Name = "TailRotor",
			Decor = true,
		}
	)
end

Vehicles.Builders = Builders

local function sameColor(a: Color3, b: Color3): boolean
	return math.round(a.R * 255) == math.round(b.R * 255)
		and math.round(a.G * 255) == math.round(b.G * 255)
		and math.round(a.B * 255) == math.round(b.B * 255)
end

local function assetFor(key: string): Model?
	local folder = ServerStorage:FindFirstChild("LobbyAssets")
	local units = folder and folder:FindFirstChild("Units")
	local found = units and units:FindFirstChild(key)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

-- Builds (or clones an asset override for) a vehicle. `id` is the unit id
-- (checked first for an override), `modelKey` the procedural builder.
function Vehicles.spawn(
	parent: Instance,
	id: string,
	modelKey: string,
	frame: CFrame,
	paint: Paint?,
	maxSize: Vector3?
): Model
	local override = assetFor(id) or assetFor(modelKey)
	if override then
		local clone = override:Clone()
		clone.Name = id
		if maxSize then
			local _, size = clone:GetBoundingBox()
			local factor = math.min(maxSize.X / size.X, maxSize.Y / size.Y, maxSize.Z / size.Z, 1)
			if factor < 1 then
				clone:ScaleTo(clone:GetScale() * factor)
			end
		end
		clone:PivotTo(frame)
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				-- showcase copies must not run game logic from the RTS
				d:Destroy()
			end
		end
		clone:SetAttribute("AssetOverride", true)
		clone.Parent = parent
		return clone
	end
	local builder = Builders[modelKey]
	assert(builder, "No vehicle builder for " .. modelKey)
	local model = Instance.new("Model")
	model.Name = id
	local ctx: Ctx = { model = model, frame = frame, paint = paint or Vehicles.DefaultPaint.NATO }
	builder(ctx)
	-- tag painted parts so clients can preview other paint schemes
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if sameColor(d.Color, ctx.paint.Base) then
				d:SetAttribute("Paint", "Base")
			elseif sameColor(d.Color, ctx.paint.Accent) then
				d:SetAttribute("Paint", "Accent")
			end
		end
	end
	model:SetAttribute("VehicleModel", modelKey)
	model.Parent = parent
	return model
end

return Vehicles
