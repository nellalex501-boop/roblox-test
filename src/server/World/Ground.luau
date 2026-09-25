--!strict
-- Ground plane, parade square, road network and sidewalks.
-- Heights: grass 0.0, asphalt 0.1, plaza/sidewalk 0.3, building floors 0.6.
-- Painted markings stand 0.06 proud of the surface they are painted on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Ground = {}

Ground.GrassTop = 0
Ground.RoadTop = 0.1
Ground.PavedTop = 0.3
Ground.FloorTop = 0.6

local function rectBox(
	parent: Instance,
	rect: Layout.Rect,
	bottom: number,
	top: number,
	color: Color3,
	material: Enum.Material,
	name: string?
): Part
	return Kit.box(
		parent,
		CFrame.new(),
		Vector3.new(rect.MinX, bottom, rect.MinZ),
		Vector3.new(rect.MaxX, top, rect.MaxZ),
		color,
		material,
		{ Name = name }
	)
end
Ground.rectBox = rectBox

function Ground.build(parent: Instance, detailed: boolean)
	local folder = Kit.folder(parent, "Ground")

	-- Grass base (the largest part Roblox allows), reaching well past the
	-- outer ring of hills, so its edge is never in view from the base.
	local grass = Kit.part(
		folder,
		Vector3.new(2048, 4, 2048),
		CFrame.new(0, Ground.GrassTop - 2, 0),
		W.Grass,
		Enum.Material.Grass,
		{ Name = "Grass" }
	)
	grass.CastShadow = false

	-- Roads: the cross roads run through; the others stop at their edges
	-- (butt joints, so no two asphalt slabs overlap at the junctions)
	local roads = Kit.folder(folder, "Roads")
	for _, road in Layout.Roads do
		local rect = { MinX = road.MinX, MaxX = road.MaxX, MinZ = road.MinZ, MaxZ = road.MaxZ }
		if (road.MaxZ - road.MinZ) > (road.MaxX - road.MinX) then
			for _, other in Layout.Roads do
				local crossRoad = (other.MaxX - other.MinX) > (other.MaxZ - other.MinZ)
				if crossRoad and other.MinX < rect.MaxX and other.MaxX > rect.MinX then
					if other.MaxZ > rect.MinZ and other.MinZ <= rect.MinZ then
						rect.MinZ = other.MaxZ
					end
					if other.MinZ < rect.MaxZ and other.MaxZ >= rect.MaxZ then
						rect.MaxZ = other.MinZ
					end
				end
			end
		end
		local part = rectBox(roads, rect, Ground.GrassTop, Ground.RoadTop, W.Asphalt, Enum.Material.Asphalt, road.Name)
		part.CastShadow = false
	end

	-- Parade square with a kerb band.
	local plaza = Layout.Plaza
	local square = Kit.folder(folder, "ParadeSquare")
	local kerbs = {
		{ MinX = plaza.MinX - 2, MaxX = plaza.MaxX + 2, MinZ = plaza.MinZ - 2, MaxZ = plaza.MinZ },
		{ MinX = plaza.MinX - 2, MaxX = plaza.MaxX + 2, MinZ = plaza.MaxZ, MaxZ = plaza.MaxZ + 2 },
		{ MinX = plaza.MinX - 2, MaxX = plaza.MinX, MinZ = plaza.MinZ, MaxZ = plaza.MaxZ },
		{ MinX = plaza.MaxX, MaxX = plaza.MaxX + 2, MinZ = plaza.MinZ, MaxZ = plaza.MaxZ },
	}
	for _, rect in kerbs do
		local kerb = rectBox(
			square,
			rect,
			Ground.RoadTop,
			Ground.PavedTop - 0.02,
			W.ConcreteDark,
			Enum.Material.Concrete,
			"Kerb"
		)
		kerb.CastShadow = false
	end

	if detailed then
		-- Concrete slabs with dark joints showing between them.
		local slab = 12
		local cols = math.floor((plaza.MaxX - plaza.MinX) / slab)
		local rows = math.floor((plaza.MaxZ - plaza.MinZ) / slab)
		local slabW = (plaza.MaxX - plaza.MinX) / cols
		local slabD = (plaza.MaxZ - plaza.MinZ) / rows
		local rng = Random.new(1987)
		for c = 0, cols - 1 do
			for r = 0, rows - 1 do
				local tone = rng:NextNumber(-0.022, 0.022)
				local base = W.ConcreteLight:Lerp(W.Concrete, if (c + r) % 2 == 0 then 0.2 else 0.45)
				local color = Color3.new(
					math.clamp(base.R + tone, 0, 1),
					math.clamp(base.G + tone, 0, 1),
					math.clamp(base.B + tone, 0, 1)
				)
				local x0 = plaza.MinX + c * slabW + 0.15
				local z0 = plaza.MinZ + r * slabD + 0.15
				local part = Kit.box(
					square,
					CFrame.new(),
					Vector3.new(x0, Ground.PavedTop - 0.3, z0),
					Vector3.new(x0 + slabW - 0.3, Ground.PavedTop, z0 + slabD - 0.3),
					color,
					Enum.Material.Concrete,
					{ Name = "Slab", Shadow = false }
				)
				part.CastShadow = false
			end
		end
		-- Joint fill below the slabs (visible through the gaps).
		local joints = rectBox(
			square,
			plaza,
			Ground.PavedTop - 0.32,
			Ground.PavedTop - 0.12,
			W.DarkGrey,
			Enum.Material.Concrete,
			"Joints"
		)
		joints.CastShadow = false
	else
		local part =
			rectBox(square, plaza, Ground.RoadTop, Ground.PavedTop, W.Concrete, Enum.Material.Concrete, "Paving")
		part.CastShadow = false
	end

	-- Sidewalks along the outer edge of the plaza road loop.
	local walks = Kit.folder(folder, "Sidewalks")
	local sw = Layout.SidewalkWidth
	local north, south = Layout.Roads[1], Layout.Roads[2]
	local west, east = Layout.Roads[3], Layout.Roads[4]
	local strips = {
		{ MinX = north.MinX, MaxX = north.MaxX - 14, MinZ = north.MinZ - sw, MaxZ = north.MinZ },
		{ MinX = south.MinX, MaxX = south.MaxX, MinZ = south.MaxZ, MaxZ = south.MaxZ + sw },
		{ MinX = west.MinX - sw, MaxX = west.MinX, MinZ = north.MaxZ, MaxZ = south.MinZ },
		{ MinX = east.MaxX, MaxX = east.MaxX + sw, MinZ = north.MaxZ, MaxZ = south.MinZ },
	}
	for _, strip in strips do
		local part = rectBox(
			walks,
			strip,
			Ground.RoadTop,
			Ground.PavedTop - 0.1,
			W.ConcreteLight,
			Enum.Material.Pavement,
			"Sidewalk"
		)
		part.CastShadow = false
	end

	return folder
