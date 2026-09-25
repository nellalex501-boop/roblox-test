--!strict
-- Outdoor detailing: street furniture on the parade square, street lamps
-- along every sidewalk, the utility line on the outside road, the staff
-- parking lot, the parked helicopter, the motor pool in the vehicle shed,
-- the gate checkpoint, the canteen courtyard, the Hall of Commanders
-- benches and the barracks fronts.
--
-- Placement keeps entrances, crossings and prompt approaches clear (the
-- navigation specs re-check every walking route after detailing).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Effects = require(World.Effects)
local Kit = require(World.Kit)
local Nature = require(World.Nature)
local Props = require(World.Props)
local Vehicles = require(World.Vehicles)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Outdoor = {}

local PAVED = 0.3 -- plaza, courtyards, open zones
local SIDEWALK = 0.2
local ROAD = 0.1
local GRASS = 0

local FACE_NORTH = CFrame.Angles(0, 0, 0) -- front -Z
local FACE_SOUTH = CFrame.Angles(0, math.pi, 0)
local FACE_WEST = CFrame.Angles(0, math.pi / 2, 0)
local FACE_EAST = CFrame.Angles(0, -math.pi / 2, 0)

-- Marks a floor-standing prop for the grounding check in the Phase 4 spec.
local function grounded<T>(model: T): T
	(model :: any):SetAttribute("Grounded", true)
	return model
end

local function at(x: number, y: number, z: number, facing: CFrame?): CFrame
	return CFrame.new(x, y, z) * (facing or FACE_NORTH)
end

-- Parade square ---------------------------------------------------------------

