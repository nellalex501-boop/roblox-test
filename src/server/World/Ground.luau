--!strict
-- Ground plane, parade square, road network and sidewalks.
-- Heights: grass 0.0, asphalt 0.1, plaza/sidewalk 0.3, building floors 0.6.

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

	-- Grass base, large enough to reach the tree line and hills beyond the fence.
	local grass = Kit.part(
		folder,
		Vector3.new(900, 4, 900),
		CFrame.new(0, Ground.GrassTop - 2, 0),
		W.Grass,
		Enum.Material.Grass,
		{ Name = "Grass" }
	)
	grass.CastShadow = false

	-- Roads
	local roads = Kit.folder(folder, "Roads")
	for _, road in Layout.Roads do
		local part = rectBox(roads, road, Ground.GrassTop, Ground.RoadTop, W.Asphalt, Enum.Material.Asphalt, road.Name)
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
				Vector3.new(along - width / 2, y, road.MinZ + offset),
				Vector3.new(along + width / 2, y + 0.03, road.MinZ + offset + 1.1),
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
				Vector3.new(road.MinX + offset, y, along - width / 2),
				Vector3.new(road.MinX + offset + 1.1, y + 0.03, along + width / 2),
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
						Vector3.new(a, y, centre - 0.2),
						Vector3.new(a + 4, y + 0.03, centre + 0.2),
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
						Vector3.new(centre - 0.2, y, a),
						Vector3.new(centre + 0.2, y + 0.03, a + 4),
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

	-- parking lot beside the canteen
	local lot = { MinX = 40, MaxX = 70, MinZ = 70, MaxZ = 128 }
	local asphalt =
		rectBox(folder, lot, Ground.GrassTop, Ground.RoadTop, W.AsphaltLight, Enum.Material.Asphalt, "ParkingLot")
	asphalt.CastShadow = false
	local drive = rectBox(
		folder,
		{ MinX = 50, MaxX = 60, MinZ = south.MaxZ - 0.5, MaxZ = lot.MinZ + 0.5 },
		Ground.GrassTop,
		Ground.PavedTop - 0.08,
		W.AsphaltLight,
		Enum.Material.Asphalt,
		"Driveway"
	)
	drive.CastShadow = false
	for i = 0, 11 do
		local z = lot.MinZ + 1 + i * 5
		for _, xs in { { lot.MinX, lot.MinX + 10 }, { lot.MaxX - 10, lot.MaxX } } do
			Kit.box(
				folder,
				CFrame.new(),
				Vector3.new(xs[1], Ground.RoadTop, z - 0.15),
				Vector3.new(xs[2], Ground.RoadTop + 0.03, z + 0.15),
				MARKING,
				nil,
				{
					Name = "StallLine",
					Decor = true,
				}
			)
		end
	end
	return folder
end

return Ground
