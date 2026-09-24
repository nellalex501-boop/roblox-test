--!strict
-- MAP ROOM — military planning room with the battle map displays.
-- Single-storey concrete building with a beige accent band, clerestory
-- windows, a roof lantern and an entrance canopy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local MapRoom = {}

MapRoom.FloorY = 0.6
MapRoom.CeilingY = 18

function MapRoom.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.MapRoom
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")

	local halfW, depth = zone.Width / 2, zone.Depth
	local floorY, roofY = MapRoom.FloorY, MapRoom.CeilingY
	local t = 1
	local door = zone.Entrances[1]

	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW, 0, -depth),
		Vector3.new(halfW, floorY, 0),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{
			Name = "Floor",
		}
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW + t, floorY, -depth + t),
		Vector3.new(halfW - t, floorY + 0.05, -t),
		Color3.fromRGB(92, 78, 60),
		Enum.Material.WoodPlanks,
		{
			Name = "Parquet",
			Shadow = false,
		}
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW, 0, 0),
		Vector3.new(halfW, 0.3, 5),
		W.Concrete,
		Enum.Material.Pavement,
		{ Name = "Forecourt", Shadow = false }
	)

	-- walls
	local wall = W.ConcreteLight
	local opening = { Center = halfW + door.Offset, Width = door.Width, Bottom = 0, Top = floorY + door.Height }
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW, -t / 2),
		Vector2.new(halfW, -t / 2),
		0,
		roofY,
		t,
		wall,
		Enum.Material.Concrete,
		{ opening }
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW, -depth + t / 2),
		Vector2.new(halfW, -depth + t / 2),
		0,
		roofY,
		t,
		wall,
		Enum.Material.Concrete
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW + t / 2, -t),
		Vector2.new(-halfW + t / 2, -depth + t),
		0,
		roofY,
		t,
		wall,
		Enum.Material.Concrete
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(halfW - t / 2, -t),
		Vector2.new(halfW - t / 2, -depth + t),
		0,
		roofY,
		t,
		wall,
		Enum.Material.Concrete
	)

	-- plinth + beige accent band (the Map Room's colour key)
	for _, seg in
		{
			{ Vector3.new(-halfW - 0.3, 0, -0.1), Vector3.new(halfW + 0.3, 1.6, 0.3) },
			{ Vector3.new(-halfW - 0.3, 0, -depth - 0.3), Vector3.new(-halfW + 0.1, 1.6, 0) },
			{ Vector3.new(halfW - 0.1, 0, -depth - 0.3), Vector3.new(halfW + 0.3, 1.6, 0) },
		}
	do
		Kit.box(shell, frame, seg[1], seg[2], W.ConcreteDark, Enum.Material.Concrete, { Name = "Plinth" })
	end
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.25, 11, -0.1),
		Vector3.new(halfW + 0.25, 12.6, 0.3),
		W.Beige,
		Enum.Material.Concrete,
		{
			Name = "AccentBand",
		}
	)
	for _, x in { -halfW - 0.25, halfW - 0.15 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x, 11, -depth),
			Vector3.new(x + 0.4, 12.6, 0),
			W.Beige,
			Enum.Material.Concrete,
			{ Name = "AccentBand" }
		)
	end

	-- windows: two beside the door, clerestory strips along the sides
	local style: Architecture.WindowStyle = { Frame = W.DarkGrey }
	Architecture.windowRow(shell, frame, -halfW + 3, -9, 0, 1, 4, 9, 2, 4, style)
	Architecture.windowRow(shell, frame, 9, halfW - 3, 0, 1, 4, 9, 2, 4, style)
	Architecture.windowColumn(shell, frame, -depth + 4, -4, -halfW, -1, 13.4, 16.4, 5, 5, style)
	Architecture.windowColumn(shell, frame, -depth + 4, -4, halfW, 1, 13.4, 16.4, 5, 5, style)

	Architecture.flatRoof(shell, frame, -halfW, halfW, -depth, 0, roofY, 1.2, wall)

	-- roof lantern (raised skylight block) for a distinct silhouette
	local lx0, lx1, lz0, lz1 = -10, 10, -32, -16
	Kit.box(
		shell,
		frame,
		Vector3.new(lx0, roofY + 1, lz0),
		Vector3.new(lx1, roofY + 4, lz1),
		W.Beige,
		Enum.Material.Concrete,
		{ Name = "Lantern" }
	)
	Architecture.windowRow(
		shell,
		frame,
		lx0 + 1,
		lx1 - 1,
		lz1,
		1,
		roofY + 1.6,
		roofY + 3.4,
		4,
		3.4,
		{ Glass = W.Glass }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(lx0 - 0.6, roofY + 4, lz0 - 0.6),
		Vector3.new(lx1 + 0.6, roofY + 4.6, lz1 + 0.6),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{
			Name = "LanternCap",
		}
	)

	-- entrance canopy and sign
	Kit.box(
		shell,
		frame,
		Vector3.new(-9, 12.8, -0.2),
		Vector3.new(9, 13.6, 5.2),
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "Canopy" }
	)
	for _, x in { -8.2, 8.2 } do
		Kit.post(
			shell,
			frame * CFrame.new(x, 0.3, 4.6),
			12.5,
			0.5,
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "CanopyStrut" }
		)
	end
	local sign = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, 15.5, 0.25)),
		Vector2.new(22, 3.6),
		zone.DisplayName,
		{ Background = W.SignGreen, Stripe = W.Beige, PixelsPerStud = 20 }
	)
	sign.Name = "EntranceSign"
	Architecture.doorFrame(shell, frame, door.Offset, 0, door.Width, door.Height, floorY, W.DarkGrey)
	Architecture.openDoors(shell, frame, door.Offset, -t, door.Width, door.Height, floorY, W.BeigeDark)
	local plate = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(door.Width / 2 + 2.4, 6, 0.3)),
		Vector2.new(3, 2),
		"BLDG 102",
		{ Background = W.OffWhite, TextColor = W.Charcoal, Depth = 0.15, PixelsPerStud = 40 }
	)
	plate.Name = "BuildingNumber"

	-- roof antenna
	local mast = frame * CFrame.new(18, roofY + 1, -40)
	Kit.post(shell, mast, 10, 0.4, W.Steel, Enum.Material.Metal, { Name = "Antenna" })
	Kit.part(
		shell,
		Vector3.new(4, 0.2, 0.2),
		mast * CFrame.new(0, 8, 0),
		W.Steel,
		Enum.Material.Metal,
		{ Name = "AntennaArm", Decor = true }
	)

	return model, frame
end

return MapRoom
