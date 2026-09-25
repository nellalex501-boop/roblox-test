--!strict
-- GARAGE — motor pool hall with the vehicle showroom (turntable, see
-- Stations/Garage) and working service bays along the sides.
-- Steel-frame hall: concrete base band, olive metal cladding, shallow gable
-- roof, three large roll-up doors with bollards, painted walkway lines.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Garage = {}

Garage.FloorY = 0.4
Garage.EaveY = 24

function Garage.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.Garage
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")

	local halfW, depth = zone.Width / 2, zone.Depth
	local floorY, eaveY = Garage.FloorY, Garage.EaveY
	local metal = W.Olive

	-- the slab stops 0.1 inside the side and back walls and stands 0.1
	-- proud of the facade as a threshold lip, so its edges never lie in
	-- the same plane as a wall face
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW + 0.1, 0, -depth + 0.1),
		Vector3.new(halfW - 0.1, floorY, 0.1),
		Color3.fromRGB(168, 166, 156),
		Enum.Material.Concrete,
		{ Name = "Floor" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW, 0, 0),
		Vector3.new(halfW, 0.3, 5.5),
		W.ConcreteLight,
		Enum.Material.Concrete,
		{ Name = "Apron", Shadow = false }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW + 0.5, 0.3, 4.6),
		Vector3.new(halfW - 0.5, 0.36, 5.2),
		W.DarkGrey,
		Enum.Material.DiamondPlate,
		{
			Name = "DrainGrate",
			Decor = true,
		}
	)

	-- walls: concrete base band + metal cladding above
	local doors = {}
	local upperDoors = {}
	for _, entrance in zone.Entrances do
		table.insert(
			doors,
			{ Center = halfW + entrance.Offset, Width = entrance.Width, Bottom = 0, Top = floorY + entrance.Height }
		)
		table.insert(
			upperDoors,
			{ Center = halfW + entrance.Offset, Width = entrance.Width, Bottom = 0, Top = floorY + entrance.Height - 4 }
		)
	end
	local function walls(
		y0: number,
		y1: number,
		thickness: number,
		color: Color3,
		material: Enum.Material,
		front: { Kit.Opening }
	)
		Kit.wall(
			shell,
			frame,
			Vector2.new(-halfW, -thickness / 2),
			Vector2.new(halfW, -thickness / 2),
			y0,
			y1,
			thickness,
			color,
			material,
			front
		)
		Kit.wall(
			shell,
			frame,
			Vector2.new(-halfW, -depth + thickness / 2),
			Vector2.new(halfW, -depth + thickness / 2),
			y0,
			y1,
			thickness,
			color,
			material
		)
		Kit.wall(
			shell,
			frame,
			Vector2.new(-halfW + thickness / 2, -thickness),
			Vector2.new(-halfW + thickness / 2, -depth + thickness),
			y0,
			y1,
			thickness,
			color,
			material
		)
		Kit.wall(
			shell,
			frame,
			Vector2.new(halfW - thickness / 2, -thickness),
			Vector2.new(halfW - thickness / 2, -depth + thickness),
			y0,
			y1,
			thickness,
			color,
			material,
			{
				{ Center = depth - 12, Width = 5, Bottom = 0, Top = if y0 == 0 then 8 else 4 },
			}
		)
	end
	walls(0, 4, 1.2, W.ConcreteDark, Enum.Material.Concrete, doors)
	walls(4, eaveY, 1, metal, Enum.Material.Metal, upperDoors)

	-- steel pilasters (I-beam columns) on the facade
	for _, x in { -39, -13, 13, 39 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.8, 0, -0.2),
			Vector3.new(x + 0.8, eaveY, 0.7),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Pilaster" }
		)
	end

	-- gable roof, ridge parallel to the facade
	Architecture.gableRoof(
		shell,
		frame,
		-halfW - 0.3,
		halfW + 0.3,
		-depth - 0.3,
		0.3,
		eaveY,
		7,
		1.6,
		Color3.fromRGB(128, 130, 124),
		metal,
		Enum.Material.CorrodedMetal,
		Enum.Material.Metal
	)

	-- high strip windows
	local style: Architecture.WindowStyle = { Glass = W.Glass, Sill = W.SteelDark }
	Architecture.windowColumn(shell, frame, -depth + 4, -4, -halfW, -1, 16.5, 21, 6, 5, style)
	Architecture.windowColumn(shell, frame, -depth + 4, -4, halfW, 1, 16.5, 21, 6, 5, style)
	Architecture.windowRow(shell, frame, -halfW + 4, halfW - 4, -depth, -1, 16.5, 21, 7, 6, style)

	-- roll-up doors (raised), bollards and bay numbers
	for i, entrance in zone.Entrances do
		local x = entrance.Offset
		local top = floorY + entrance.Height
		Kit.cylinder(
			shell,
			entrance.Width + 1,
			2.6,
			frame * CFrame.new(x, top + 1.5, -2.2),
			W.SteelDark,
			Enum.Material.Metal,
			{
				Name = "DoorDrum",
			}
		)
		Kit.box(
			shell,
			frame,
			Vector3.new(x - entrance.Width / 2, top - 0.5, -1.6),
			Vector3.new(x + entrance.Width / 2, top + 0.1, -1.1),
			W.Olive,
			Enum.Material.Metal,
			{
				Name = "DoorSlat",
				Decor = true,
			}
		)
		for _, side in { -1, 1 } do
			-- rails stand 0.05 clear of the door reveal
			local jamb = x + side * (entrance.Width / 2 + 0.35)
			Kit.box(
				shell,
				frame,
				Vector3.new(jamb - 0.3, floorY, -1.6),
				Vector3.new(jamb + 0.3, top, -1.1),
				W.SteelDark,
				Enum.Material.Metal,
				{
					Name = "DoorRail",
					Decor = true,
				}
			)
			local bollard = frame * CFrame.new(x + side * (entrance.Width / 2 + 1.2), 0.3, 2.2)
			Kit.post(shell, bollard, 3.2, 1.1, W.HazardYellow, Enum.Material.SmoothPlastic, { Name = "Bollard" })
			Kit.post(
				shell,
				bollard * CFrame.new(0, 2.2, 0),
				0.5,
				1.15,
				W.Charcoal,
				Enum.Material.SmoothPlastic,
				{ Name = "BollardBand", Decor = true }
			)
		end
		if i ~= 2 then
			local plate = Kit.sign(
				shell,
				Kit.facingOut(frame, Vector3.new(x, top + 2.2, 0.2)),
				Vector2.new(7, 2.4),
				"BAY " .. i,
				{ Background = W.Charcoal, TextColor = W.HazardYellow, PixelsPerStud = 30 }
			)
			plate.Name = "BayNumber"
		end
	end

	-- main sign over the centre door
	local sign = Kit.sign(
		shell,
		-- below the roof's front overhang
		Kit.facingOut(frame, Vector3.new(0, floorY + 18 + 2.6, 0.2)),
		Vector2.new(24, 4.8),
		zone.DisplayName,
		{ Background = W.SignGreen, Subtitle = zone.Subtitle, Stripe = W.HazardYellow, PixelsPerStud = 18 }
	)
	sign.Name = "EntranceSign"
	local plate = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(-37.1, 8, 0.075)),
		Vector2.new(2, 1.4),
		"BLDG 104",
		{ Background = W.OffWhite, TextColor = W.Charcoal, Depth = 0.15, PixelsPerStud = 40 }
	)
	plate.Name = "BuildingNumber"

	-- painted walkway lines from the doors to the showroom, 0.06 proud
	local line = W.HazardYellow
	for _, x in { -13, 13 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.25, floorY - 0.04, -14),
			Vector3.new(x + 0.25, floorY + 0.06, -3),
			line,
			nil,
			{ Name = "WalkLine", Decor = true }
		)
	end

	-- personnel door on the north side (closed)
	local doorCf = frame * CFrame.new(halfW + 0.1, floorY + 4, -(depth - 12))
	Kit.part(shell, Vector3.new(0.3, 8, 5), doorCf, W.SteelDark, Enum.Material.Metal, { Name = "SideDoor" })

	return model, frame
end

return Garage
