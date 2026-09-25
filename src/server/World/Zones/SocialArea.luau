--!strict
-- SOCIAL AREA — canteen building with an outdoor courtyard. No gameplay
-- systems: a place to wait for friends, sit and hang out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local SocialArea = {}

SocialArea.Canteen = { MinX = -28, MaxX = 28, MinZ = -70, MaxZ = -44, FloorY = 0.6, EaveY = 11 }
SocialArea.Courtyard = { MinX = -42, MaxX = 42, MinZ = -44, MaxZ = -2 }

function SocialArea.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.SocialArea
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")

	local court = SocialArea.Courtyard
	Kit.box(
		shell,
		frame,
		Vector3.new(court.MinX, 0, court.MinZ),
		Vector3.new(court.MaxX, 0.3, court.MaxZ),
		Color3.fromRGB(150, 140, 124),
		Enum.Material.Cobblestone,
		{
			Name = "Courtyard",
			Shadow = false,
		}
	)
	-- low brick wall along the road with three openings
	local wallZ = court.MaxZ - 0.6
	for _, seg in { { court.MinX, -24 }, { -14, -6 }, { 6, 14 }, { 24, court.MaxX } } do
		Kit.box(
			shell,
			frame,
			Vector3.new(seg[1], 0.3, wallZ - 0.5),
			Vector3.new(seg[2], 2.4, wallZ + 0.5),
			W.BrickDark,
			Enum.Material.Brick,
			{
				Name = "CourtWall",
			}
		)
		Kit.box(
			shell,
			frame,
			Vector3.new(seg[1] - 0.1, 2.4, wallZ - 0.6),
			Vector3.new(seg[2] + 0.1, 2.7, wallZ + 0.6),
			W.ConcreteLight,
			Enum.Material.Concrete,
			{
				Name = "CourtWallCap",
				Shadow = false,
			}
		)
	end

	-- canteen building
	local c = SocialArea.Canteen
	local t = 1
	local floorY, eaveY = c.FloorY, c.EaveY
	local canteenFrame = frame * CFrame.new(0, 0, c.MaxZ)
	local halfW, depth = (c.MaxX - c.MinX) / 2, c.MaxZ - c.MinZ
	-- inset under the side and back walls, 0.1 proud of the front
	Kit.box(
		shell,
		canteenFrame,
		Vector3.new(-halfW + 0.1, 0, -depth + 0.1),
		Vector3.new(halfW - 0.1, floorY, 0.1),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{ Name = "Floor" }
	)
	Kit.box(
		shell,
		canteenFrame,
		Vector3.new(-halfW + t, floorY, -depth + t),
		Vector3.new(halfW - t, floorY + 0.05, -t),
		Color3.fromRGB(150, 86, 70),
		Enum.Material.Slate,
		{
			Name = "Tiles",
			Shadow = false,
		}
	)
	local door = { Center = halfW, Width = 10, Bottom = 0, Top = floorY + 9 }
	local plaster = W.Beige
	-- brick base band + plaster above
	local function walls(y0: number, y1: number, color: Color3, material: Enum.Material, front: { Kit.Opening }?)
		Kit.wall(
			shell,
			canteenFrame,
			Vector2.new(-halfW, -t / 2),
			Vector2.new(halfW, -t / 2),
			y0,
			y1,
			t,
			color,
			material,
			front
		)
		Kit.wall(
			shell,
			canteenFrame,
			Vector2.new(-halfW, -depth + t / 2),
			Vector2.new(halfW, -depth + t / 2),
			y0,
			y1,
			t,
			color,
			material
		)
		Kit.wall(
			shell,
			canteenFrame,
			Vector2.new(-halfW + t / 2, -t),
			Vector2.new(-halfW + t / 2, -depth + t),
			y0,
			y1,
			t,
			color,
			material
		)
		Kit.wall(
			shell,
			canteenFrame,
			Vector2.new(halfW - t / 2, -t),
			Vector2.new(halfW - t / 2, -depth + t),
			y0,
			y1,
			t,
			color,
			material
		)
	end
	walls(0, 3, W.BrickDark, Enum.Material.Brick, { door })
	walls(
		3,
		eaveY,
		plaster,
		Enum.Material.Concrete,
		{ { Center = halfW, Width = 10, Bottom = 0, Top = floorY + 9 - 3 } }
	)

	-- big windows on the courtyard side
	local style: Architecture.WindowStyle = { Frame = W.BrownDark, Sill = W.BrownDark, Lit = true }
	Architecture.windowRow(shell, canteenFrame, -halfW + 1, -6, 0, 1, 3.6, 8.6, 4, 4, style)
	Architecture.windowRow(shell, canteenFrame, 6, halfW - 1, 0, 1, 3.6, 8.6, 4, 4, style)
	Architecture.windowColumn(shell, canteenFrame, -depth + 3, -3, -halfW, -1, 3.6, 8.6, 3, 4, style)
	Architecture.windowColumn(shell, canteenFrame, -depth + 3, -3, halfW, 1, 3.6, 8.6, 3, 4, style)

	Architecture.gableRoof(
		shell,
		canteenFrame,
		-halfW - 0.3,
		halfW + 0.3,
		-depth - 0.3,
		0.3,
		eaveY,
		5.5,
		1.6,
		Color3.fromRGB(116, 64, 52),
		plaster,
		Enum.Material.Slate,
		Enum.Material.Concrete
	)
	Kit.box(
		shell,
		canteenFrame,
		Vector3.new(14, eaveY + 1, -depth / 2 - 1.5),
		Vector3.new(17, eaveY + 7.5, -depth / 2 + 1.5),
		W.BrickDark,
		Enum.Material.Brick,
		{
			Name = "Chimney",
		}
	)

	-- wooden awning over the entrance with the canteen sign on top
	Kit.box(
		shell,
		canteenFrame,
		Vector3.new(-7, 9, -0.2),
		Vector3.new(7, 9.6, 4.6),
		W.Wood,
		Enum.Material.WoodPlanks,
		{ Name = "Awning" }
	)
	for _, x in { -6.4, 6.4 } do
		Kit.post(
			shell,
			canteenFrame * CFrame.new(x, 0.3, 4),
			8.8,
			0.5,
			W.BrownDark,
			Enum.Material.Wood,
			{ Name = "AwningPost" }
		)
	end
	local sign = Kit.sign(
		shell,
		Kit.facingOut(canteenFrame, Vector3.new(0, 10.8, 4.2)),
		Vector2.new(15, 2.4),
		"KANTINE · CANTEEN",
		{ Background = W.BrownDark, TextColor = W.Paper, PixelsPerStud = 30, Depth = 0.3 }
	)
	sign.Name = "EntranceSign"
	Architecture.doorFrame(shell, canteenFrame, 0, 0, 10, 9, floorY, W.BrownDark)
	Architecture.openDoors(shell, canteenFrame, 0, -t, 10, 9, floorY, W.Wood)
	local plate = Kit.sign(
		shell,
		-- at the corner, clear of the window row
		Kit.facingOut(canteenFrame, Vector3.new(-halfW + 0.85, 6, 0.3)),
		Vector2.new(1.5, 1.1),
		"BLDG 110",
		{ Background = W.OffWhite, TextColor = W.Charcoal, Depth = 0.15, PixelsPerStud = 40 }
	)
	plate.Name = "BuildingNumber"

	return model, frame
end

return SocialArea
