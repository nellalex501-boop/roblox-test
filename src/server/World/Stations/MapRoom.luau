--!strict
-- Map Room stations: one framed tactical display per battle map on the
-- walls (top-down preview + name plate) and a planning table carrying a 3D
-- miniature of the featured map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Maps = require(ReplicatedStorage.Lobby.Config.Maps)
local MapDraw = require(ReplicatedStorage.Lobby.Util.MapDraw)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local MapRoom = {}

MapRoom.FloorY = 0.6

-- Display placement (Map Room frame): wall position and facing direction.
type Slot = { Map: string, Pos: Vector3, Facing: Vector3 }

MapRoom.Slots = {
	{ Map = "TRAIN_STATION", Pos = Vector3.new(-24.5, 0, -14), Facing = Vector3.new(1, 0, 0) },
	{ Map = "CATHEDRAL", Pos = Vector3.new(-24.5, 0, -32), Facing = Vector3.new(1, 0, 0) },
	{ Map = "RIVER_CROSSING", Pos = Vector3.new(-16, 0, -46.4), Facing = Vector3.new(0, 0, 1) },
	{ Map = "INDUSTRIAL_HEART", Pos = Vector3.new(0, 0, -46.4), Facing = Vector3.new(0, 0, 1) },
	{ Map = "AIRBASE", Pos = Vector3.new(16, 0, -46.4), Facing = Vector3.new(0, 0, 1) },
	{ Map = "DAM", Pos = Vector3.new(24.5, 0, -32), Facing = Vector3.new(-1, 0, 0) },
	{ Map = "HIGHWAY", Pos = Vector3.new(24.5, 0, -14), Facing = Vector3.new(-1, 0, 0) },
} :: { Slot }