local function plaza(parent: Instance)
	local folder = Kit.folder(parent, "Plaza")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local facing = if sz < 0 then FACE_SOUTH else FACE_NORTH
			grounded(Props.streetLamp(folder, at(sx * 63, PAVED, sz * 47, facing), true, 17))
		end
	end
	-- benches along the square's edges, between the road crossings
	local benches: { { x: number, z: number, facing: CFrame } } = {
		{ x = -63.5, z = -15, facing = FACE_EAST },
		{ x = -63.5, z = 11, facing = FACE_EAST },
		{ x = -63.5, z = -44, facing = FACE_EAST },
		{ x = 63.5, z = -40, facing = FACE_WEST },
		{ x = 63.5, z = 0, facing = FACE_WEST },
		{ x = 63.5, z = 36, facing = FACE_WEST },
		{ x = -44, z = -47.5, facing = FACE_SOUTH },
		{ x = 44, z = -47.5, facing = FACE_SOUTH },
		{ x = -44, z = 47.5, facing = FACE_NORTH },
		{ x = 38, z = 47.5, facing = FACE_NORTH },
	}
	for i, b in benches do
		-- the bench "front" (sitter's view) is its -Z: face the square
		grounded(Props.bench(folder, at(b.x, PAVED, b.z, b.facing), 6))
		if i % 2 == 0 then
			local side = (at(b.x, PAVED, b.z, b.facing) * CFrame.new(4.2, 0, 0)).Position
			grounded(Props.trashBin(folder, CFrame.new(side)))
		end
	end
	for _, x in { -46, 46 } do
		grounded(Props.loudspeakerPole(folder, at(x, PAVED, -44)))
	end
	grounded(Props.noticeBoard(folder, at(-28.5, PAVED, 26, FACE_EAST), "CAMP FULDA · STANDING ORDERS", {
		"OPS CENTER — MATCHMAKING (N)",
		"MAP ROOM — BATTLE MAPS (NW)",
		"GARAGE — UNITS & PAINT (W)",
		"COMMAND HQ — YOUR FILE (E)",
		"MISSION BOARD — ORDERS (S)",
	}))
	-- a bench and bin by the mission board shelter
	grounded(Props.bench(folder, at(-19, PAVED, 41), 6))
	grounded(Props.trashBin(folder, CFrame.new(-23.5, PAVED, 41.5)))
end

-- Streets ---------------------------------------------------------------------

local function streets(parent: Instance)
	local folder = Kit.folder(parent, "StreetLamps")
	local count = 0
	local function lamp(x: number, z: number, facing: CFrame)
		count += 1
		-- every other lamp carries a real light (kept cheap)
		grounded(Props.streetLamp(folder, at(x, SIDEWALK, z, facing), count % 2 == 1))
	end
	-- north road: lamps on the building side, heads over the road (the last
	-- one short of the guard booth's glass)
	for _, x in { -140, -120, -80, -45, 36, 60, 110, 150, 166 } do
		lamp(x, -65.5, FACE_SOUTH)
	end
	-- south road
	for _, x in { -135, -75, -42, 36, 66, 100, 134 } do
		lamp(x, 65.5, FACE_NORTH)
	end
	-- west road (between the garage doors) and east road
	for _, z in { -44, -15, 11, 40 } do
		lamp(-81.5, z, FACE_EAST)
	end
	-- (clear of the HQ porch and its flagpoles at z -35 and -5)
	for _, z in { -44, 6, 26, 46 } do
		lamp(81.5, z, FACE_WEST)
	end
	local signs = Kit.folder(parent, "RoadSigns")
	-- inside the gate, set back from the arch posts
	grounded(Props.roadSign(signs, at(178, GRASS, -48.2, FACE_EAST), "10", "KM/H · CAMP ROADS", "white"))
	grounded(Props.roadSign(signs, at(61, SIDEWALK, 66.5, FACE_NORTH), "P", "STAFF PARKING", "info"))
end

-- Utility line along the outside road ------------------------------------------

local function utilityLine(parent: Instance)
	local folder = Kit.folder(parent, "UtilityLine")
	local previous: { Vector3 }? = nil
	for z = -240, 240, 48 do
		local _, tips = Props.utilityPole(folder, at(220, GRASS, z), 22)
		local prev = previous
		if prev then
			for i = 1, 3 do
				Props.wire(folder, prev[i], tips[i], 1.4, 4)
			end
		end
		previous = tips
	end
	-- distant traffic hum from the public road
	local hum = Kit.part(
		folder,
		Vector3.new(1, 1, 1),
		CFrame.new(210, 3, 40),
		W.Charcoal,
		nil,
		{ Name = "TrafficAnchor", Transparency = 1, Decor = true }
	)
	Kit.anchor(hum, "Sound", "DistantTraffic")
end

-- Staff parking -------------------------------------------------------------------

local CIVIL_COLORS = {
	Color3.fromRGB(88, 104, 122),
	Color3.fromRGB(176, 164, 132),
	Color3.fromRGB(122, 64, 54),
	Color3.fromRGB(70, 84, 64),
	Color3.fromRGB(140, 138, 128),
}

-- Car lengths (for nose-in parking against the wheel stops).
local CAR_LENGTH = { CAR_SEDAN = 15.2, CAR_SMALL = 12.9, VAN = 15.6, JEEP = 12.9 }

local function parking(parent: Instance)
	local folder = Kit.folder(parent, "Parking")
	local P = Layout.Parking
	local field = P.Field
	local rng = Random.new(1979)
	-- wheel stops at the head of every stall
	local function stop(x: number, z: number)
		Kit.box(
			folder,
			CFrame.new(x, ROAD, z),
			Vector3.new(-2.1, 0, -0.35),
			Vector3.new(2.1, 0.3, 0.35),
			W.ConcreteLight,
			Enum.Material.Concrete,
			{ Name = "WheelStop" }
		)
	end
	for k = 0, P.NorthStalls - 1 do
		stop(P.NorthRowX + (k + 0.5) * P.StallWidth, field.MinZ + 1.4)
	end
	for k = 0, P.SouthStalls - 1 do
		stop(P.SouthRowX + (k + 0.5) * P.StallWidth, field.MaxZ - 1.4)
	end
	-- parked cars, nose-in to the stops, a little off-centre and askew
	type Stall = { row: string, stall: number, key: string, reversed: boolean? }
	local cars: { Stall } = {
		{ row = "north", stall = 0, key = "CAR_SEDAN" },
		{ row = "north", stall = 1, key = "CAR_SEDAN" },
		{ row = "north", stall = 3, key = "CAR_SMALL" },
		{ row = "north", stall = 4, key = "JEEP" },
		{ row = "south", stall = 0, key = "VAN" },
		{ row = "south", stall = 2, key = "CAR_SEDAN" },
		{ row = "south", stall = 3, key = "CAR_SMALL" },
		{ row = "south", stall = 5, key = "CAR_SEDAN", reversed = true },
		{ row = "south", stall = 7, key = "CAR_SMALL" },
	}
	for i, car in cars do
		local north = car.row == "north"
		local x = (if north then P.NorthRowX else P.SouthRowX) + (car.stall + 0.5) * P.StallWidth
		local length = CAR_LENGTH[car.key]
		local z = if north then field.MinZ + 1.9 + length / 2 else field.MaxZ - 1.9 - length / 2
		local facing = if north then FACE_NORTH else FACE_SOUTH
		if car.reversed then
			facing = facing * CFrame.Angles(0, math.pi, 0)
		end
		local paint: Vehicles.Paint = if car.key == "JEEP"
			then Vehicles.DefaultPaint.NATO
			else { Base = CIVIL_COLORS[(i - 1) % #CIVIL_COLORS + 1], Accent = W.DarkGrey }
		local cf = CFrame.new(x + rng:NextNumber(-0.35, 0.35), ROAD, z)
			* facing
			* CFrame.Angles(0, rng:NextNumber(-0.035, 0.035), 0)
		grounded(Vehicles.spawn(folder, car.key, car.key, cf, paint, Vector3.new(6.8, 6, 12.8)))
	end
	-- oil stains in the busy stalls
	for _, spot in
		{
			{ north = true, stall = 2 },
			{ north = true, stall = 5 },
			{ north = false, stall = 1 },
			{ north = false, stall = 4 },
			{ north = false, stall = 6 },
		}
	do
		local north = spot.north
		local x = (if north then P.NorthRowX else P.SouthRowX) + (spot.stall + 0.5) * P.StallWidth
		local z = if north then field.MinZ + 7 else field.MaxZ - 7
		Kit.part(
			folder,
			Vector3.new(rng:NextNumber(1.6, 2.6), 0.04, rng:NextNumber(2.4, 3.6)),
			CFrame.new(x + rng:NextNumber(-0.6, 0.6), ROAD + 0.02 + 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color3.fromRGB(58, 58, 56),
			Enum.Material.Asphalt,
			{ Name = "OilStain", Decor = true }
		)
	end
	-- lamps on the planting strips (never in the aisle), lit after dusk
	for _, x in { 70, 88, 106 } do
		grounded(Props.streetLamp(folder, at(x, GRASS, field.MinZ - 2.2, FACE_SOUTH), true, 15))
	end
	for _, x in { 56, 90 } do
		grounded(Props.streetLamp(folder, at(x, GRASS, field.MaxZ + 2.4, FACE_NORTH), true, 15))
	end
	grounded(Props.streetLamp(folder, at(P.Lane.MinX - 2.1, PAVED, 92, FACE_EAST), false, 13))
	-- hedge screening the lot from the Hall of Commanders' back wall
	Nature.hedge(folder, Vector3.new(60, GRASS, field.MinZ - 3.2), Vector3.new(110, GRASS, field.MinZ - 3.2), 2.2, 1.6)
	-- reserved stalls by the lane, and the rules at the lane mouth
	for k, title in { "RESERVED · CO", "RESERVED · XO", "RESERVED · CSM" } do
		local x = P.NorthRowX + (k - 0.5) * P.StallWidth
		local sign = Kit.model(folder, "ReservedSign")
		-- the post stands behind the plate (north), touching its back
		Kit.post(sign, CFrame.new(x, GRASS, field.MinZ - 1.36), 3.4, 0.16, W.Steel, Enum.Material.Metal, {
			Name = "Post",
			Decor = true,
		})
		Kit.sign(sign, CFrame.new(x, 3, field.MinZ - 1.25) * FACE_SOUTH, Vector2.new(2.6, 1.1), title, {
			Background = W.OffWhite,
			TextColor = W.Charcoal,
			Depth = 0.08,
			PixelsPerStud = 40,
			MaxDistance = 70,
		})
	end
	grounded(
		Props.roadSign(
			folder,
			at(P.Lane.MinX - 2.1, PAVED, Layout.Roads[2].MaxZ + 5, FACE_NORTH),
			"STAFF PARKING",
			"PRIVATE VEHICLES · 15 KM/H",
			"white"
		)
	)
	grounded(Props.trashBin(folder, at(P.Lane.MinX - 2.2, PAVED, field.MaxZ - 3)))
end

-- Helipad ----------------------------------------------------------------------

local function helipad(parent: Instance)
	local folder = Kit.folder(parent, "Helipad")
	local pad = Vector3.new(118, 0.35, 29)
	local heli =
		Vehicles.spawn(folder, "HELICOPTER", "HELICOPTER", at(pad.X, pad.Y, pad.Z, CFrame.Angles(0, math.rad(-120), 0)))
	grounded(heli)
	-- windsock beside the pad (clear of the lane behind the HQ): one
	-- tapered sleeve of overlapping hoops drooping from a pivot arm
	local sock = Kit.model(folder, "Windsock")
	local mast = Vector3.new(130, GRASS, 49)
	Kit.post(sock, at(mast.X, mast.Y, mast.Z), 10, 0.35, W.Steel, Enum.Material.Metal, { Name = "Pole", Shadow = true })
	local wind = Vector3.new(0.6, -0.2, 0.77).Unit
	local mouth = Vector3.new(mast.X, 9.6, mast.Z) + wind * 0.4
	Kit.part(
		sock,
		Vector3.new(0.15, 0.15, 0.5),
		CFrame.lookAt(Vector3.new(mast.X, 9.6, mast.Z), mouth),
		W.Steel,
		Enum.Material.Metal,
		{ Name = "PivotArm", Decor = true }
	)
	local stripes = { W.MutedRed, W.OffWhite, W.MutedRed, W.OffWhite }
	for i, color in stripes do
		local d = 1.5 - (i - 1) * 0.25
		local center = mouth + wind * (0.55 + (i - 1) * 1.0)
		Kit.part(
			sock,
			Vector3.new(d, d, 1.15),
			CFrame.lookAt(center, center + wind),
			color,
			Enum.Material.Fabric,
			{ Name = "Sock", Decor = true }
		)
	end
	grounded(sock)
	grounded(Props.drumCluster(folder, at(98, GRASS, 12), 3, W.MutedRed))
end

-- Motor pool (vehicle shed behind the Operations Center) ---------------------------

local function motorPool(parent: Instance)
	local folder = Kit.folder(parent, "MotorPool")
	local nato = Vehicles.DefaultPaint.NATO
	-- bays between the shed columns (every 12 studs from x = -54), facing out
	local bays: { { x: number, model: string, unit: string } } = {
		{ x = -48, model = "TRUCK_WEST", unit = "M35_TRUCK" },
		{ x = -36, model = "TRUCK_WEST", unit = "M35_TRUCK" },
		{ x = -24, model = "JEEP", unit = "M151_JEEP" },
		{ x = -12, model = "APC_TRACKED", unit = "M113" },
		{ x = 0, model = "TRUCK_WEST", unit = "M35_TRUCK" },
		{ x = 12, model = "JEEP", unit = "M151_JEEP" },
	}
	for _, bay in bays do
		local vehicle =
			Vehicles.spawn(folder, bay.unit, bay.model, at(bay.x, 0.3, -155, FACE_SOUTH), nato, Vector3.new(10, 9, 16))
		grounded(vehicle)
	end
	-- idling truck sound at the busiest bay
	local idle = Kit.part(
		folder,
		Vector3.new(1, 1, 1),
		CFrame.new(-36, 3, -150),
		W.Charcoal,
		nil,
		{ Name = "TruckIdleAnchor", Transparency = 1, Decor = true }
	)
	Kit.anchor(idle, "Sound", "TruckIdle")
	-- fuel point at the east end of the shed
	grounded(Props.fuelTank(folder, at(40, 0.3, -158, FACE_SOUTH)))
	grounded(Props.drumCluster(folder, at(32, 0.3, -151), 5))
	grounded(Props.jerrycans(folder, at(48, 0.3, -150), 5))
	-- spare tyres by the fuel point, clear of the parked trucks
	grounded(Props.tireStack(folder, at(47.5, 0.3, -163), 5))
	grounded(Props.tireStack(folder, at(51, 0.3, -162.6), 3))
	grounded(Props.floodlight(folder, at(0, GRASS, -142, FACE_NORTH), true))
	grounded(Props.crateStack(folder, at(26, 0.3, -162), "wide"))
end

-- Gate checkpoint ------------------------------------------------------------------

local function gate(parent: Instance)
	local folder = Kit.folder(parent, "Checkpoint")
	local g = Layout.Gate.Center
	-- sandbagged position outside the fence, north of the approach
	local post = CFrame.new(g.X + 8, GRASS, g.Z - 12)
	for i, angle in { -60, 0, 60 } do
		local seg = post * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -3.2)
		-- the middle run stacks 0.12 lower per course than its neighbours, so
		-- the overlapping corner bags never share a top or bottom face
		grounded(Props.sandbags(folder, seg, 4.6, if i == 2 then 3 else 2, if i == 2 then 0.52 else 0.64))
	end
	grounded(Props.jerseyBarrier(folder, at(g.X + 6, GRASS, g.Z + 9.5, FACE_WEST)))
	-- the security-area warning stands on the fence line south of the gate
	-- (the gate's own HALT plaque faces the approach)
	grounded(
		Props.roadSign(
			folder,
			at(g.X + 2.5, GRASS, g.Z + 17, FACE_EAST),
			"ACHTUNG",
			"MILITÄRISCHER SICHERHEITSBEREICH",
			"halt"
		)
	)
	grounded(Props.floodlight(folder, at(g.X - 3, GRASS, g.Z - 21, FACE_EAST), true))
end

-- Canteen courtyard ------------------------------------------------------------------

local function courtyard(parent: Instance)
	local folder = Kit.folder(parent, "Courtyard")
	local frame = Layout.frame(Layout.Zones.SocialArea)
	local function local_(x: number, z: number, rot: number?): CFrame
		return frame * CFrame.new(x, PAVED, z) * CFrame.Angles(0, rot or 0, 0)
	end
	for _, spot in { { -29, -14 }, { -18, -25 }, { -28, -35 }, { 29, -14 }, { 18, -25 }, { 28, -35 } } do
		grounded(Props.picnicTable(folder, local_(spot[1], spot[2], if spot[1] < 0 then 0.06 else -0.06)))
	end
	-- two lamps light the courtyard at night (off by day)
	grounded(Props.streetLamp(folder, local_(-38, -6, math.rad(-135)), true, 12))
	grounded(Props.streetLamp(folder, local_(38, -40, math.rad(45)), true, 12))
	grounded(Props.fieldKitchen(folder, local_(37.5, -24)))
	local pipe = folder:FindFirstChild("StovePipe", true)
	if pipe and pipe:IsA("BasePart") then
		Kit.anchor(pipe, "Smoke", "Stove")
		Effects.smoke(pipe, { Rate = 1.5, Size = 1, Rise = 1.8, Opacity = 0.35 })
	end
	-- planters along the walk to the door, parasols over two tables; the
	-- planters hold clipped shrubs (tree crowns here would hide the canteen
	-- sign from the plaza)
	local rng = Random.new(1985)
	for _, spot in { { -8, -12 }, { 8, -12 }, { -8, -30 }, { 8, -30 } } do
		grounded(Nature.planter(folder, local_(spot[1], spot[2]).Position, rng, 4, true))
	end
	for _, spot in { { -18, -25 }, { 18, -25 } } do
		local parasol = Kit.model(folder, "Parasol")
		Kit.post(parasol, local_(spot[1], spot[2]), 7.4, 0.2, W.SteelDark, Enum.Material.Metal, { Name = "Pole" })
		Kit.post(
			parasol,
			local_(spot[1], spot[2]) * CFrame.new(0, 7.1, 0),
			0.35,
			7,
			Color3.fromRGB(168, 150, 108),
			Enum.Material.Fabric,
			{ Name = "Canopy", Decor = true }
		)
		grounded(parasol)
	end
	-- bins and empties by the kitchen's service door (behind the canteen)
	for _, x in { -21, -23.4 } do
		grounded(Props.trashBin(folder, frame * CFrame.new(x, GRASS, -72.5)))
	end
	grounded(Props.crateStack(folder, frame * CFrame.new(-9.5, GRASS, -72.8)))
	grounded(Props.crateStack(folder, local_(24, -40.5)))
	-- radio standing on the crates (not a floor prop)
	Props.radio(folder, local_(24, -40.5) * CFrame.new(-0.2, 3.6, 0.1))
	-- (clear of the posts of the canteen's name boards)
	for _, x in { -34, 34 } do
		grounded(Props.bench(folder, local_(x, -4.4), 6))
	end
	-- a bike rack row: every other bike faces the other way and sits half
	-- a length further on, so the handlebars never clash
	for i = 0, 3 do
		local flip = i % 2 == 1
		grounded(Props.bicycle(folder, local_(9 + i * 1.3, if flip then -40.7 else -41.3, if flip then math.pi else 0)))
	end
	grounded(Props.trashBin(folder, local_(6, -41)))
	grounded(Props.trashBin(folder, local_(-37, -22)))
	grounded(Props.phoneBox(folder, local_(-35, -41.6, math.pi)))
	-- canteen chatter drifting out of the open doors
	local chatter = Kit.part(
		folder,
		Vector3.new(1, 1, 1),
		frame * CFrame.new(0, 5, -46),
		W.Charcoal,
		nil,
		{ Name = "CanteenAnchor", Transparency = 1, Decor = true }
	)
	Kit.anchor(chatter, "Sound", "Canteen")
	-- canteen chimney smoke
	local chimney = Kit.part(
		folder,
		Vector3.new(1, 1, 1),
		frame * CFrame.new(15.5, 19, -57),
		W.Charcoal,
		nil,
		{ Name = "ChimneyAnchor", Transparency = 1, Decor = true }
	)
	Kit.anchor(chimney, "Smoke", "Chimney")
	Effects.smoke(chimney, { Rate = 2, Size = 1.8 })
end

-- Hall of Commanders ------------------------------------------------------------------

local function hallOfCommanders(parent: Instance)
	local folder = Kit.folder(parent, "HallOfCommanders")
	local frame = Layout.frame(Layout.Zones.Leaderboards)
	for _, x in { -21, -7, 7, 21 } do
		grounded(Props.bench(folder, frame * CFrame.new(x, PAVED, -18), 6))
	end
	for _, x in { -34, 34 } do
		grounded(Props.bollardLamp(folder, frame * CFrame.new(x, PAVED, -8), true))
	end
end

-- Barracks fronts ------------------------------------------------------------------------

-- Benches, a bin and bicycles in front of a barracks block. Positions are
-- along the facade (local X), chosen per block to stay clear of neighbours
-- and of the three door steps (at 0 and +-length/4, 6 wide).
type BarracksDressing = { benches: { number }, bin: number, bikes: number }

local function barracksFront(parent: Instance, facade: Vector3, inward: Vector3, dressing: BarracksDressing)
	local frame = CFrame.lookAt(facade, facade + inward)
	local folder = Kit.folder(parent, "BarracksFront")
	-- everything stands on the footpath along the front (0 .. 3 studs out)
	for _, x in dressing.benches do
		-- against the wall between the doors, sitters looking out
		grounded(Props.bench(folder, frame * CFrame.new(x, SIDEWALK, 1.4) * FACE_SOUTH, 6))
	end
	grounded(Props.trashBin(folder, frame * CFrame.new(dressing.bin, SIDEWALK, 1.2)))
	-- two bicycles parked end to end along the wall
	for i = 0, 1 do
		grounded(Props.bicycle(folder, frame * CFrame.new(dressing.bikes + i * 5.2, SIDEWALK, 1.05) * FACE_WEST))
	end
end

function Outdoor.build(parent: Instance)
	local folder = Kit.folder(parent, "Outdoor")
	plaza(folder)
	streets(folder)
	utilityLine(folder)
	parking(folder)
	helipad(folder)
	motorPool(folder)
	gate(folder)
	courtyard(folder)
	hallOfCommanders(folder)
	-- benches midway between the doors (at 0 and +-length/4)
	local dressings: { BarracksDressing } = {
		{ benches = { -8.75, 8.75 }, bin = -26, bikes = 23.4 },
		{ benches = { -10, 10 }, bin = -30, bikes = 26 },
		{ benches = { -7, 7 }, bin = -21, bikes = 19.8 },
	}
	for i, b in Layout.Barracks do
		barracksFront(folder, b.Facade, b.Inward, dressings[i])
	end
end

return Outdoor
