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
local STAMP_RED = Color3.fromRGB(150, 50, 44)
local CORK_FACE = -3.3 + 0.25 -- front face of the cork (zone-local z)
-- Every pinned layer sits further out than the one below it, so no two
-- items share a plane: orders, then clippings/photos/cards, then string.
local LAYER_Z = { CORK_FACE + 0.03, CORK_FACE + 0.06, CORK_FACE + 0.09 }

local function paper(
	parent: Instance,
	frame: CFrame,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	tilt: number,
	layer: number,
	color: Color3?
): (Part, SurfaceGui)
	local cf = Kit.facingOut(frame, Vector3.new(x, y, LAYER_Z[layer])) * CFrame.Angles(0, 0, math.rad(tilt))
	local sheet = Kit.part(
		parent,
		Vector3.new(w, h, 0.02),
		cf,
		color or W.Paper,
		Enum.Material.SmoothPlastic,
		{ Name = name, Decor = true }
	)
	sheet:SetAttribute("PinLayer", layer)
	local gui = Kit.surface(sheet, Enum.NormalId.Front, 44, 1, 90)
	gui.Name = name
	return sheet, gui
end

local function pin(parent: Instance, frame: CFrame, x: number, y: number, color: Color3): Vector3
	local pos = (frame * CFrame.new(x, y, CORK_FACE + 0.14)).Position
	Kit.ball(parent, 0.26, CFrame.new(pos), color, Enum.Material.SmoothPlastic, { Name = "Pin", Decor = true })
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

local function stamp(parent: Instance, text: string, x: number, y: number, w: number, h: number, rotation: number)
	local label = Kit.text(parent, {
		Name = "Stamp",
		Text = text,
		Color = STAMP_RED,
		Font = Theme.font("Header", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = rotation,
	})
	label.TextTransparency = 0.2
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = STAMP_RED
	stroke.Thickness = 3
	stroke.Transparency = 0.3
	stroke.Parent = label
	return label
end

local function box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, round: number?)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = f
	end
	return f
end

-- Black-and-white reconnaissance photos drawn with frames: a white print
-- border around a grey scene with a clear silhouette.
local PHOTOS = {
	-- T-72 on a treeline, side view
	Tank = function(image: Frame)
		box(image, 0, 0, 1, 0.55, Color3.fromRGB(150, 152, 146))
		box(image, 0, 0.55, 1, 0.45, Color3.fromRGB(96, 98, 92))
		for i = 0, 5 do
			box(image, i * 0.18 - 0.04, 0.3 + (i % 2) * 0.05, 0.22, 0.3, Color3.fromRGB(112, 114, 108), 0.5)
		end
		local dark = Color3.fromRGB(34, 36, 34)
		box(image, 0.14, 0.62, 0.68, 0.14, dark, 0.4) -- tracks
		box(image, 0.12, 0.5, 0.72, 0.14, dark) -- hull
		box(image, 0.34, 0.38, 0.28, 0.14, dark, 0.5) -- turret
		box(image, 0.6, 0.42, 0.34, 0.035, dark) -- gun
		box(image, 0.46, 0.33, 0.06, 0.06, dark) -- cupola
	end,
	-- Mi-24 helicopter against the sky
	Helicopter = function(image: Frame)
		box(image, 0, 0, 1, 1, Color3.fromRGB(168, 170, 164))
		box(image, 0, 0.82, 1, 0.18, Color3.fromRGB(104, 106, 100))
		local dark = Color3.fromRGB(38, 40, 38)
		box(image, 0.28, 0.42, 0.36, 0.16, dark, 0.5) -- cabin
		box(image, 0.6, 0.46, 0.3, 0.06, dark) -- tail boom
		box(image, 0.86, 0.36, 0.05, 0.16, dark) -- fin
		box(image, 0.1, 0.36, 0.8, 0.025, dark) -- rotor
		box(image, 0.44, 0.37, 0.03, 0.06, dark) -- mast
		box(image, 0.3, 0.58, 0.28, 0.025, dark) -- stub wings
	end,
}

local function photo(parent: Instance, frame: CFrame, name: string, x: number, y: number, tilt: number, kind: string)
	local sheet, gui = paper(parent, frame, name, x, y, 1.5, 1.2, tilt, 2, Color3.fromRGB(236, 234, 226))
	local image = box(gui, 0.07, 0.08, 0.86, 0.72, Color3.fromRGB(120, 122, 116))
	image.Name = "Image"
	image.ClipsDescendants = true
	PHOTOS[kind](image)
	local caption = Kit.text(gui, {
		Name = "Caption",
		Text = if kind == "Tank" then "T-72 · OP ALPHA" else "MI-24 · SECTOR C",
		Color = INK,
		Font = Theme.font("Mono"),
		Position = UDim2.fromScale(0.07, 0.82),
		Size = UDim2.fromScale(0.86, 0.15),
	})
	caption.TextXAlignment = Enum.TextXAlignment.Left
	return sheet
