--!strict
-- Operations Center stations: one physical matchmaking terminal per mode
-- (QUICK MATCH / 1v1 / 2v2 / 4v4 / PRIVATE), each with an overhead sign,
-- colour-coded floor pad and a live CRT screen; plus the command wall
-- (theatre map + live deployment board).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Common = require(script.Parent.Common)
local Kit = require(World.Kit)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local GameModes = require(ReplicatedStorage.Lobby.Config.GameModes)
local MapDraw = require(ReplicatedStorage.Lobby.Util.MapDraw)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Operations = {}

Operations.FloorY = 0.6
Operations.CeilingY = 22.6

-- Terminal positions in the Operations Center frame (see Layout).
-- sign centre heights above the hall floor, per terminal
Operations.SignHeights = { ["1V1"] = 10.4, ["2V2"] = 10.4, PRIVATE = 16.8, ["4V4"] = 16.8, QUICK = 16.4 }

Operations.Stations = {
	PRIVATE = Vector3.new(-26, 0, -30),
	["1V1"] = Vector3.new(-13, 0, -26),
	QUICK = Vector3.new(0, 0, -24),
	["2V2"] = Vector3.new(13, 0, -26),
	["4V4"] = Vector3.new(26, 0, -30),
}

local function terminalScreen(screen: Part, mode: GameModes.Mode, number: string)
	local gui, content = Common.screen(screen, "TerminalScreen", 70)
	gui:SetAttribute("ModeId", mode.Id)
	gui:SetAttribute("TerminalNumber", number)
	local phosphor = Common.Phosphor
	Common.line(content, "Header", "C3-NET // OPS TERMINAL " .. number, 0, 0.12, phosphor, Theme.font("Mono"))
	Common.line(
		content,
		"Title",
		mode.Title,
		0.14,
		0.24,
		phosphor,
		Theme.font("Mono", Enum.FontWeight.Bold),
		Enum.TextXAlignment.Center
	)
	Common.line(
		content,
		"Players",
		mode.PlayersLabel,
		0.4,
		0.13,
		phosphor,
		Theme.font("Mono"),
		Enum.TextXAlignment.Center
	)
	Common.line(
		content,
		"QueueCount",
		"IN QUEUE: --",
		0.58,
		0.15,
		Common.Amber,
		Theme.font("Mono", Enum.FontWeight.Bold),
		Enum.TextXAlignment.Center
	)
	local hint = Common.line(
		content,
		"Hint",
		"[E] ACCESS TERMINAL",
		0.82,
		0.13,
		phosphor,
		Theme.font("Mono"),
		Enum.TextXAlignment.Center
	)
	hint:SetAttribute("Blink", true)
end