end

local MARKING = Color3.fromRGB(206, 202, 186)

local function inAny(rects: { Layout.Rect }, x: number, z: number): boolean
	for _, r in rects do
		if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then
			return true
		end
	end
	return false
end

-- Zebra crossing across a road (stripes run with the traffic).
local function crossing(parent: Instance, road: Layout.Rect, along: number, width: number)
	local horizontal = (road.MaxX - road.MinX) > (road.MaxZ - road.MinZ)
	local y = Ground.RoadTop
	local span = if horizontal then road.MaxZ - road.MinZ else road.MaxX - road.MinX
	local count = math.floor(span / 2.2)
	for i = 0, count - 1 do
		local offset = 0.6 + i * 2.2
		if horizontal then
			Kit.box(
				parent,
				CFrame.new(),
				Vector3.new(along - width / 2, y - 0.04, road.MinZ + offset),
				Vector3.new(along + width / 2, y + 0.06, road.MinZ + offset + 1.1),
				MARKING,
				nil,
				{
					Name = "Crosswalk",
					Decor = true,
				}
			)
		else
			Kit.box(
				parent,
				CFrame.new(),
				Vector3.new(road.MinX + offset, y - 0.04, along - width / 2),
				Vector3.new(road.MinX + offset + 1.1, y + 0.06, along + width / 2),
				MARKING,
				nil,
				{
					Name = "Crosswalk",
					Decor = true,
				}
			)
		end
	end
