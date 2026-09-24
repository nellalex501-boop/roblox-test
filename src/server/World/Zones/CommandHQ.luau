--!strict
-- COMMAND HQ — the player's personal headquarters (profile, records,
-- customisation, achievements). Two-storey brick Kaserne building with a
-- slate gable roof, white-framed windows and a columned entrance porch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local CommandHQ = {}

CommandHQ.FloorY = 1.2
CommandHQ.EaveY = 17.6

-- Interior rooms (zone-local) used to place stations and props.
CommandHQ.Rooms = {
	Lobby = { MinX = -22.8, MaxX = 22.8, MinZ = -20, MaxZ = -1.2 },
	Office = { MinX = -22.8, MaxX = 0, MinZ = -42.8, MaxZ = -20 },
	Records = { MinX = 0, MaxX = 22.8, MinZ = -42.8, MaxZ = -20 },
}

function CommandHQ.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.CommandHQ
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")

	local halfW, depth = zone.Width / 2, zone.Depth
	local floorY, eaveY = CommandHQ.FloorY, CommandHQ.EaveY
	local t = 1.2
	local door = zone.Entrances[1]
	local brick = W.Brick
	local trim = W.OffWhite

	-- raised floor with front steps (two 0.45 steps up from the forecourt)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW, 0, -depth),
		Vector3.new(halfW, floorY, 0),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Floor" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW + t, floorY, -depth + t),
		Vector3.new(halfW - t, floorY + 0.05, -t),
		Color3.fromRGB(96, 70, 52),
		Enum.Material.WoodPlanks,
		{
			Name = "Floorboards",
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
	Kit.box(
		shell,
		frame,
		Vector3.new(-7, 0.3, 0),
		Vector3.new(7, 0.75, 4.2),
		W.ConcreteLight,
		Enum.Material.Concrete,
		{ Name = "Step" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-7, 0.75, 0),
		Vector3.new(7, floorY, 2.2),
		W.ConcreteLight,
		Enum.Material.Concrete,
		{ Name = "Step" }
	)

	-- stone plinth
	for _, seg in
		{
			{ Vector3.new(-halfW - 0.3, 0, -0.1), Vector3.new(halfW + 0.3, 2.2, 0.3) },
			{ Vector3.new(-halfW - 0.3, 0, -depth - 0.3), Vector3.new(halfW + 0.3, 2.2, -depth + 0.1) },
			{ Vector3.new(-halfW - 0.3, 0, -depth), Vector3.new(-halfW + 0.1, 2.2, 0) },
			{ Vector3.new(halfW - 0.1, 0, -depth), Vector3.new(halfW + 0.3, 2.2, 0) },
		}
	do
		Kit.box(shell, frame, seg[1], seg[2], W.ConcreteDark, Enum.Material.Slate, { Name = "Plinth" })
	end

	-- brick walls
	local opening = { Center = halfW + door.Offset, Width = door.Width, Bottom = 0, Top = floorY + door.Height }
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW, -t / 2),
		Vector2.new(halfW, -t / 2),
		0,
		eaveY,
		t,
		brick,
		Enum.Material.Brick,
		{ opening }
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW, -depth + t / 2),
		Vector2.new(halfW, -depth + t / 2),
		0,
		eaveY,
		t,
		brick,
		Enum.Material.Brick
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW + t / 2, -t),
		Vector2.new(-halfW + t / 2, -depth + t),
		0,
		eaveY,
		t,
		brick,
		Enum.Material.Brick
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(halfW - t / 2, -t),
		Vector2.new(halfW - t / 2, -depth + t),
		0,
		eaveY,
		t,
		brick,
		Enum.Material.Brick
	)

	-- string course between the storeys + cornice
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.25, 10.6, -0.1),
		Vector3.new(halfW + 0.25, 11.2, 0.35),
		trim,
		Enum.Material.Concrete,
		{ Name = "StringCourse" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.5, eaveY - 0.8, -depth - 0.5),
		Vector3.new(halfW + 0.5, eaveY, 0.5),
		trim,
		Enum.Material.Concrete,
		{
			Name = "Cornice",
		}
	)

	-- interior partitions: open lobby at the front, office + records behind
	local interior = W.Beige
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW + t, -20),
		Vector2.new(halfW - t, -20),
		floorY,
		eaveY - 0.8,
		0.6,
		interior,
		Enum.Material.Concrete,
		{
			{ Center = 11.3, Width = 9, Bottom = 0, Top = 10 },
			{ Center = 34.3, Width = 9, Bottom = 0, Top = 10 },
		}
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(0, -20),
		Vector2.new(0, -depth + t),
		floorY,
		eaveY - 0.8,
		0.6,
		interior,
		Enum.Material.Concrete
	)
	for _, x in { -6, 6 } do
		Kit.wall(
			shell,
			frame,
			Vector2.new(x, -t),
			Vector2.new(x, -6),
			floorY,
			eaveY - 0.8,
			0.6,
			interior,
			Enum.Material.Concrete
		)
	end
	-- dark wood wainscoting in the lobby
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW + t, floorY, -20.4),
		Vector3.new(halfW - t, floorY + 3, -19.6),
		W.BrownDark,
		Enum.Material.Wood,
		{
			Name = "Wainscot",
			Decor = true,
		}
	)

	-- white-framed windows on both storeys
	local style: Architecture.WindowStyle = { Frame = trim, Sill = trim }
	for _, row in { { 4.6, 9.4 }, { 12.4, 16.2 } } do
		Architecture.windowRow(shell, frame, -halfW + 1, -8, 0, 1, row[1], row[2], 3, 3, style)
		Architecture.windowRow(shell, frame, 8, halfW - 1, 0, 1, row[1], row[2], 3, 3, style)
		Architecture.windowColumn(shell, frame, -depth + 2, -2, -halfW, -1, row[1], row[2], 5, 3, style)
		Architecture.windowColumn(shell, frame, -depth + 2, -2, halfW, 1, row[1], row[2], 5, 3, style)
	end
	-- upper window above the porch
	Architecture.windowRow(shell, frame, -3, 3, 0, 1, 12.4, 16.2, 1, 3.4, style)

	-- slate gable roof with two chimneys
	Architecture.gableRoof(
		shell,
		frame,
		-halfW - 0.4,
		halfW + 0.4,
		-depth - 0.4,
		0.4,
		eaveY,
		9,
		1.6,
		W.Roof,
		brick,
		Enum.Material.Slate,
		Enum.Material.Brick
	)
	for _, pos in { Vector3.new(-14, 0, -30), Vector3.new(14, 0, -30) } do
		Kit.box(
			shell,
			frame,
			Vector3.new(pos.X - 1.3, eaveY + 3, pos.Z - 1.3),
			Vector3.new(pos.X + 1.3, eaveY + 10.5, pos.Z + 1.3),
			W.BrickDark,
			Enum.Material.Brick,
			{
				Name = "Chimney",
			}
		)
		Kit.box(
			shell,
			frame,
			Vector3.new(pos.X - 1.6, eaveY + 10.5, pos.Z - 1.6),
			Vector3.new(pos.X + 1.6, eaveY + 11, pos.Z + 1.6),
			W.ConcreteDark,
			Enum.Material.Concrete,
			{
				Name = "ChimneyCap",
			}
		)
	end

	-- entrance porch: two columns carrying a small pediment
	for _, x in { -6.2, 6.2 } do
		Kit.post(
			shell,
			frame * CFrame.new(x, 0.3, 4),
			floorY + door.Height + 0.2,
			1.3,
			trim,
			Enum.Material.Concrete,
			{ Name = "PorchColumn" }
		)
	end
	local porchY = floorY + door.Height + 0.5
	Kit.box(
		shell,
		frame,
		Vector3.new(-7.6, porchY, -0.2),
		Vector3.new(7.6, porchY + 0.9, 5.2),
		trim,
		Enum.Material.Concrete,
		{ Name = "PorchRoof" }
	)
	for _, side in { -1, 1 } do
		Kit.wedge(
			shell,
			Vector3.new(0.9, 2.8, 7.6),
			frame
				* CFrame.new(side * 3.8, porchY + 2.3, 4.7)
				* CFrame.Angles(0, if side < 0 then math.pi / 2 else -math.pi / 2, 0),
			trim,
			Enum.Material.Concrete,
			{ Name = "Pediment" }
		)
	end
	local sign = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, porchY - 1.6, 0.3)),
		Vector2.new(12, 2.2),
		zone.DisplayName,
		{ Background = W.BrownDark, TextColor = Color3.fromRGB(214, 190, 120), PixelsPerStud = 40, Depth = 0.25 }
	)
	sign.Name = "EntranceSign"
	Architecture.doorFrame(shell, frame, door.Offset, 0, door.Width, door.Height, floorY, trim)
	Architecture.openDoors(shell, frame, door.Offset, -t, door.Width, door.Height, floorY, W.BrownDark)
	local plate = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(-9.5, 6, 0.3)),
		Vector2.new(3, 2),
		"BLDG 103",
		{ Background = W.OffWhite, TextColor = W.Charcoal, Depth = 0.15, PixelsPerStud = 40 }
	)
	plate.Name = "BuildingNumber"

	Architecture.flagpole(model, frame * CFrame.new(-15, 0.3, 3.2), 20, Architecture.Flags.WestGermany)
	Architecture.flagpole(model, frame * CFrame.new(15, 0.3, 3.2), 20, Architecture.Flags.Regiment)

	return model, frame
end

return CommandHQ