local function station(parent: Instance, opsFrame: CFrame, modeId: string, index: number): Model
	local mode = GameModes.Modes[modeId]
	local color = Theme.ModeColors[mode.ColorKey]
	local model = Kit.model(parent, "Terminal_" .. modeId)
	local pos = Operations.Stations[modeId] + Vector3.new(0, Operations.FloorY, 0)
	-- face the entrance: local +Z points at the doorway
	local target = Vector3.new(0, Operations.FloorY, 10)
	local away = Vector3.new(pos.X - target.X, 0, pos.Z - target.Z).Unit
	local frame = opsFrame * CFrame.lookAt(pos, pos + away)
	local big = modeId == "QUICK"
	local width = if big then 11 else 8

	-- floor pad in the mode colour: its top 0.05 above the hall floor
	-- (FloorY + 0.05), the coloured edges 0.05 above the pad and inset from
	-- its sides; sized so neighbouring pads never overlap
	local floorTop = 0.05
	local padW, padD = width + 1, 6
	Kit.part(
		model,
		Vector3.new(padW, 0.06, padD),
		frame * CFrame.new(0, floorTop + 0.02, 0.1 + padD / 2),
		W.DarkGrey:Lerp(color, 0.35),
		Enum.Material.SmoothPlastic,
		{
			Name = "FloorPad",
			Decor = true,
		}
	)
	local edgeY = floorTop + 0.075
	for _, seg in
		{
			{ Vector3.new(padW - 0.1, 0.05, 0.4), Vector3.new(0, edgeY, padD - 0.15) },
			{
				Vector3.new(0.4, 0.05, padD - 0.55),
				Vector3.new(-(padW / 2 - 0.25), edgeY, 0.1 + (padD - 0.55) / 2 + 0.05),
			},
			{
				Vector3.new(0.4, 0.05, padD - 0.55),
				Vector3.new(padW / 2 - 0.25, edgeY, 0.1 + (padD - 0.55) / 2 + 0.05),
			},
		}
	do
		Kit.part(
			model,
			seg[1],
			frame * CFrame.new(seg[2]),
			color,
			Enum.Material.SmoothPlastic,
			{ Name = "PadEdge", Decor = true }
		)
	end

	local desk = Common.console(model, frame, width)
	Interactions.attach(desk, "Matchmaking", modeId, mode.TerminalLabel)
	desk:SetAttribute("ModeColor", color)

	-- monitor(s)
	local monitors: { number } = if big then { -2.6, 2.6 } else { 0 }
	for i, x in monitors do
		local screen = Common.crt(model, frame * CFrame.new(x, 3.9, -2.3), 3.4, "Terminal")
		-- same number as the terminal panel ("03"); dual screens are 03A/03B
		local number = ("%02d"):format(index) .. (if #monitors > 1 then (if i == 1 then "A" else "B") else "")
		terminalScreen(screen, mode, number)
	end

	-- equipment rack with blinking lamps
	Kit.part(
		model,
		Vector3.new(1.8, 5.4, 1.8),
		frame * CFrame.new(width / 2 + 1.4, 2.7, -1.8),
		Color3.fromRGB(60, 66, 58),
		Enum.Material.Metal,
		{
			Name = "Rack",
		}
	)
	for i = 1, 3 do
		local lamp = Kit.part(
			model,
			Vector3.new(0.3, 0.3, 0.1),
			frame * CFrame.new(width / 2 + 1.4, 1.4 + i * 1.2, -0.85),
			if i == 2 then W.LampRed else color,
			Enum.Material.Neon,
			{
				Name = "RackLamp",
				Decor = true,
			}
		)
		Kit.anchor(lamp, if i == 2 then "BlinkFast" else "BlinkSlow")
	end

	-- overhead sign. Seen from the doorway the terminals stand in an arc,
	-- so the signs hang at two heights: the inner pair (1V1, 2V2) low, the
	-- outer pair and QUICK MATCH high, clear above the inner signs and the
	-- command wall's display
	local signW = if big then 12 else 8.5
	local signY = Operations.SignHeights[modeId] or 12.6
	local overhead = Common.hangingSign(
		model,
		frame * CFrame.new(0, signY, -1),
		Vector2.new(signW, 3.4),
		Operations.CeilingY,
		mode.SignText,
		{
			Background = W.Charcoal,
			TextColor = W.OffWhite,
			Stripe = color,
			Subtitle = mode.Subtitle,
			PixelsPerStud = 30,
		}
	)
	overhead.Name = "OverheadSign"
	return model
end

local function commandWall(parent: Instance, opsFrame: CFrame)
	local model = Kit.model(parent, "CommandWall")
	local z = -62.35
	local y0, height = 4.4, 15
	local mapW, boardW = 15, 21
	local total = mapW + boardW
	-- frame
	Kit.box(
		model,
		opsFrame,
		Vector3.new(-total / 2 - 0.6, y0 - 0.6, z - 0.4),
		Vector3.new(total / 2 + 0.6, y0 + height + 0.6, z - 0.1),
		W.SteelDark,
		Enum.Material.Metal,
		{
			Name = "WallFrame",
		}
	)
	-- theatre map (square)
	local mapPart = Kit.part(
		model,
		Vector3.new(mapW, height, 0.2),
		Kit.facingOut(opsFrame, Vector3.new(-total / 2 + mapW / 2, y0 + height / 2, z)),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{ Name = "TheaterDisplay" }
	)
	local pps = 25
	local gui = Kit.surface(mapPart, Enum.NormalId.Front, pps, 0.1)
	gui.Name = "TheaterMap"
	MapDraw.theater(gui, mapW * pps, height * pps)
	Kit.anchor(mapPart, "Sound", "RadarBleeps")

	-- deployment board (live queue counts, filled by LobbyStatus)
	local board = Kit.part(
		model,
		Vector3.new(boardW, height, 0.2),
		Kit.facingOut(opsFrame, Vector3.new(total / 2 - boardW / 2, y0 + height / 2, z)),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{ Name = "DeploymentBoard" }
	)
	local bgui, content = Common.screen(board, "DeploymentBoard", 25)
	bgui.MaxDistance = 0
	Common.line(
		content,
		"Header",
		"DEPLOYMENT STATUS // FULDA SECTOR",
		0,
		0.1,
		Common.Amber,
		Theme.font("Mono", Enum.FontWeight.Bold)
	)
	local rows = { "QUICK", "1V1", "2V2", "4V4", "PRIVATE" }
	for i, modeId in rows do
		local mode = GameModes.Modes[modeId]
		local y = 0.14 + (i - 1) * 0.13
		local name = Common.line(content, "Mode_" .. modeId, mode.Title, y, 0.11, Common.Phosphor)
		name.Size = UDim2.fromScale(0.64, 0.11)
		local count =
			Common.line(content, "Count_" .. modeId, "--", y, 0.11, Common.Amber, nil, Enum.TextXAlignment.Right)
		count.Position = UDim2.fromScale(0.64, y)
		count.Size = UDim2.fromScale(0.36, 0.11)
	end
	Common.line(content, "Operation", "CURRENT OPERATION: --", 0.82, 0.08, Common.Phosphor, Theme.font("Mono"))
	Common.line(content, "Clock", "0000Z", 0.91, 0.08, Common.Phosphor, Theme.font("Mono"), Enum.TextXAlignment.Right)
	return model
end

function Operations.build(zoneModel: Instance, opsFrame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	for i, modeId in GameModes.Order do
		station(folder, opsFrame, modeId, i)
	end
	commandWall(folder, opsFrame)
	-- room tone + radio chatter anchors (ambient sound, Phase 5)
	local tone = Kit.part(
		folder,
		Vector3.new(1, 1, 1),
		opsFrame * CFrame.new(0, 16, -34),
		W.Screen,
		nil,
		{ Name = "RoomTone", Transparency = 1, Decor = true }
	)
	Kit.anchor(tone, "Sound", "CommandRoom")
	local radio = Kit.part(
		folder,
		Vector3.new(1, 1, 1),
		opsFrame * CFrame.new(-42, 6, -30),
		W.Screen,
		nil,
		{ Name = "RadioChatter", Transparency = 1, Decor = true }
	)
	Kit.anchor(radio, "Sound", "RadioChatter")
end

return Operations
