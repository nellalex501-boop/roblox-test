--!strict
-- Parade square stations: the 3D theatre map on the central table (relief,
-- rivers, autobahns, the inner-German border, front lines and numbered
-- battle-map markers) and the live status pylons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Common = require(script.Parent.Common)
local Kit = require(World.Kit)
local PlazaZone = require(World.Zones.Plaza)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Maps = require(ReplicatedStorage.Lobby.Config.Maps)
local MapDraw = require(ReplicatedStorage.Lobby.Util.MapDraw)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Plaza = {}

local SIDE = 16.4 -- square relief area on the table (studs)

local function mapToTable(top: CFrame, u: number, v: number, y: number): CFrame
	return top * CFrame.new((u - 0.5) * SIDE, y, (v - 0.5) * SIDE)
end

local function strips(
	model: Instance,
	top: CFrame,
	points: { { number } },
	thickness: number,
	y: number,
	color: Color3,
	dashed: boolean?
)
	-- each strip stands on the relief (top 0.12) up to its layer's top, so
	-- no line hovers over the map
	local topY, bottomY = y + 0.03, 0.11
	local midY = (topY + bottomY) / 2
	for i = 1, #points - 1 do
		local a = mapToTable(top, points[i][1], points[i][2], midY).Position
		local b = mapToTable(top, points[i + 1][1], points[i + 1][2], midY).Position
		local segments = if dashed then math.max(2, math.floor((b - a).Magnitude / 0.8)) else 1
		for s = 0, segments - 1 do
			if not dashed or s % 2 == 0 then
				local p0 = a:Lerp(b, s / segments)
				local p1 = a:Lerp(b, (s + 1) / segments)
				Kit.part(
					model,
					Vector3.new(thickness, topY - bottomY, (p1 - p0).Magnitude + thickness * 0.4),
					CFrame.lookAt((p0 + p1) / 2, p1),
					color,
					Enum.Material.SmoothPlastic,
					{
						Name = "Line",
						Decor = true,
					}
				)
			end
		end
	end
end