end

-- Centre-line dashes, zebra crossings at every entrance and the parking lot.
function Ground.markings(parent: Instance)
	local folder = Kit.folder(parent, "RoadMarkings")
	local north, south = Layout.Roads[1], Layout.Roads[2]
	local west, east = Layout.Roads[3], Layout.Roads[4]
	local junctions = {
		{ MinX = west.MinX, MaxX = west.MaxX, MinZ = north.MinZ, MaxZ = north.MaxZ },
		{ MinX = east.MinX, MaxX = east.MaxX, MinZ = north.MinZ, MaxZ = north.MaxZ },
		{ MinX = west.MinX, MaxX = west.MaxX, MinZ = south.MinZ, MaxZ = south.MaxZ },
		{ MinX = east.MinX, MaxX = east.MaxX, MinZ = south.MinZ, MaxZ = south.MaxZ },
	}

	-- crossings in front of each entrance
	local crossings = {}
	local function addCrossing(road: Layout.Rect, along: number, width: number)
		crossing(folder, road, along, width)
		local horizontal = (road.MaxX - road.MinX) > (road.MaxZ - road.MinZ)
		if horizontal then
			table.insert(
				crossings,
				{ MinX = along - width / 2 - 1, MaxX = along + width / 2 + 1, MinZ = road.MinZ, MaxZ = road.MaxZ }
			)
		else
			table.insert(
				crossings,
				{ MinX = road.MinX, MaxX = road.MaxX, MinZ = along - width / 2 - 1, MaxZ = along + width / 2 + 1 }
			)
		end
	end
	addCrossing(north, Layout.Zones.OperationsCenter.Facade.X, 12)
	addCrossing(north, Layout.Zones.MapRoom.Facade.X, 8)
	addCrossing(west, Layout.Zones.Garage.Facade.Z, 10)
	addCrossing(east, Layout.Zones.CommandHQ.Facade.Z, 8)
	addCrossing(south, Layout.Zones.SocialArea.Facade.X, 10)
	addCrossing(south, Layout.Zones.EventArea.Facade.X, 8)
	addCrossing(south, Layout.Zones.Leaderboards.Facade.X, 8)

	-- dashed centre lines
	local y = Ground.RoadTop
	for _, road in Layout.Roads do
		local horizontal = (road.MaxX - road.MinX) > (road.MaxZ - road.MinZ)
		local length = if horizontal then road.MaxX - road.MinX else road.MaxZ - road.MinZ
		local start = if horizontal then road.MinX else road.MinZ
		local centre = if horizontal then (road.MinZ + road.MaxZ) / 2 else (road.MinX + road.MaxX) / 2
		local d = 2
		while d + 4 < length do
			local a = start + d
			local mid = a + 2
			local x = if horizontal then mid else centre
			local z = if horizontal then centre else mid
			if not inAny(junctions, x, z) and not inAny(crossings, x, z) then
				if horizontal then
					Kit.box(
						folder,
						CFrame.new(),
						Vector3.new(a, y - 0.04, centre - 0.2),
						Vector3.new(a + 4, y + 0.06, centre + 0.2),
						MARKING,
						nil,
						{
							Name = "CentreLine",
							Decor = true,
						}
					)
				else
					Kit.box(
						folder,
						CFrame.new(),
						Vector3.new(centre - 0.2, y - 0.04, a),
						Vector3.new(centre + 0.2, y + 0.06, a + 4),
						MARKING,
						nil,
						{
							Name = "CentreLine",
							Decor = true,
						}
					)
				end
			end
			d += 9
		end
	end

	-- staff parking: access lane + field (asphalt), painted stall lines and
	-- the lane's centre line, kerbs all round (butt-jointed), a footpath
	-- along the west side
	-- (the road's sidewalk runs across the lane mouth)
	local P = Layout.Parking
	local lane, field = P.Lane, P.Field
	local laneStart = south.MaxZ + Layout.SidewalkWidth
	for _, spec in { { rect = lane, name = "ParkingLane" }, { rect = field, name = "ParkingLot" } } do
		local rect = spec.rect
		local minZ = if spec.name == "ParkingLane" then laneStart else rect.MinZ
		local slab = rectBox(
			folder,
			{ MinX = rect.MinX, MaxX = rect.MaxX, MinZ = minZ, MaxZ = rect.MaxZ },
			Ground.GrassTop,
			Ground.RoadTop,
			W.AsphaltLight,
			Enum.Material.Asphalt,
			spec.name
		)
		slab.CastShadow = false
	end
	local kerbTop = Ground.PavedTop
	for _, rect in
		{
			{ MinX = lane.MinX - 0.6, MaxX = lane.MinX, MinZ = laneStart, MaxZ = field.MaxZ + 0.6 },
			{ MinX = lane.MinX, MaxX = field.MaxX + 0.6, MinZ = field.MaxZ, MaxZ = field.MaxZ + 0.6 },
			{ MinX = field.MaxX, MaxX = field.MaxX + 0.6, MinZ = field.MinZ - 0.6, MaxZ = field.MaxZ },
			{ MinX = lane.MaxX + 0.6, MaxX = field.MaxX, MinZ = field.MinZ - 0.6, MaxZ = field.MinZ },
			{ MinX = lane.MaxX, MaxX = lane.MaxX + 0.6, MinZ = laneStart, MaxZ = field.MinZ },
		}
	do
		local kerb =
			rectBox(folder, rect, Ground.GrassTop, kerbTop, W.ConcreteLight, Enum.Material.Concrete, "ParkingKerb")
		kerb.CastShadow = false
	end
	local path = rectBox(
		folder,
		{ MinX = lane.MinX - 3.6, MaxX = lane.MinX - 0.6, MinZ = laneStart, MaxZ = field.MaxZ + 0.6 },
		Ground.GrassTop,
		kerbTop,
		W.Concrete,
		Enum.Material.Pavement,
		"ParkingPath"
	)
	path.CastShadow = false
	-- paint: 0.25 wide lines 0.06 above the asphalt, stopping short of kerbs
	local function paint(name: string, a: Vector3, b: Vector3)
		Kit.box(folder, CFrame.new(), a, b, MARKING, nil, { Name = name, Decor = true })
	end
	local lineY0, lineY1 = Ground.RoadTop - 0.04, Ground.RoadTop + 0.06
	for k = 0, P.NorthStalls do
		local x = P.NorthRowX + k * P.StallWidth
		paint(
			"StallLine",
			Vector3.new(x - 0.125, lineY0, field.MinZ + 0.4),
			Vector3.new(x + 0.125, lineY1, field.MinZ + P.StallDepth)
		)
	end
	for k = 0, P.SouthStalls do
		local x = P.SouthRowX + k * P.StallWidth
		paint(
			"StallLine",
			Vector3.new(x - 0.125, lineY0, field.MaxZ - P.StallDepth),
			Vector3.new(x + 0.125, lineY1, field.MaxZ - 0.4)
		)
	end
	-- dashed centre line up the lane, a stop line at the road
	local mid = (lane.MinX + lane.MaxX) / 2
	local z = laneStart + 3
	while z + 3 < lane.MaxZ - 2 do
		paint("CentreLine", Vector3.new(mid - 0.125, lineY0, z), Vector3.new(mid + 0.125, lineY1, z + 3))
		z += 6
	end
	paint(
		"StopLine",
		Vector3.new(mid + 0.4, lineY0, laneStart + 0.4),
		Vector3.new(lane.MaxX - 0.4, lineY1, laneStart + 1)
	)
	return folder
end

return Ground
