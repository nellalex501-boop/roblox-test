--!strict
-- Hall of Commanders: five military information boards. The server's
-- LeaderboardService fills the rows (Row1..Row10 -> Rank/Name/Value).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Common = require(script.Parent.Common)
local Kit = require(World.Kit)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Config = require(ReplicatedStorage.Lobby.Config.Leaderboards)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Leaderboards = {}

Leaderboards.Boards = Config.Boards

Leaderboards.Rows = Config.Rows
local SLOTS = require(World.Zones.Leaderboards).Slots

local function board(parent: Instance, frame: CFrame, spec: Config.Board, x: number)
	local model = Kit.model(parent, "Board_" .. spec.Id)
	local size = Vector2.new(12.4, 9.6)
	local z = -38.4
	local centerY = 6.6
	Kit.box(
		model,
		frame,
		Vector3.new(x - size.X / 2 - 0.5, centerY - size.Y / 2 - 0.5, z - 0.35),
		Vector3.new(x + size.X / 2 + 0.5, centerY + size.Y / 2 + 0.5, z - 0.15),
		W.SteelDark,
		Enum.Material.Metal,
		{
			Name = "BoardFrame",
		}
	)
	local screen = Kit.part(
		model,
		Vector3.new(size.X, size.Y, 0.2),
		Kit.facingOut(frame, Vector3.new(x, centerY, z)),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{
			Name = "BoardScreen",
		}
	)
	screen:SetAttribute("BoardId", spec.Id)
	local gui, content = Common.screen(screen, "Leaderboard", 26)
	gui.MaxDistance = 0
	gui:SetAttribute("BoardId", spec.Id)
	Common.line(
		content,
		"Title",
		spec.Title,
		0,
		0.1,
		Common.Amber,
		Theme.font("Header", Enum.FontWeight.Bold),
		Enum.TextXAlignment.Center
	)
	Common.line(
		content,
		"Subtitle",
		spec.Subtitle,
		0.1,
		0.055,
		Common.Phosphor,
		Theme.font("Mono"),
		Enum.TextXAlignment.Center
	)
	local rowH = 0.068
	for i = 1, Leaderboards.Rows do
		local row = Kit.frame(
			content,
			UDim2.fromScale(0, 0.18 + (i - 1) * rowH),
			UDim2.fromScale(1, rowH),
			W.Screen,
			if i % 2 == 0 then 1 else 0.6
		)
		row.Name = "Row" .. i
		local color = if i <= 3 then Common.Amber else Common.Phosphor
		local rank = Common.line(row, "Rank", ("%02d"):format(i), 0, 1, color)
		rank.Size = UDim2.fromScale(0.12, 1)
		local name = Common.line(row, "Name", "—", 0, 1, color)
		name.Position = UDim2.fromScale(0.13, 0)
		name.Size = UDim2.fromScale(0.57, 1)
		local value = Common.line(row, "Value", "", 0, 1, color, nil, Enum.TextXAlignment.Right)
		value.Position = UDim2.fromScale(0.7, 0)
		value.Size = UDim2.fromScale(0.3, 1)
	end
	Common.line(
		content,
		"Footer",
		"AWAITING DATA LINK...",
		0.9,
		0.06,
		Common.Phosphor,
		Theme.font("Mono"),
		Enum.TextXAlignment.Center
	)
	Interactions.attach(screen, "Leaderboard", spec.Id, spec.Title)
	return model
end

function Leaderboards.build(zoneModel: Instance, frame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	for i, spec in Leaderboards.Boards do
		board(folder, frame, spec, SLOTS[i])
	end
end

return Leaderboards
