--!strict
-- Military facility signage: direction signposts whose arrows are computed
-- from the real zone positions (so they stay correct if the layout moves).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Architecture = require(script.Parent.Architecture)
local Kit = require(script.Parent.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Signage = {}

local ZONE_STRIPES = {
	OperationsCenter = W.MutedBlue,
	MapRoom = W.Beige,
	CommandHQ = W.MutedRed,
	Garage = W.HazardYellow,
	Leaderboards = W.CrtAmber,
	EventArea = Color3.fromRGB(190, 204, 212),
	MissionBoard = W.Cork,
	SocialArea = W.Wood,
}

-- Screen angle (degrees, 0 = right, -90 = up/ahead) of `target` for a reader
-- standing in front of a sign at `position` that faces `facing`.
function Signage.arrowAngle(position: Vector3, facing: Vector3, target: Vector3): number
	local forward = Vector3.new(-facing.X, 0, -facing.Z).Unit
	local right = forward:Cross(Vector3.new(0, 1, 0))
	local d = Vector3.new(target.X - position.X, 0, target.Z - position.Z).Unit
	local ahead = d:Dot(forward)
	local side = d:Dot(right)
	local angle = math.deg(math.atan2(-ahead, side))
	return math.floor(angle / 45 + 0.5) * 45
end

-- Direction signpost with one plate per destination zone.
function Signage.post(parent: Instance, position: Vector3, facing: Vector3, destinations: { string }): Model
	local model = Kit.model(parent, "Signpost")
	local base = CFrame.new(position)
	local plateH, gap = 1.35, 0.25
	local height = 3.2 + #destinations * (plateH + gap)
	Kit.post(model, base, height, 0.5, W.SteelDark, Enum.Material.Metal, { Name = "Post" })
	local look = CFrame.lookAt(position, position + facing)
	for i, zoneId in destinations do
		local zone = Layout.Zones[zoneId]
		local y = height - (i - 0.5) * (plateH + gap)
		local plateCf = look * CFrame.new(0, y, -0.35)
		local plate = Kit.part(
			model,
			Vector3.new(8.4, plateH, 0.2),
			plateCf,
			W.SignGreen,
			Enum.Material.SmoothPlastic,
			{ Name = "Plate" }
		)
		local gui = Kit.surface(plate, Enum.NormalId.Front, 40, 0.25)
		local target = Layout.entrancePoint(zone)
		local angle = Signage.arrowAngle(position, facing, target)
		local pointsLeft = angle > 90 or angle < -90
		Kit.frame(
			gui,
			UDim2.fromScale(if pointsLeft then 0.97 else 0, 0),
			UDim2.fromScale(0.03, 1),
			ZONE_STRIPES[zoneId] or W.OffWhite
		)
		Architecture.guiArrow(gui, UDim2.fromScale(if pointsLeft then 0.09 else 0.91, 0.5), 40, angle, W.OffWhite)
		Kit.text(gui, {
			Name = "Destination",
			Text = zone.DisplayName,
			Position = UDim2.fromScale(if pointsLeft then 0.18 else 0.05, 0.12),
			Size = UDim2.fromScale(0.76, 0.76),
			XAlign = if pointsLeft then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Font = Theme.font("Header", Enum.FontWeight.Medium),
		})
		plate:SetAttribute("Destination", zoneId)
	end
	return model
end

-- Small standalone sign on a post (e.g. ASSEMBLY POINT, HALT).
function Signage.plaque(
	parent: Instance,
	position: Vector3,
	facing: Vector3,
	text: string,
	style: Kit.SignStyle?,
	size: Vector2?
): Model
	local model = Kit.model(parent, "Plaque")
	local s = size or Vector2.new(6, 2.4)
	local postHeight = 3.4 + s.Y
	Kit.post(model, CFrame.new(position), postHeight, 0.4, W.SteelDark, Enum.Material.Metal, { Name = "Post" })
	local look = CFrame.lookAt(position, position + facing)
	Kit.sign(model, look * CFrame.new(0, postHeight - s.Y / 2, -0.3), s, text, style)
	return model
end

return Signage
