--!strict
-- MISSION BOARD — roofed briefing board on the south edge of the parade
-- square, on the way to the canteen. Phase 3 pins the documents on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local MissionBoard = {}

-- Cork board face (zone-local): centre, size, facing +Z.
MissionBoard.BoardCenter = Vector3.new(0, 5.3, -3.3)
MissionBoard.BoardSize = Vector2.new(15.4, 6.4)

function MissionBoard.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.MissionBoard
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")
	local halfW = zone.Width / 2

	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW + 1, 0.3, -5),
		Vector3.new(halfW - 1, 0.5, 0),
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "Platform" }
	)

	for _, x in { -8.65, 8.65 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.45, 0.5, -3.95),
			Vector3.new(x + 0.45, 10.8, -3.05),
			W.Wood,
			Enum.Material.Wood,
			{ Name = "Post" }
		)
	end

	local c, size = MissionBoard.BoardCenter, MissionBoard.BoardSize
	local board = Kit.part(
		shell,
		Vector3.new(size.X, size.Y, 0.5),
		Kit.facingOut(frame, c),
		W.Cork,
		Enum.Material.Fabric,
		{ Name = "CorkBoard" }
	)
	board:SetAttribute("BoardSurface", "Missions")
	-- wooden frame around the cork
	local fw = 0.45
	local x0, x1 = c.X - size.X / 2, c.X + size.X / 2
	local y0, y1 = c.Y - size.Y / 2, c.Y + size.Y / 2
	for _, seg in
		{
			{ Vector3.new(x0 - fw, y1, c.Z - 0.35), Vector3.new(x1 + fw, y1 + fw, c.Z + 0.4) },
			{ Vector3.new(x0 - fw, y0 - fw, c.Z - 0.35), Vector3.new(x1 + fw, y0, c.Z + 0.4) },
			{ Vector3.new(x0 - fw, y0, c.Z - 0.35), Vector3.new(x0, y1, c.Z + 0.4) },
			{ Vector3.new(x1, y0, c.Z - 0.35), Vector3.new(x1 + fw, y1, c.Z + 0.4) },
		}
	do
		Kit.box(shell, frame, seg[1], seg[2], W.BrownDark, Enum.Material.Wood, { Name = "BoardFrame" })
	end

	Architecture.gableRoof(
		shell,
		frame,
		-9.8,
		9.8,
		-5.2,
		-0.8,
		10.8,
		1.8,
		0.7,
		W.Roof,
		W.Wood,
		Enum.Material.Slate,
		Enum.Material.Wood
	)

	local header = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, 9.85, -2.7)),
		Vector2.new(15.6, 1.3),
		"MISSION BOARD · CURRENT OPERATIONS",
		{ Background = W.SignGreen, TextColor = W.OffWhite, PixelsPerStud = 40, Depth = 0.2 }
	)
	header.Name = "Header"
	return model, frame
end

return MissionBoard
