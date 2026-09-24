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
		Vector3.new(halfW - 2, 0.34, -30),
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
	-- low side walls framing the court
	for _, x in { -halfW, halfW - 1 } do
		Kit.box(
			shell,
			frame,
			Vector3.new(x, 0, -depth),
			Vector3.new(x + 1, 3, -18),
			W.Concrete,
			Enum.Material.Concrete,
			{ Name = "SideWall" }
		)
	end

	-- steel canopy on two rows of columns
	local y = Leaderboards.CanopyY
	for x = -36, 36, 12 do
		for _, z in { -38, -24 } do
			Kit.box(
				shell,
				frame,
				Vector3.new(x - 0.5, 0.3, z - 0.5),
				Vector3.new(x + 0.5, y, z + 0.5),
				W.SteelDark,
				Enum.Material.Metal,
				{ Name = "Column" }
			)
		end
	end
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 2, y, -depth - 0.5),
		Vector3.new(halfW + 2, y + 1, -22),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "CanopyRoof" }
	)
	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW - 2, y - 1.2, -23),
		Vector3.new(halfW + 2, y, -22),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "CanopyBeam" }
	)

	local sign = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, y + 2.6, -22.2)),
		Vector2.new(46, 3.6),
		"HALL OF COMMANDERS",
		{ Background = W.Charcoal, TextColor = W.CrtAmber, Stripe = W.MutedRed, PixelsPerStud = 24 }
	)
	sign.Name = "EntranceSign"
	local sub = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(0, y - 1.9, -22.3)),
		Vector2.new(20, 1.6),
		zone.DisplayName,
		{ Background = W.SteelDark, TextColor = W.OffWhite, PixelsPerStud = 30, Depth = 0.2 }
	)
	sub.Name = "ZoneName"

	return model, frame
end

return Leaderboards