local function display(parent: Instance, roomFrame: CFrame, slot: Slot)
	local info = Maps.List[slot.Map]
	local model = Kit.model(parent, "Display_" .. slot.Map)
	local size = Vector2.new(10.5, 10.5)
	local centerY = 8.9
	local look = roomFrame
		* CFrame.lookAt(slot.Pos + Vector3.new(0, centerY, 0), slot.Pos + Vector3.new(0, centerY, 0) + slot.Facing)
	-- frame + screen
	Kit.part(
		model,
		Vector3.new(size.X + 1, size.Y + 1, 0.4),
		look * CFrame.new(0, 0, 0.15),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "Frame" }
	)
	local screen = Kit.part(
		model,
		Vector3.new(size.X, size.Y, 0.2),
		look * CFrame.new(0, 0, -0.15),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{
			Name = "MapScreen",
		}
	)
	local pps = 24
	local gui = Kit.surface(screen, Enum.NormalId.Front, pps, 0.15, 160)
	gui.Name = "MapPreview"
	MapDraw.preview(gui, info, size.X * pps, size.Y * pps, { labels = true })
	Interactions.attach(screen, "MapInfo", slot.Map, info.Name)
	-- name plate under the display
	local plate = Kit.sign(model, look * CFrame.new(0, -size.Y / 2 - 1.4, -0.1), Vector2.new(size.X, 1.9), info.Name, {
		Background = W.Charcoal,
		TextColor = W.OffWhite,
		Stripe = W.Beige,
		Subtitle = ("%s · %s PLAYERS"):format(info.Size, info.Players),
		PixelsPerStud = 40,
		MaxDistance = 120,
	})
	plate.Name = "NamePlate"
	-- small spot lamp above
	local lamp = Kit.part(
		model,
		Vector3.new(2.4, 0.5, 0.8),
		look * CFrame.new(0, size.Y / 2 + 1, -1),
		W.SteelDark,
		Enum.Material.Metal,
		{
			Name = "DisplayLamp",
			Decor = true,
		}
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 80
	light.Range = 12
	light.Brightness = 0.9
	light.Color = W.Lamp
	light.Shadows = false
	light.Parent = lamp
end

-- 3D miniature of a map's preview layout on a table top.
local function miniature(parent: Instance, top: CFrame, width: number, depth: number, info: Maps.MapInfo)
	local model = Kit.model(parent, "Miniature_" .. info.Id)
	local p = info.Preview
	local water: { Maps.Box } = p.Water or {}
	local rivers: { Maps.Polyline } = p.Rivers or {}
	local highways: { Maps.Polyline } = p.Highways or {}
	local function at(x: number, z: number, y: number): CFrame
		return top * CFrame.new((x - 0.5) * width, y, (z - 0.5) * depth)
	end
	Kit.part(
		model,
		Vector3.new(width, 0.3, depth),
		top * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(88, 102, 62),
		Enum.Material.Grass,
		{
			Name = "Terrain",
			Decor = true,
		}
	)
	local function strip(
		points: { { number } },
		thickness: number,
		height: number,
		color: Color3,
		material: Enum.Material
	)
		for i = 1, #points - 1 do
			local a = at(points[i][1], points[i][2], height).Position
			local b = at(points[i + 1][1], points[i + 1][2], height).Position
			local delta = b - a
			local cf = CFrame.lookAt((a + b) / 2, b)
			Kit.part(
				model,
				Vector3.new(thickness, 0.06, delta.Magnitude + thickness * 0.5),
				cf,
				color,
				material,
				{ Name = "Strip", Decor = true }
			)
		end
	end
	for _, box in water do
		local cf = at(box[1] + box[3] / 2, box[2] + box[4] / 2, 0.32)
		Kit.part(
			model,
			Vector3.new(box[3] * width, 0.04, box[4] * depth),
			cf,
			MapDraw.Colors.Water,
			Enum.Material.SmoothPlastic,
			{
				Name = "Water",
				Decor = true,
			}
		)
	end
	for _, river in rivers do
		strip(
			river,
			math.max(0.5, (p.RiverWidth or 0.03) * width),
			0.33,
			MapDraw.Colors.Water,
			Enum.Material.SmoothPlastic
		)
	end
	for _, road in p.Roads do
		strip(road, 0.25, 0.34, MapDraw.Colors.Road, Enum.Material.SmoothPlastic)
	end
	for _, road in highways do
		strip(road, 0.5, 0.34, MapDraw.Colors.Highway, Enum.Material.SmoothPlastic)
	end
	local rng = Random.new(#info.Id * 97)
	for _, box in p.Forests do
		local cf = at(box[1] + box[3] / 2, box[2] + box[4] / 2, 0.6)
		Kit.part(
			model,
			Vector3.new(box[3] * width, 0.6, box[4] * depth),
			cf,
			MapDraw.Colors.Forest,
			Enum.Material.Grass,
			{
				Name = "Forest",
				Decor = true,
			}
		)
	end
	for _, box in p.Urban do
		local bw, bd = box[3] * width, box[4] * depth
		local nx, nz = math.max(1, math.floor(bw / 0.9)), math.max(1, math.floor(bd / 0.9))
		for ix = 0, nx - 1 do
			for iz = 0, nz - 1 do
				if rng:NextNumber() < 0.8 then
					local h = rng:NextNumber(0.3, 0.9)
					local x = box[1] + (ix + 0.5) * box[3] / nx
					local z = box[2] + (iz + 0.5) * box[4] / nz
					Kit.part(
						model,
						Vector3.new(bw / nx * 0.75, h, bd / nz * 0.75),
						at(x, z, 0.3 + h / 2),
						MapDraw.Colors.Urban,
						Enum.Material.Concrete,
						{
							Name = "Block",
							Decor = true,
						}
					)
				end
			end
		end
	end
	local lm = p.Landmark
	Kit.part(
		model,
		Vector3.new(0.5, 1.6, 0.5),
		at(lm.x, lm.y, 1.1),
		Theme.UI.Accent,
		Enum.Material.SmoothPlastic,
		{ Name = "Landmark", Decor = true }
	)
	for faction, pos in p.Spawns :: { [string]: { number } } do
		local color = if faction == "NATO" then MapDraw.Colors.Nato else MapDraw.Colors.Pact
		Kit.part(
			model,
			Vector3.new(0.7, 0.5, 0.7),
			at(pos[1], pos[2], 0.55),
			color,
			Enum.Material.SmoothPlastic,
			{ Name = "SpawnMarker", Decor = true }
		)
	end
	for _, s in p.Sectors do
		Kit.part(
			model,
			Vector3.new(0.1, 0.9, 0.1),
			at(s[1], s[2], 0.75),
			W.OffWhite,
			nil,
			{ Name = "SectorPin", Decor = true }
		)
		Kit.part(
			model,
			Vector3.new(0.5, 0.3, 0.05),
			at(s[1], s[2], 1.05) * CFrame.new(0.25, 0, 0),
			W.MutedRed,
			nil,
			{ Name = "SectorFlag", Decor = true }
		)
	end
	return model
end

local function planningTable(parent: Instance, roomFrame: CFrame)
	local model = Kit.model(parent, "PlanningTable")
	local center = Vector3.new(0, MapRoom.FloorY, -26)
	local w, d = 20, 13
	local topY = 3.4
	local top = roomFrame * CFrame.new(center + Vector3.new(0, topY, 0))
	local body = Kit.part(
		model,
		Vector3.new(w + 1.2, 0.8, d + 1.2),
		top * CFrame.new(0, -0.4, 0),
		W.BrownDark,
		Enum.Material.Wood,
		{
			Name = "TableTop",
		}
	)
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			Kit.part(
				model,
				Vector3.new(0.9, topY - 0.8, 0.9),
				roomFrame * CFrame.new(center + Vector3.new(x, (topY - 0.8) / 2, z)),
				W.BrownDark,
				Enum.Material.Wood,
				{
					Name = "Leg",
				}
			)
		end
	end
	local info = Maps.List[Maps.Featured]
	miniature(model, top, w, d, info)
	Interactions.attach(body, "MapInfo", info.Id, info.Name .. " — PLANNING TABLE")
	-- hanging lamps over the table
	for _, x in { -6, 6 } do
		local lamp = Kit.part(
			model,
			Vector3.new(2.6, 1, 2.6),
			roomFrame * CFrame.new(center + Vector3.new(x, 12.5, 0)),
			W.OliveDark,
			Enum.Material.Metal,
			{
				Name = "PendantLamp",
				Decor = true,
			}
		)
		Kit.part(
			model,
			Vector3.new(0.1, 4.4, 0.1),
			roomFrame * CFrame.new(center + Vector3.new(x, 15.2, 0)),
			W.Charcoal,
			nil,
			{ Name = "Cord", Decor = true }
		)
		local light = Instance.new("PointLight")
		light.Range = 16
		light.Brightness = 0.8
		light.Color = W.Lamp
		light.Shadows = false
		light.Parent = lamp
	end
	return model
end

function MapRoom.build(zoneModel: Instance, roomFrame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	for _, slot in MapRoom.Slots do
		display(folder, roomFrame, slot)
	end
	planningTable(folder, roomFrame)
	local teletype = Kit.part(
		folder,
		Vector3.new(1, 1, 1),
		roomFrame * CFrame.new(18, 6, -8),
		W.Screen,
		nil,
		{ Name = "Teletype", Transparency = 1, Decor = true }
	)
	Kit.anchor(teletype, "Sound", "Teletype")
end

return MapRoom
