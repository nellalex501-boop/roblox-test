--!strict
-- OPERATIONS CENTER — largest building; matchmaking hall.
-- Concrete command block with a raised central tower, a radome landmark,
-- portico entrance, strip windows, side wings (signals room / briefing room)
-- and roof antennas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local OperationsCenter = {}

OperationsCenter.FloorY = 0.6
OperationsCenter.CeilingY = 22.6
-- Interior bounds of the matchmaking hall (zone-local).
OperationsCenter.Hall = { MinX = -34, MaxX = 34, MinZ = -62.8, MaxZ = -1.2 }

function OperationsCenter.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.OperationsCenter
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")

	local halfW, depth = zone.Width / 2, zone.Depth
	local floorY, roofY = OperationsCenter.FloorY, OperationsCenter.CeilingY
	local t = 1.2
	local wallColor = W.ConcreteLight
	local door = zone.Entrances[1]

	-- floor, interior finish, forecourt
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
		Vector3.new(-34, floorY, -62.8),
		Vector3.new(34, floorY + 0.05, -1.2),
		Color3.fromRGB(128, 130, 120),
		Enum.Material.SmoothPlastic,
		{
			Name = "HallFloor",
			Shadow = false,
		}
	)
	Kit.box(shell, frame, Vector3.new(-halfW, 0, 0), Vector3.new(halfW, 0.3, 5), W.Concrete, Enum.Material.Pavement, {
		Name = "Forecourt",
		Shadow = false,
	})

	-- plinth band (slightly proud of the walls)
	local plinth = W.ConcreteDark
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.4, 0, -0.1),
		Vector3.new(halfW + 0.4, 1.8, 0.4),
		plinth,
		Enum.Material.Concrete,
		{ Name = "Plinth" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.4, 0, -depth - 0.4),
		Vector3.new(halfW + 0.4, 1.8, -depth + 0.1),
		plinth,
		Enum.Material.Concrete,
		{
			Name = "Plinth",
		}
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.4, 0, -depth + 0.1),
		Vector3.new(-halfW + 0.1, 1.8, -0.1),
		plinth,
		Enum.Material.Concrete,
		{ Name = "Plinth" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(halfW - 0.1, 0, -depth + 0.1),
		Vector3.new(halfW + 0.4, 1.8, -0.1),
		plinth,
		Enum.Material.Concrete,
		{ Name = "Plinth" }
	)

	-- exterior walls
	local entrance = { Center = halfW + door.Offset, Width = door.Width, Bottom = 0, Top = floorY + door.Height }
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW, -t / 2),
		Vector2.new(halfW, -t / 2),
		0,
		roofY,
		t,
		wallColor,
		Enum.Material.Concrete,
		{ entrance }
	)
	Kit.wall(
		shell,
		frame,
		Vector2.new(-halfW, -depth + t / 2),
		Vector2.new(halfW, -depth + t / 2),
		0,
		roofY,
		t,
		wallColor,
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
		wallColor,
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
		wallColor,
		Enum.Material.Concrete
	)

	-- interior walls between the hall and the side wings, with doorways
	local wingDoors = {
		{ Center = 18.8, Width = 8, Bottom = 0, Top = floorY + 11 },
		{ Center = 44.8, Width = 8, Bottom = 0, Top = floorY + 11 },
	}
	for _, x in { -34, 34 } do
		Kit.wall(
			shell,
			frame,
			Vector2.new(x, -1.2),
			Vector2.new(x, -62.8),
			floorY,
			roofY,
			0.8,
			W.Concrete,
			Enum.Material.Concrete,
			wingDoors
		)
	end
	-- interior wall trim: dado band in the hall
	for _, x in { -33.5, 33.5 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.2, floorY, -62.8),
			Vector3.new(x + 0.2, floorY + 3.2, -1.2),
			W.OliveDark,
			nil,
			{
				Name = "Dado",
				Decor = true,
			}
		)
	end
	Kit.box(
		shell,
		frame,
		Vector3.new(-34, floorY, -62.9),
		Vector3.new(34, floorY + 3.2, -62.4),
		W.OliveDark,
		nil,
		{ Name = "Dado", Decor = true }
	)

	-- facade: horizontal band, pilasters, windows
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.3, 11.2, -0.2),
		Vector3.new(halfW + 0.3, 12.2, 0.5),
		W.Concrete,
		Enum.Material.Concrete,
		{
			Name = "Band",
			Shadow = false,
		}
	)
	for _, x in { -38, -28, -18, 18, 28, 38 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.6, 1.8, -0.2),
			Vector3.new(x + 0.6, roofY, 0.8),
			W.Concrete,
			Enum.Material.Concrete,
			{
				Name = "Pilaster",
			}
		)
	end
	local windows: Architecture.WindowStyle = { Frame = W.DarkGrey }
	for _, section in { { -48, -18 }, { 18, 48 } } do
		for bay = 0, 2 do
			local bx0 = section[1] + bay * 10
			Architecture.windowRow(shell, frame, bx0 + 0.6, bx0 + 9.4, 0, 1, 4, 9.5, 2, 3.4, windows)
			Architecture.windowRow(shell, frame, bx0 + 0.6, bx0 + 9.4, 0, 1, 14, 19.5, 2, 3.4, windows)
		end
	end
	for _, x in { -halfW, halfW } do
		local outward = if x > 0 then 1 else -1
		Architecture.windowColumn(shell, frame, -60, -4, x, outward, 14, 19.5, 7, 3.6, windows)
		Architecture.windowColumn(shell, frame, -60, -4, x, outward, 4, 9.5, 7, 3.6, windows)
	end

	-- flat roof + parapet
	Architecture.flatRoof(shell, frame, -halfW, halfW, -depth, 0, roofY, 1.4, wallColor)

	-- central tower block with the building name, rising above the roof
	local towerTop = 35
	local tw = { x0 = -20, x1 = 20, z0 = -44, z1 = -6 }
	Kit.box(
		shell,
		frame,
		Vector3.new(tw.x0, roofY + 1, tw.z1 - 1),
		Vector3.new(tw.x1, towerTop, tw.z1),
		wallColor,
		Enum.Material.Concrete,
		{
			Name = "TowerFront",
		}
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(tw.x0, roofY + 1, tw.z0),
		Vector3.new(tw.x1, towerTop, tw.z0 + 1),
		wallColor,
		Enum.Material.Concrete,
		{
			Name = "TowerBack",
		}
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(tw.x0, roofY + 1, tw.z0 + 1),
		Vector3.new(tw.x0 + 1, towerTop, tw.z1 - 1),
		wallColor,
		Enum.Material.Concrete,
		{
			Name = "TowerSide",
		}
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(tw.x1 - 1, roofY + 1, tw.z0 + 1),
		Vector3.new(tw.x1, towerTop, tw.z1 - 1),
		wallColor,
		Enum.Material.Concrete,
		{
			Name = "TowerSide",
		}
	)
	Architecture.flatRoof(shell, frame, tw.x0, tw.x1, tw.z0, tw.z1, towerTop, 1, W.Concrete)
	Architecture.windowColumn(shell, frame, tw.z0 + 3, tw.z1 - 3, tw.x0, -1, 27, 32, 5, 3, windows)
	Architecture.windowColumn(shell, frame, tw.z0 + 3, tw.z1 - 3, tw.x1, 1, 27, 32, 5, 3, windows)

	local towerSign = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, 30, tw.z1 + 0.25)),
		Vector2.new(36, 7.5),
		zone.DisplayName,
		{ Background = W.SignGreen, Subtitle = zone.Subtitle, Stripe = W.MutedBlue, PixelsPerStud = 18 }
	)
	towerSign.Name = "TowerSign"

	-- radome (strong silhouette visible across the lobby)
	local domeBase = frame * CFrame.new(0, towerTop + 1.3, -25)
	Kit.post(shell, domeBase, 2.2, 11, W.Concrete, Enum.Material.Concrete, { Name = "RadomeBase" })
	Kit.ball(
		shell,
		17,
		domeBase * CFrame.new(0, 9, 0),
		Color3.fromRGB(222, 220, 210),
		Enum.Material.SmoothPlastic,
		{ Name = "Radome" }
	)
	Kit.post(
		shell,
		domeBase * CFrame.new(0, 8.8, 0),
		0.4,
		17.2,
		Color3.fromRGB(196, 194, 184),
		Enum.Material.SmoothPlastic,
		{
			Name = "RadomeSeam",
			Decor = true,
		}
	)

	-- roof antennas
	for _, pos in { Vector3.new(-44, 0, -8), Vector3.new(44, 0, -56) } do
		local base = frame * CFrame.new(pos.X, roofY + 1, pos.Z)
		Kit.post(shell, base, 16, 0.5, W.Steel, Enum.Material.Metal, { Name = "AntennaMast" })
		for i = 1, 3 do
			Kit.part(
				shell,
				Vector3.new(3.2 - i * 0.6, 0.2, 0.2),
				base * CFrame.new(0, 6 + i * 3, 0),
				W.Steel,
				Enum.Material.Metal,
				{
					Name = "AntennaArm",
					Decor = true,
				}
			)
		end
		local light = Kit.ball(
			shell,
			0.6,
			base * CFrame.new(0, 16.3, 0),
			W.LampRed,
			Enum.Material.Neon,
			{ Name = "WarningLight", Decor = true }
		)
		Kit.anchor(light, "BlinkRed")
	end

	-- rotating surveillance radar on the east roof (animated client-side)
	local radarBase = frame * CFrame.new(38, roofY + 1, -40)
	Kit.post(shell, radarBase, 1.2, 3.4, W.DarkGrey, Enum.Material.Metal, { Name = "RadarTurntable" })
	local radar = Kit.model(shell, "Radar")
	local pivot =
		Kit.part(radar, Vector3.new(0.8, 4, 0.8), radarBase * CFrame.new(0, 3.2, 0), W.Steel, Enum.Material.Metal, {
			Name = "RadarMast",
		})
	radar.PrimaryPart = pivot
	for i, angle in { -0.35, 0, 0.35 } do
		Kit.part(
			radar,
			Vector3.new(3.6, 2.2, 0.3),
			radarBase
				* CFrame.new(math.sin(angle) * 3.4, 5.6, -math.cos(angle) * 0.6 - 0.6)
				* CFrame.Angles(0, angle, 0),
			Color3.fromRGB(200, 198, 188),
			Enum.Material.SmoothPlastic,
			{ Name = "RadarDish" .. i }
		)
	end
	Kit.anchor(pivot, "RadarSpin")

	-- portico: canopy on four columns, with the entrance sign on its fascia
	local canopyY = 14.6
	for _, x in { -15, -9, 9, 15 } do
		Architecture.column(shell, frame, x, 7.6, 0.3, canopyY, 1.6, W.Concrete)
	end
	Kit.box(
		shell,
		frame,
		Vector3.new(-17, canopyY, -0.2),
		Vector3.new(17, canopyY + 1.4, 9.4),
		W.Concrete,
		Enum.Material.Concrete,
		{
			Name = "Canopy",
		}
	)
	-- the tower already carries the name; the portico fascia shows the
	-- building number, stencilled like the rest of the base
	local fascia = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, canopyY + 3.05, 9.25)),
		Vector2.new(22, 3.2),
		"BLDG 101",
		{ Background = W.Charcoal, TextColor = W.OffWhite, PixelsPerStud = 22, Subtitle = "C3 OPERATIONS HALL" }
	)
	fascia.Name = "EntranceSign"
	Kit.box(
		shell,
		frame,
		Vector3.new(-17.05, canopyY - 0.2, 8.6),
		Vector3.new(17.05, canopyY + 1, 9.6),
		W.MutedBlue,
		nil,
		{
			Name = "CanopyStripe",
			Decor = true,
		}
	)

	-- entrance doors
	Architecture.doorFrame(shell, frame, door.Offset, 0, door.Width, door.Height, floorY, W.DarkGrey)
	Architecture.openDoors(shell, frame, door.Offset, -t, door.Width, door.Height, floorY, W.MutedBlue)
	local plate = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(door.Offset + door.Width / 2 + 2.6, 6, 0.3)),
		Vector2.new(3, 2),
		"BLDG 101",
		{ Background = W.OffWhite, TextColor = W.Charcoal, Depth = 0.15, PixelsPerStud = 40 }
	)
	plate.Name = "BuildingNumber"

	-- flags flanking the forecourt
	Architecture.flagpole(model, frame * CFrame.new(-26, 0.3, 3.2), 22, Architecture.Flags.Nato)
	Architecture.flagpole(model, frame * CFrame.new(26, 0.3, 3.2), 22, Architecture.Flags.Base)

	return model, frame
end

return OperationsCenter
