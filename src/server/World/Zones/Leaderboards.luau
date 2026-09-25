--!strict
-- LEADERBOARDS — "Hall of Commanders": a paved court with a long steel
-- canopy sheltering the display boards along its back wall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Leaderboards = {}

-- Board slots along the back wall (zone-local x), boards face +Z.
Leaderboards.Slots = { -28, -14, 0, 14, 28 }
-- Canopy columns, halfway between the boards.
Leaderboards.Columns = { -35, -21, -7, 7, 21, 35 }
Leaderboards.BoardZ = -37.4
Leaderboards.CanopyY = 17

function Leaderboards.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.Leaderboards
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")
	local halfW, depth = zone.Width / 2, zone.Depth

	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW, 0, -depth),
		Vector3.new(halfW, 0.3, 0),
		W.ConcreteLight,
		Enum.Material.Pavement,
		{
			Name = "Court",
			Shadow = false,
		}
	)
	-- dark paving band in front of the boards
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW + 2, 0.3, -34),
		Vector3.new(halfW - 2, 0.36, -30),
		W.DarkGrey,
		Enum.Material.Slate,
		{
			Name = "BoardApron",
			Decor = true,
		}
	)

	-- back wall the boards hang on
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW, 0, -depth),
		Vector3.new(halfW, 12, -depth + 1.2),
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "BackWall" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 0.2, 12, -depth - 0.2),
		Vector3.new(halfW + 0.2, 12.5, -depth + 1.4),
		W.ConcreteLight,
		Enum.Material.Concrete,
		{
			Name = "Coping",
		}
	)
	-- low side walls framing the court (butting against the back wall)
	for _, x in { -halfW, halfW - 1 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x, 0, -depth + 1.2),
			Vector3.new(x + 1, 3, -18),
			W.Concrete,
			Enum.Material.Concrete,
			{ Name = "SideWall" }
		)
	end

	-- steel canopy: the columns stand between the boards (boards every 14
	-- studs, columns offset by 7), the back row set into the back wall, so
	-- no column ever stands in front of a board
	local y = Leaderboards.CanopyY
	for _, x in Leaderboards.Columns do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.6, 0.3, -23.1),
			Vector3.new(x + 0.6, y, -21.9),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "Column" }
		)
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.5, 0, -39.9),
			Vector3.new(x + 0.5, y, -38.9),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "WallColumn" }
		)
		-- base plate
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.9, 0.3, -23.4),
			Vector3.new(x + 0.9, 0.45, -21.6),
			W.Steel,
			Enum.Material.Metal,
			{ Name = "ColumnBase" }
		)
	end
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 2, y, -depth - 0.5),
		Vector3.new(halfW + 2, y + 1, -21.5),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "CanopyRoof" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 1.9, y - 1.2, -23.2),
		Vector3.new(halfW + 1.9, y, -21.8),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "CanopyBeam" }
	)

	-- the name sits on top of the canopy, set back from its front edge
	local sign = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, y + 1 + 1.8, -22.0)),
		Vector2.new(46, 3.6),
		"HALL OF COMMANDERS",
		{ Background = W.Charcoal, TextColor = W.CrtAmber, Stripe = W.MutedRed, PixelsPerStud = 18 }
	)
	sign.Name = "EntranceSign"
	for _, x in { -18, 0, 18 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.2, y + 1, -22.9),
			Vector3.new(x + 0.2, y + 3.2, -22.2),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "SignStay" }
		)
	end

	return model, frame
end

return Leaderboards