end

-- Board layout (zone-local x/y of each item's centre): the two orders side
-- by side on the left; clipping, photos and the intel card in the right
-- column, so nothing covers an order's text.
MissionBoard.Layout = {
	DailyOrders = { X = -4.7, Y = 5.25, W = 5.2, H = 5.8 },
	OrientationOrders = { X = 0.5, Y = 5.25, W = 4.6, H = 5.8 },
	MapClipping = { X = 4.6, Y = 6.85, W = 2.6, H = 2.3 },
	PhotoTank = { X = 6.72, Y = 7.15, W = 1.5, H = 1.2 },
	PhotoHeli = { X = 6.72, Y = 5.65, W = 1.5, H = 1.2 },
	IntelCard = { X = 5.3, Y = 3.35, W = 3.9, H = 1.9 },
}

function MissionBoard.build(zoneModel: Instance, frame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	local docs = Kit.model(folder, "Documents")
	local L = MissionBoard.Layout

	-- daily operations order
	local _, daily =
		paper(docs, frame, "DailyOrders", L.DailyOrders.X, L.DailyOrders.Y, L.DailyOrders.W, L.DailyOrders.H, -1.2, 1)
	typed(daily, "Header", "CURRENT OPERATIONS", 0.05, 0.1)
	typed(daily, "Date", "DAILY ORDERS · RESET 0000Z", 0.15, 0.06)
	local y = 0.26
	for _, id in Missions.Order do
		local mission = Missions.List[id]
		if mission.Group == "DAILY" then
			typed(daily, "Mission_" .. id, "[ ] " .. mission.Text, y, 0.1)
			y += 0.13
		end
	end
	typed(daily, "Footer", "BY ORDER OF THEATER COMMAND", 0.88, 0.06, nil, Color3.fromRGB(110, 40, 34))

	-- orientation orders
	local o = L.OrientationOrders
	local _, orientation = paper(docs, frame, "OrientationOrders", o.X, o.Y, o.W, o.H, 1.4, 1)
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

	-- map clipping of the featured battlefield
	local m = L.MapClipping
	local clip, mapGui = paper(docs, frame, "MapClipping", m.X, m.Y, m.W, m.H, 3, 2)
	mapGui.PixelsPerStud = 50
	MapDraw.preview(mapGui, Maps.List[Maps.Featured], m.W * 50, m.H * 50, { labels = false })
	clip:SetAttribute("Kind", "Map")

	-- reconnaissance photos
	photo(docs, frame, "PhotoTank", L.PhotoTank.X, L.PhotoTank.Y, -4, "Tank")
	photo(docs, frame, "PhotoHeli", L.PhotoHeli.X, L.PhotoHeli.Y, 5, "Helicopter")

	-- intel summary card with the classification stamp in its empty corner
	local c = L.IntelCard
	local _, card = paper(docs, frame, "IntelCard", c.X, c.Y, c.W, c.H, -1.5, 2, Color3.fromRGB(226, 214, 176))
	typed(card, "Header", "INTEL SUMMARY", 0.08, 0.2)
	typed(card, "Line1", "PACT ARMOR MASSING", 0.34, 0.15).Size = UDim2.fromScale(0.56, 0.15)
	typed(card, "Line2", "NEAR OP ALPHA", 0.5, 0.15).Size = UDim2.fromScale(0.56, 0.15)
	typed(card, "Line3", "EXPECT CONTACT 0400Z", 0.66, 0.15).Size = UDim2.fromScale(0.56, 0.15)
	stamp(card, "RESTRICTED", 0.63, 0.5, 0.34, 0.22, -10)

	-- pins at the top of each item; red string links the intel items only
	pin(docs, frame, L.DailyOrders.X, L.DailyOrders.Y + L.DailyOrders.H / 2 - 0.3, W.MutedRed)
	pin(docs, frame, o.X, o.Y + o.H / 2 - 0.3, W.MutedBlue)
	local a = pin(docs, frame, m.X, m.Y + m.H / 2 - 0.2, W.MutedRed)
	local b = pin(docs, frame, L.PhotoTank.X, L.PhotoTank.Y + 0.42, W.HazardYellow)
	local d = pin(docs, frame, L.PhotoHeli.X, L.PhotoHeli.Y + 0.42, W.HazardYellow)
	local e = pin(docs, frame, c.X + 1.3, c.Y + c.H / 2 - 0.2, W.MutedRed)
	-- the string runs just in front of the pin heads
	local out = frame:VectorToWorldSpace(Vector3.new(0, 0, 0.04))
	for _, pair in { { a, b }, { b, d }, { d, e } } do
		local p1, p2 = pair[1] + out, pair[2] + out
		local mid = (p1 + p2) / 2
		Kit.part(
			docs,
			Vector3.new(0.05, 0.05, (p2 - p1).Magnitude),
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
