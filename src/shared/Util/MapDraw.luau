--!strict
-- Draws stylised tactical maps with GUI frames (no image assets).
-- Used for Map Room displays, the Operations Center wall map (SurfaceGuis)
-- and the map UI. Callers pass the exact pixel size of the drawing area so
-- rotated line segments come out at the right angle.

local Config = script.Parent.Parent.Config
local Maps = require(Config.Maps)
local Theme = require(Config.Theme)

local MapDraw = {}

MapDraw.Colors = {
	Land = Color3.fromRGB(58, 70, 50),
	LandDark = Color3.fromRGB(44, 54, 40),
	Grid = Color3.fromRGB(92, 104, 80),
	Forest = Color3.fromRGB(38, 56, 36),
	Urban = Color3.fromRGB(122, 118, 104),
	Water = Color3.fromRGB(64, 88, 108),
	Road = Color3.fromRGB(176, 170, 150),
	Highway = Color3.fromRGB(206, 178, 110),
	Rail = Color3.fromRGB(30, 30, 30),
	Nato = Color3.fromRGB(96, 136, 176),
	Pact = Color3.fromRGB(186, 74, 60),
	Label = Color3.fromRGB(226, 222, 206),
	Border = Color3.fromRGB(196, 70, 56),
}

local C = MapDraw.Colors

