--!strict
-- Mission board documents: typed operation orders pinned to the cork board
-- with map clippings, photos, pins and string. Each client personalises the
-- checkboxes locally (see client MissionBoardView).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Maps = require(ReplicatedStorage.Lobby.Config.Maps)
local Missions = require(ReplicatedStorage.Lobby.Config.Missions)
local MapDraw = require(ReplicatedStorage.Lobby.Util.MapDraw)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local MissionBoard = {}

local INK = Color3.fromRGB(40, 36, 32)
local FACE_Z = -3.3 + 0.25 + 0.03 -- just in front of the cork face (zone-local)

local function paper(
	parent: Instance,
	frame: CFrame,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	tilt: number
): (Part, SurfaceGui)
	local cf = Kit.facingOut(frame, Vector3.new(x, y, FACE_Z)) * CFrame.Angles(0, 0, math.rad(tilt))
	local sheet = Kit.part(
		parent,
		Vector3.new(w, h, 0.04),
		cf,
		W.Paper,
		Enum.Material.SmoothPlastic,
		{ Name = name, Decor = true }
	)
	local gui = Kit.surface(sheet, Enum.NormalId.Front, 44, 0.6, 70)
	gui.Name = name
	return sheet, gui
end

local function pin(parent: Instance, frame: CFrame, x: number, y: number, color: Color3): Vector3
	local pos = (frame * CFrame.new(x, y, FACE_Z + 0.12)).Position
	Kit.ball(parent, 0.28, CFrame.new(pos), color, Enum.Material.SmoothPlastic, { Name = "Pin", Decor = true })
	return pos
end

local function typed(parent: Instance, name: string, text: string, y: number, h: number, size: number?, color: Color3?)
	return Kit.text(parent, {
		Name = name,
		Text = text,
		Color = color or INK,
		Font = Theme.font("Document"),
		Position = UDim2.fromScale(0.07, y),
		Size = UDim2.fromScale(0.86, h),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = size,
	})
end

function MissionBoard.build(zoneModel: Instance, frame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	local docs = Kit.model(folder, "Documents")

	-- daily operations order
	local _, daily = paper(docs, frame, "DailyOrders", -3.3, 5.3, 5.4, 5.4, -1.5)
	typed(daily, "Header", "CURRENT OPERATIONS", 0.05, 0.1)
	typed(daily, "Date", "DAILY ORDERS · RESET 00:00 UTC", 0.15, 0.06)
	local y = 0.26
	for _, id in Missions.Order do
		local mission = Missions.List[id]
		if mission.Group == "DAILY" then
			typed(daily, "Mission_" .. id, "[ ] " .. mission.Text, y, 0.1)
			y += 0.13
		end
	end
	typed(daily, "Footer", "BY ORDER OF THEATRE COMMAND", 0.86, 0.06, nil, Color3.fromRGB(110, 40, 34))

	-- orientation orders
	local _, orientation = paper(docs, frame, "OrientationOrders", 2.6, 5.15, 4.6, 5.6, 1.8)
	typed(orientation, "Header", "ORIENTATION ORDERS", 0.04, 0.09)
	typed(orientation, "Date", "NEW COMMANDERS · ONE-TIME", 0.13, 0.055)
	y = 0.22
	for _, id in Missions.Order do
		local mission = Missions.List[id]
		if mission.Group == "ORIENTATION" then
			typed(orientation, "Mission_" .. id, "[ ] " .. mission.Text, y, 0.11)
			y += 0.125
		end
	end
	local stamp = Kit.text(orientation, {
		Name = "Stamp",
		Text = "RESTRICTED",
		Color = Color3.fromRGB(150, 50, 44),
		Font = Theme.font("Header", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(0.45, 0.02),
		Size = UDim2.fromScale(0.5, 0.1),
		Rotation = -8,
	})
	stamp.TextTransparency = 0.25

	-- map clipping of the featured battlefield
	local mapCf = Kit.facingOut(frame, Vector3.new(5.6, 6.9, FACE_Z + 0.02)) * CFrame.Angles(0, 0, math.rad(4))
	local clip = Kit.part(
		docs,
		Vector3.new(2.4, 2.1, 0.04),
		mapCf,
		W.Paper,
		Enum.Material.SmoothPlastic,
		{ Name = "MapClipping", Decor = true }
	)
	local mapGui = Kit.surface(clip, Enum.NormalId.Front, 50, 0.6, 70)
	MapDraw.preview(mapGui, Maps.List[Maps.Featured], 2.4 * 50, 2.1 * 50, { labels = false })

	-- photos
	for i, spec in { { 5.3, 4.2, -5 }, { 5.9, 3.0, 7 } } do
		local cf = Kit.facingOut(frame, Vector3.new(spec[1], spec[2], FACE_Z + 0.01))
			* CFrame.Angles(0, 0, math.rad(spec[3]))
		Kit.part(
			docs,
			Vector3.new(1.5, 1.1, 0.04),
			cf,
			Color3.fromRGB(64, 66, 62),
			Enum.Material.SmoothPlastic,
			{ Name = "Photo" .. i, Decor = true }
		)
		Kit.part(
			docs,
			Vector3.new(1.3, 0.9, 0.02),
			cf * CFrame.new(0, 0, -0.03),
			Color3.fromRGB(116, 118, 108),
			Enum.Material.SmoothPlastic,
			{
				Name = "PhotoImage" .. i,
				Decor = true,
			}
		)
	end

	-- pins and red string
	local a = pin(docs, frame, -3.3, 7.8, W.MutedRed)
	local b = pin(docs, frame, 2.6, 7.75, W.MutedBlue)
	local c = pin(docs, frame, 5.6, 7.9, W.MutedRed)
	local d = pin(docs, frame, 5.3, 4.7, W.HazardYellow)
	for _, pair in { { a, b }, { b, d }, { c, d } } do
		local p1, p2 = pair[1], pair[2]
		local mid = (p1 + p2) / 2
		Kit.part(
			docs,
			Vector3.new(0.06, 0.06, (p2 - p1).Magnitude),
			CFrame.lookAt(mid, p2),
			Color3.fromRGB(150, 40, 36),
			nil,
			{
				Name = "String",
				Decor = true,
			}
		)
	end

	local board = zoneModel:FindFirstChild("CorkBoard", true)
	if board and board:IsA("BasePart") then
		Interactions.attach(board, "Missions", "BOARD", "MISSION BOARD")
	end
end

return MissionBoard
