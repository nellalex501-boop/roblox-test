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
				local tone = rng:NextNumber(-0.035, 0.035)
				local base = if (c + r) % 2 == 0 then W.ConcreteLight else W.Concrete
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

return Ground