local function frame(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	z: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

-- Thick line between two pixel points (a rotated frame).
function MapDraw.segment(
	parent: Instance,
	a: Vector2,
	b: Vector2,
	thickness: number,
	color: Color3,
	z: number?,
	name: string?
): Frame
	local delta = b - a
	local length = delta.Magnitude
	local f = Instance.new("Frame")
	f.Name = name or "Segment"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(length + thickness * 0.6, thickness)
	f.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	f.ZIndex = z or 2
	f.Parent = parent
	return f
end

local function polyline(
	parent: Instance,
	points: { { number } },
	w: number,
	h: number,
	thickness: number,
	color: Color3,
	z: number?,
	dashed: boolean?
)
	for i = 1, #points - 1 do
		local a = Vector2.new(points[i][1] * w, points[i][2] * h)
		local b = Vector2.new(points[i + 1][1] * w, points[i + 1][2] * h)
		if dashed then
			local delta = b - a
			local steps = math.max(1, math.floor(delta.Magnitude / (thickness * 5)))
			for s = 0, steps - 1, 2 do
				MapDraw.segment(
					parent,
					a + delta * (s / steps),
					a + delta * ((s + 1) / steps),
					thickness,
					color,
					z,
					"Dash"
				)
			end
		else
			MapDraw.segment(parent, a, b, thickness, color, z)
		end
	end
end

local function label(
	parent: Instance,
	text: string,
	x: number,
	y: number,
	size: number,
	color: Color3,
	z: number?,
	anchor: Vector2?
)
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.BackgroundTransparency = 1
	t.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(size * #text * 0.62 + 8, size * 1.3)
	t.Text = text
	t.TextColor3 = color
	t.TextSize = size
	t.FontFace = Theme.font("Mono", Enum.FontWeight.Bold)
	t.TextStrokeTransparency = 0.35
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	t.ZIndex = z or 6
	t.Parent = parent
	return t
end

local function grid(parent: Instance, w: number, h: number, divisions: number)
	for i = 1, divisions - 1 do
		frame(parent, "GridV", w * i / divisions, 0, 1, h, C.Grid, 1).BackgroundTransparency = 0.6
		frame(parent, "GridH", 0, h * i / divisions, w, 1, C.Grid, 1).BackgroundTransparency = 0.6
	end
end

local SECTOR_LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H" }

-- Top-down preview of one battle map inside `parent` (w x h pixels).
function MapDraw.preview(
	parent: Instance,
	map: Maps.MapInfo,
	w: number,
	h: number,
	options: { labels: boolean?, spawns: boolean? }?
)
	local opts: { labels: boolean?, spawns: boolean? } = options or {}
	local p = map.Preview
	local water: { Maps.Box } = p.Water or {}
	local rivers: { Maps.Polyline } = p.Rivers or {}
	local rails: { Maps.Polyline } = p.Rail or {}
	local highways: { Maps.Polyline } = p.Highways or {}
	local canvas = frame(parent, "MapCanvas", 0, 0, w, h, C.Land, 1)
	canvas.ClipsDescendants = true
	grid(canvas, w, h, 6)
	for _, box in water do
		frame(canvas, "Water", box[1] * w, box[2] * h, box[3] * w, box[4] * h, C.Water, 2)
	end
	for _, box in p.Forests do
		local f = frame(canvas, "Forest", box[1] * w, box[2] * h, box[3] * w, box[4] * h, C.Forest, 2)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = f
	end
	for _, river in rivers do
		polyline(canvas, river, w, h, math.max(3, (p.RiverWidth or 0.03) * w), C.Water, 3)
	end
	for _, rail in rails do
		polyline(canvas, rail, w, h, math.max(2, w * 0.006), C.Rail, 4, true)
	end
	for _, road in p.Roads do
		polyline(canvas, road, w, h, math.max(2, w * 0.009), C.Road, 4)
	end
	for _, road in highways do
		polyline(canvas, road, w, h, math.max(4, w * 0.02), C.Highway, 4)
	end
	for _, box in p.Urban do
		frame(canvas, "Urban", box[1] * w, box[2] * h, box[3] * w, box[4] * h, C.Urban, 5)
	end
	local markSize = math.max(10, w * 0.045)
	for i, s in p.Sectors do
		local m = frame(
			canvas,
			"Sector",
			s[1] * w - markSize / 2,
			s[2] * h - markSize / 2,
			markSize,
			markSize,
			Color3.fromRGB(20, 24, 20),
			7
		)
		local stroke = Instance.new("UIStroke")
		stroke.Color = C.Label
		stroke.Thickness = math.max(1, markSize * 0.08)
		stroke.Parent = m
		label(m, SECTOR_LETTERS[i] or "?", markSize / 2, markSize / 2, markSize * 0.7, C.Label, 8)
	end
	if opts.spawns ~= false then
		for faction, pos in p.Spawns :: { [string]: { number } } do
			local color = if faction == "NATO" then C.Nato else C.Pact
			local s = markSize * 1.2
			frame(canvas, faction .. "Spawn", pos[1] * w - s / 2, pos[2] * h - s / 2, s, s, color, 7)
		end
	end
	local lm = p.Landmark
	local d = frame(
		canvas,
		"Landmark",
		lm.x * w - markSize * 0.45,
		lm.y * h - markSize * 0.45,
		markSize * 0.9,
		markSize * 0.9,
		Theme.UI.Accent,
		8
	)
	d.Rotation = 45
	if opts.labels ~= false then
		label(canvas, lm.label, lm.x * w, lm.y * h - markSize * 1.1, math.max(9, w * 0.032), C.Label, 9)
	end
	return canvas
end

-- Regional theatre map with the battle maps marked on it.
function MapDraw.theater(parent: Instance, w: number, h: number, options: { highlight: string? }?)
	local opts: { highlight: string? } = options or {}
	local t = Maps.Theater
	local canvas = frame(parent, "TheaterCanvas", 0, 0, w, h, C.LandDark, 1)
	canvas.ClipsDescendants = true
	grid(canvas, w, h, 8)
	for _, box in t.Forests do
		local f = frame(canvas, "Forest", box[1] * w, box[2] * h, box[3] * w, box[4] * h, C.Forest, 2)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = f
	end
	for _, river in t.Rivers do
		polyline(canvas, river, w, h, math.max(3, w * 0.008), C.Water, 3)
	end
	for _, road in t.Highways do
		polyline(canvas, road, w, h, math.max(3, w * 0.007), C.Highway, 4)
	end
	polyline(canvas, t.Border, w, h, math.max(3, w * 0.006), C.Border, 5, true)
	polyline(canvas, t.FrontNato, w, h, math.max(3, w * 0.006), C.Nato, 5)
	for _, axis in t.AxesPact do
		polyline(canvas, axis, w, h, math.max(4, w * 0.009), C.Pact, 5)
	end
	local fontSize = math.max(9, w * 0.022)
	local mark = math.max(12, w * 0.03)
	-- labels are placed greedily so none covers another label or a marker:
	-- markers and towns first (fixed), then town names (right, else left),
	-- then map names (below, above, right, left of the marker, whichever
	-- is free first), all inside the canvas
	type Box = { x0: number, y0: number, x1: number, y1: number }
	local taken: { Box } = {}
	local function free(b: Box): boolean
		if b.x0 < 2 or b.y0 < 2 or b.x1 > w - 2 or b.y1 > h - 2 then
			return false
		end
		for _, o in taken do
			if b.x0 < o.x1 and o.x0 < b.x1 and b.y0 < o.y1 and o.y0 < b.y1 then
				return false
			end
		end
		return true
	end
	local function labelBox(text: string, size: number, x: number, y: number, anchor: Vector2): Box
		local lw, lh = size * #text * 0.62 + 8, size * 1.3
		local x0, y0 = x - anchor.X * lw, y - anchor.Y * lh
		return { x0 = x0, y0 = y0, x1 = x0 + lw, y1 = y0 + lh }
	end
	local townSize = math.max(5, w * 0.012)
	for _, town in t.Towns do
		local x, y = town.x * w, town.y * h
		table.insert(
			taken,
			{ x0 = x - townSize / 2, y0 = y - townSize / 2, x1 = x + townSize / 2, y1 = y + townSize / 2 }
		)
	end
	for _, id in Maps.Order do
		local info = Maps.List[id]
		local x, y = info.TheaterPos[1] * w, info.TheaterPos[2] * h
		table.insert(
			taken,
			{ x0 = x - mark / 2 - 2, y0 = y - mark / 2 - 2, x1 = x + mark / 2 + 2, y1 = y + mark / 2 + 2 }
		)
	end
	local function place(text: string, size: number, candidates: { { number | Vector2 } }): (number, number, Vector2)
		for _, c in candidates do
			local x, y, anchor = c[1] :: number, c[2] :: number, c[3] :: Vector2
			local b = labelBox(text, size, x, y, anchor)
			if free(b) then
				table.insert(taken, b)
				return x, y, anchor
			end
		end
		local first = candidates[1]
		return first[1] :: number, first[2] :: number, first[3] :: Vector2
	end
	for _, town in t.Towns do
		local x, y = town.x * w, town.y * h
		frame(canvas, "Town", x - townSize / 2, y - townSize / 2, townSize, townSize, C.Urban, 6)
		local size = fontSize * 0.85
		local lx, ly, anchor = place(town.label, size, {
			{ x + townSize, y, Vector2.new(0, 0.5) },
			{ x - townSize, y, Vector2.new(1, 0.5) },
			{ x, y - townSize, Vector2.new(0.5, 1) },
			{ x, y + townSize, Vector2.new(0.5, 0) },
		})
		label(canvas, town.label, lx, ly, size, C.Label, 7, anchor)
	end
	for i, id in Maps.Order do
		local info = Maps.List[id]
		local x, y = info.TheaterPos[1] * w, info.TheaterPos[2] * h
		local highlighted = opts.highlight == id
		local m = frame(
			canvas,
			"MapMarker",
			x - mark / 2,
			y - mark / 2,
			mark,
			mark,
			if highlighted then Theme.UI.Accent else Color3.fromRGB(24, 28, 24),
			8
		)
		m:SetAttribute("MapId", id)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.UI.Accent
		stroke.Thickness = math.max(1, mark * 0.1)
		stroke.Parent = m
		label(
			m,
			tostring(i),
			mark / 2,
			mark / 2,
			mark * 0.7,
			if highlighted then Color3.new(0, 0, 0) else Theme.UI.Accent,
			9
		)
		local gap = mark / 2 + 3
		local lx, ly, anchor = place(info.Name, fontSize, {
			{ x, y + gap, Vector2.new(0.5, 0) },
			{ x, y - gap, Vector2.new(0.5, 1) },
			{ x + gap, y, Vector2.new(0, 0.5) },
			{ x - gap, y, Vector2.new(1, 0.5) },
			{ x + gap, y + gap, Vector2.new(0, 0) },
			{ x - gap, y + gap, Vector2.new(1, 0) },
			{ x + gap, y - gap, Vector2.new(0, 1) },
			{ x - gap, y - gap, Vector2.new(1, 1) },
		})
		local name = label(canvas, info.Name, lx, ly, fontSize, C.Label, 9, anchor)
		name.Name = "MapLabel"
		name:SetAttribute("MapId", id)
	end
	return canvas
end

return MapDraw