local function theaterMap(parent: Instance)
	local model = Kit.model(parent, "TheaterMap")
	local top = PlazaZone.tableFrame()
	local t = Maps.Theater
	Kit.part(
		model,
		Vector3.new(SIDE, 0.12, SIDE),
		top * CFrame.new(0, 0.06, 0),
		Color3.fromRGB(62, 74, 50),
		Enum.Material.Grass,
		{
			Name = "Relief",
			Decor = true,
		}
	)
	-- hills (Vogelsberg / Rhoen) as low mounds
	for _, hill in { { 0.2, 0.5, 4.2 }, { 0.74, 0.54, 3.4 }, { 0.36, 0.14, 2.6 } } do
		Kit.post(
			model,
			mapToTable(top, hill[1], hill[2], 0.1),
			0.35,
			hill[3],
			Color3.fromRGB(78, 90, 60),
			Enum.Material.Grass,
			{ Name = "Hill", Decor = true }
		)
		Kit.post(
			model,
			mapToTable(top, hill[1], hill[2], 0.45),
			0.25,
			hill[3] * 0.55,
			Color3.fromRGB(90, 100, 66),
			Enum.Material.Grass,
			{ Name = "Hill", Decor = true }
		)
	end
	for _, box in t.Forests do
		Kit.part(
			model,
			Vector3.new(box[3] * SIDE, 0.4, box[4] * SIDE),
			mapToTable(top, box[1] + box[3] / 2, box[2] + box[4] / 2, 0.3),
			MapDraw.Colors.Forest,
			Enum.Material.Grass,
			{
				Name = "Forest",
				Decor = true,
			}
		)
	end
	-- map layers stacked 0.06 apart (tops): relief 0.12, rivers 0.18,
	-- autobahns 0.24, border 0.30, NATO front 0.36, Pact axes 0.42
	for _, river in t.Rivers do
		strips(model, top, river, 0.26, 0.15, MapDraw.Colors.Water)
	end
	for _, road in t.Highways do
		strips(model, top, road, 0.22, 0.21, MapDraw.Colors.Highway)
	end
	strips(model, top, t.Border, 0.16, 0.27, MapDraw.Colors.Border, true)
	strips(model, top, t.FrontNato, 0.22, 0.33, MapDraw.Colors.Nato)
	for _, axis in t.AxesPact do
		strips(model, top, axis, 0.3, 0.39, MapDraw.Colors.Pact)
		local last, prev = axis[#axis], axis[#axis - 1]
		local tip = mapToTable(top, last[1], last[2], 0.39).Position
		local from = mapToTable(top, prev[1], prev[2], 0.39).Position
		-- arrowhead: two wedges rolled flat form a triangle pointing forward
		local base = CFrame.lookAt(tip, tip + (tip - from).Unit)
		for _, side in { -1, 1 } do
			Kit.wedge(
				model,
				Vector3.new(0.12, 0.5, 0.9),
				base * CFrame.new(side * 0.25, 0, 0) * CFrame.Angles(0, 0, -side * math.pi / 2),
				MapDraw.Colors.Pact,
				Enum.Material.SmoothPlastic,
				{ Name = "Arrowhead", Decor = true }
			)
		end
	end
	for _, town in t.Towns do
		Kit.part(
			model,
			Vector3.new(0.55, 0.5, 0.55),
			mapToTable(top, town.x, town.y, 0.37),
			MapDraw.Colors.Urban,
			Enum.Material.Concrete,
			{
				Name = "Town",
				Decor = true,
			}
		)
	end
	-- wargame counters along the front
	local rng = Random.new(1987)
	for i = 1, 10 do
		local nato = i % 2 == 0
		local u = (if nato then 0.52 else 0.74) + rng:NextNumber(-0.05, 0.05)
		local v = rng:NextNumber(0.08, 0.92)
		Kit.part(
			model,
			Vector3.new(0.7, 0.44, 0.7),
			mapToTable(top, u, v, 0.34),
			if nato then MapDraw.Colors.Nato else MapDraw.Colors.Pact,
			Enum.Material.SmoothPlastic,
			{
				Name = "Counter",
				Decor = true,
			}
		)
	end
	-- numbered battle map markers (flag pins); the marker blocks rise to
	-- 0.80, clear of every layer below (hills 0.70, towns 0.62, forests 0.50)
	for i, id in Maps.Order do
		local info = Maps.List[id]
		local base = mapToTable(top, info.TheaterPos[1], info.TheaterPos[2], 0.12)
		Kit.part(
			model,
			Vector3.new(0.9, 0.68, 0.9),
			base * CFrame.new(0, 0.34, 0),
			Theme.UI.Accent,
			Enum.Material.SmoothPlastic,
			{
				Name = "MapMarker",
				Decor = true,
			}
		)
		Kit.part(
			model,
			Vector3.new(0.08, 1.8, 0.08),
			base * CFrame.new(0, 1.2, 0),
			W.Steel,
			Enum.Material.Metal,
			{ Name = "FlagPin", Decor = true }
		)
		local tab = Kit.part(
			model,
			Vector3.new(0.9, 0.6, 0.04),
			base * CFrame.new(0.49, 1.8, 0) * CFrame.Angles(0, math.pi, 0),
			Theme.UI.Accent,
			Enum.Material.SmoothPlastic,
			{
				Name = "FlagTab",
				Decor = true,
			}
		)
		local gui = Kit.surface(tab, Enum.NormalId.Front, 60, 1, 70)
		Kit.text(gui, { Text = tostring(i), Color = W.Charcoal, Font = Theme.font("Header", Enum.FontWeight.Bold) })
		tab:SetAttribute("MapId", id)
	end
	-- title and legend plates standing on the table, tilted toward the spawn (south)
	local function plate(x: number, width: number, name: string): (Part, SurfaceGui)
		local cf = top
			* CFrame.new(x, 0.6, SIDE / 2 - 1.2)
			* CFrame.Angles(math.rad(-40), 0, 0)
			* CFrame.Angles(0, math.pi, 0)
		local p = Kit.part(
			model,
			Vector3.new(width, 1.4, 0.1),
			cf,
			W.Charcoal,
			Enum.Material.SmoothPlastic,
			{ Name = name, Decor = true }
		)
		local gui = Kit.surface(p, Enum.NormalId.Front, 50, 1, 90)
		return p, gui
	end
	local titleOffset = PlazaZone.TableSize.X / 2 - 3.6
	local _, titleGui = plate(-titleOffset, 6.2, "TitlePlate")
	Kit.text(titleGui, {
		Name = "Title",
		Text = "THEATER OF OPERATIONS",
		Color = Theme.UI.Accent,
		Position = UDim2.fromScale(0.04, 0.05),
		Size = UDim2.fromScale(0.92, 0.5),
	})
	Kit.text(titleGui, {
		Name = "Subtitle",
		Text = "FULDA SECTOR · 1987",
		Color = W.OffWhite,
		Position = UDim2.fromScale(0.04, 0.55),
		Size = UDim2.fromScale(0.92, 0.4),
		Font = Theme.font("Mono"),
	})
	local _, legendGui = plate(titleOffset, 6.2, "LegendPlate")
	for i, id in Maps.Order do
		local col = (i - 1) // 4
		local row = (i - 1) % 4
		Kit.text(legendGui, {
			Name = "Legend_" .. id,
			Text = ("%d %s"):format(i, Maps.List[id].Name),
			Color = W.OffWhite,
			Font = Theme.font("Mono", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.04 + col * 0.5, 0.05 + row * 0.23),
			Size = UDim2.fromScale(0.46, 0.21),
			XAlign = Enum.TextXAlignment.Left,
		})
	end
	return model
end

local function pylonScreens(root: Instance)
	for _, board in root:GetDescendants() do
		if board:IsA("BasePart") and board:GetAttribute("StatusBoard") then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui = Kit.surface(board, face, 22, 0.1)
				gui.Name = "StatusScreen" .. face.Name
				local bg = Kit.frame(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), W.Screen)
				local content = Kit.frame(bg, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.88), W.Screen, 1)
				content.Name = "Content"
				Common.line(content, "Header", "FULDA GAP // LOBBY STATUS", 0, 0.12, Common.Amber)
				local rows = {
					{ "Online", "COMMANDERS ONLINE" },
					{ "Queued", "IN MATCHMAKING" },
					{ "Deployed", "BATTLES DEPLOYED" },
				}
				for i, row in rows do
					local y = 0.16 + (i - 1) * 0.15
					local labelText = Common.line(content, row[1] .. "Label", row[2], y, 0.12, Common.Phosphor)
					labelText.Size = UDim2.fromScale(0.7, 0.12)
					local value = Common.line(
						content,
						row[1] .. "Value",
						"--",
						y,
						0.12,
						Common.Amber,
						nil,
						Enum.TextXAlignment.Right
					)
					value.Position = UDim2.fromScale(0.7, y)
					value.Size = UDim2.fromScale(0.3, 0.12)
				end
				Common.line(content, "OperationLabel", "CURRENT OPERATION", 0.64, 0.1, Common.Phosphor)
				Common.line(
					content,
					"OperationValue",
					"--",
					0.74,
					0.14,
					Common.Amber,
					Theme.font("Mono", Enum.FontWeight.Bold)
				)
				Common.line(
					content,
					"Clock",
					"0000Z",
					0.9,
					0.1,
					Common.Phosphor,
					Theme.font("Mono"),
					Enum.TextXAlignment.Right
				)
			end
		end
	end
end

function Plaza.build(root: Instance)
	local plaza = root:FindFirstChild("Plaza")
	assert(plaza, "Plaza folder missing")
	local stations = Kit.folder(plaza, "Stations")
	theaterMap(stations)
	local tableBody = plaza:FindFirstChild("TableBody", true)
	if tableBody and tableBody:IsA("BasePart") then
		Interactions.attach(tableBody, "TheaterMap", "THEATER", "THEATER MAP")
	end
	pylonScreens(plaza)
end

return Plaza
