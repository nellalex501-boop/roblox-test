--!strict
-- COMMAND HQ — the player's personal headquarters (profile, records,
-- customisation, achievements). A German-built Kaserne block, as the US
-- Army took them over in the 1950s: two plastered storeys on a stone
-- plinth, a steep clay-tile roof with dormers, white-framed windows and a
-- flat-topped sandstone portal.

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
	local plaster = Color3.fromRGB(212, 196, 160)
	local trim = Color3.fromRGB(184, 164, 128) -- sandstone
	local frameWhite = W.OffWhite

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
		Color3.fromRGB(138, 102, 72),
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

	-- stone plinth; the front run stops at the door jambs
	Architecture.boxRun(
		shell,
		frame,
		Vector3.new(-halfW - 0.3, 0, -0.1),
		Vector3.new(halfW + 0.3, 2.2, 0.3),
		-- ends tucked 0.1 into the door-frame jambs (clear of the reveal)
		{ { door.Offset - door.Width / 2 - 0.1, door.Offset + door.Width / 2 + 0.1 } },
		W.ConcreteDark,
		Enum.Material.Slate,
		{ Name = "Plinth" }
	)
	for _, seg in
		{
			{ Vector3.new(-halfW - 0.3, 0, -depth - 0.3), Vector3.new(halfW + 0.3, 2.2, -depth + 0.1) },
			-- the sides butt against the front and back runs (no overlap)
			{ Vector3.new(-halfW - 0.3, 0, -depth + 0.1), Vector3.new(-halfW + 0.1, 2.2, -0.1) },
			{ Vector3.new(halfW - 0.1, 0, -depth + 0.1), Vector3.new(halfW + 0.3, 2.2, -0.1) },
		}
	do
		Kit.box(shell, frame, seg[1], seg[2], W.ConcreteDark, Enum.Material.Slate, { Name = "Plinth" })
	end

	-- plastered walls
	local opening = { Center = halfW + door.Offset, Width = door.Width, Bottom = 0, Top = floorY + door.Height }
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW, -t / 2),
		Vector2.new(halfW, -t / 2),
		0,
		eaveY,
		t,
		plaster,
		Enum.Material.Plaster,
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
		plaster,
		Enum.Material.Plaster
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW + t / 2, -t),
		Vector2.new(-halfW + t / 2, -depth + t),
		0,
		eaveY,
		t,
		plaster,
		Enum.Material.Plaster
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(halfW - t / 2, -t),
		Vector2.new(halfW - t / 2, -depth + t),
		0,
		eaveY,
		t,
		plaster,
		Enum.Material.Plaster
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

	-- light ceiling over the ground floor (the lights hang from it) and the
	-- interior partitions up to it: open lobby at the front, office +
	-- records behind
	Architecture.ceiling(shell, frame, -halfW + t, halfW - t, -depth + t, -t, eaveY - 0.4)
	local interior = W.Beige
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW + t, -20),
		Vector2.new(halfW - t, -20),
		floorY,
		eaveY - 0.6,
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
		eaveY - 0.6,
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
			eaveY - 0.6,
			0.6,
			interior,
			Enum.Material.Concrete
		)
	end
	-- the regiment's plaque on the partition facing the front door
	local crest =
		Kit.sign(shell, Kit.facingOut(frame, Vector3.new(0, floorY + 8, -19.62)), Vector2.new(9, 3), "BLACKHORSE", {
			Background = W.BrownDark,
			TextColor = Color3.fromRGB(214, 190, 120),
			Subtitle = "11TH ARMORED CAVALRY REGIMENT · ALLONS",
			Stripe = W.MutedRed,
			PixelsPerStud = 36,
			Depth = 0.2,
			MaxDistance = 90,
		})
	crest.Name = "RegimentPlaque"

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
	local style: Architecture.WindowStyle = { Frame = frameWhite, Sill = trim }
	for _, row in { { 4.6, 9.4 }, { 12.4, 16.2 } } do
		Architecture.windowRow(shell, frame, -halfW + 1, -8, 0, 1, row[1], row[2], 3, 3, style)
		Architecture.windowRow(shell, frame, 8, halfW - 1, 0, 1, row[1], row[2], 3, 3, style)
		Architecture.windowColumn(shell, frame, -depth + 2, -2, -halfW, -1, row[1], row[2], 5, 3, style)
		Architecture.windowColumn(shell, frame, -depth + 2, -2, halfW, 1, row[1], row[2], 5, 3, style)
		-- the back is a facade too (the lane behind the HQ passes it)
		Architecture.windowRow(shell, frame, -halfW + 2, halfW - 2, -depth, -1, row[1], row[2], 7, 3, style)
	end
	-- upper window above the porch
	Architecture.windowRow(shell, frame, -3, 3, 0, 1, 12.9, 16.5, 1, 3.4, style)

	-- steep clay-tile roof (about 35 degrees) with dormers and two chimneys
	local rise = 16
	Architecture.gableRoof(
		shell,
		frame,
		-halfW - 0.4,
		halfW + 0.4,
		-depth - 0.4,
		0.4,
		eaveY,
		rise,
		1.6,
		Color3.fromRGB(128, 64, 50),
		plaster,
		Enum.Material.ClayRoofTiles,
		Enum.Material.Plaster
	)
	-- gabled dormers on the front slope: the plastered box and its small
	-- tiled gable run back until they disappear into the main roof (box
	-- top 4.2 and ridge 5.8 above its base), a window in front
	local roofHalf = (depth + 0.8) / 2
	local function roofTop(z: number): number
		-- top surface of the front slope at zone-local z (0.9 roof planes)
		local angle = math.atan2(rise, roofHalf)
		return eaveY + rise * ((0.4 - z) / roofHalf) + 0.9 / math.cos(angle)
	end
	for _, x in { -14, 0, 14 } do
		local zFront = -4
		local base = roofTop(zFront) - 0.6
		local dormer = frame * CFrame.new(x, base, zFront)
		Kit.box(
			shell,
			dormer,
			Vector3.new(-2, 0, -9.6),
			Vector3.new(2, 4.2, 0),
			plaster,
			Enum.Material.Plaster,
			{ Name = "Dormer" }
		)
		for _, side in { -1, 1 } do
			Kit.wedge(
				shell,
				Vector3.new(11.8, 1.6, 2.3),
				dormer * CFrame.new(side * 1.15, 4.2 + 0.8, -5.6) * CFrame.Angles(0, -side * math.pi / 2, 0),
				Color3.fromRGB(128, 64, 50),
				Enum.Material.ClayRoofTiles,
				{ Name = "DormerRoof" }
			)
		end
		Kit.part(
			shell,
			Vector3.new(1.8, 2, 0.1),
			dormer * CFrame.new(0, 2.5, 0.1),
			W.Glass,
			Enum.Material.Glass,
			{ Name = "DormerWindow", Reflectance = 0.15, Decor = true }
		)
		Kit.part(
			shell,
			Vector3.new(2.3, 0.2, 0.4),
			dormer * CFrame.new(0, 1.4, 0.2),
			trim,
			Enum.Material.Sandstone,
			{ Name = "DormerSill", Decor = true }
		)
	end
	for _, pos in { Vector3.new(-14, 0, -30), Vector3.new(14, 0, -30) } do
		Kit.box(
			shell,
			frame,
			Vector3.new(pos.X - 1.3, eaveY + 3, pos.Z - 1.3),
			Vector3.new(pos.X + 1.3, eaveY + 14, pos.Z + 1.3),
			plaster,
			Enum.Material.Plaster,
			{
				Name = "Chimney",
			}
		)
		Kit.box(
			shell,
			frame,
			Vector3.new(pos.X - 1.6, eaveY + 14, pos.Z - 1.6),
			Vector3.new(pos.X + 1.6, eaveY + 14.5, pos.Z + 1.6),
			W.ConcreteDark,
			Enum.Material.Concrete,
			{
				Name = "ChimneyCap",
			}
		)
	end

	-- entrance portal: two square sandstone pillars carrying a deep, flat
	-- entablature (the name is carved on its front) under a cornice cap
	local porchY = floorY + door.Height + 0.5
	for _, x in { -6.2, 6.2 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.6, 0.3, 3.4),
			Vector3.new(x + 0.6, porchY, 4.6),
			trim,
			Enum.Material.Sandstone,
			{ Name = "PorchColumn" }
		)
	end
	Kit.box(
		shell,
		frame,
		Vector3.new(-7.6, porchY, -0.2),
		Vector3.new(7.6, porchY + 1.9, 5.2),
		trim,
		Enum.Material.Sandstone,
		{ Name = "PorchRoof" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-7.9, porchY + 1.9, -0.2),
		Vector3.new(7.9, porchY + 2.2, 5.5),
		trim,
		Enum.Material.Sandstone,
		{ Name = "PorchCornice" }
	)
	local sign = Kit.sign(
		shell,
		-- 0.02 into the entablature's face
		Kit.facingOut(frame, Vector3.new(0, porchY + 0.95, 5.2 + 0.1 - 0.02)),
		Vector2.new(12.6, 1.6),
		zone.DisplayName,
		{ Background = W.BrownDark, TextColor = Color3.fromRGB(214, 190, 120), PixelsPerStud = 40, Depth = 0.2 }
	)
	sign.Name = "EntranceSign"
	Architecture.doorFrame(shell, frame, door.Offset, 0, door.Width, door.Height, floorY, trim)
	Architecture.openDoors(shell, frame, door.Offset, -t, door.Width, door.Height, floorY, W.BrownDark)
	local plate = Kit.sign(
		shell,
		-- on the solid wall between the window row and the porch column
		Kit.facingOut(frame, Vector3.new(-8, 6, 0.055)),
		Vector2.new(2.2, 1.6),
		"BLDG 103",
		{ Background = W.OffWhite, TextColor = W.Charcoal, Depth = 0.15, PixelsPerStud = 40 }
	)
	plate.Name = "BuildingNumber"

	-- the poles stand out by the pavement so the flags fly clear of the eaves
	Architecture.flagpole(model, frame * CFrame.new(-15, 0.3, 5.6), 20, Architecture.Flags.Usa)
	Architecture.flagpole(model, frame * CFrame.new(15, 0.3, 5.6), 20, Architecture.Flags.Cavalry)

	return model, frame
end

return CommandHQ
