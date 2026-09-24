--!strict
-- Low-poly prop library for detailing (Phase 4): street furniture, military
-- clutter, utility, interior furniture and light fittings.
--
-- Convention: every prop is built in a local frame `cf` whose origin is on
-- the floor under the prop's centre, front facing -Z (LookVector). Small
-- parts use Decor (no collision/query/shadow); bodies a player could walk
-- into keep collision. Light fittings add non-shadowed lights only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Props = {}

local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local CONCRETE = Enum.Material.Concrete
local PLASTIC = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric

Props.LampColor = Color3.fromRGB(255, 196, 132) -- sodium / tungsten warm
Props.TubeColor = Color3.fromRGB(236, 240, 228) -- fluorescent

local function decor(name: string): Kit.Opts
	return { Name = name, Decor = true }
end

local function solid(name: string): Kit.Opts
	return { Name = name, Shadow = true }
end

-- Street furniture -----------------------------------------------------------

function Props.bench(parent: Instance, cf: CFrame, length: number?): Model
	local model = Kit.model(parent, "Bench")
	local l = length or 6
	for _, x in { -l / 2 + 0.6, l / 2 - 0.6 } do
		Kit.part(model, Vector3.new(0.5, 1.5, 1.8), cf * CFrame.new(x, 0.75, 0), W.ConcreteDark, CONCRETE, solid("Leg"))
	end
	for i = 0, 2 do
		Kit.part(
			model,
			Vector3.new(l, 0.18, 0.5),
			cf * CFrame.new(0, 1.55, -0.6 + i * 0.6),
			W.Wood,
			WOOD,
			{ Name = "Slat", Shadow = i == 1 }
		)
	end
	Kit.part(
		model,
		Vector3.new(l, 0.9, 0.18),
		cf * CFrame.new(0, 2.4, 0.95) * CFrame.Angles(math.rad(-12), 0, 0),
		W.Wood,
		WOOD,
		decor("Backrest")
	)
	return model
end

function Props.picnicTable(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "PicnicTable")
	Kit.part(model, Vector3.new(6, 0.25, 2.6), cf * CFrame.new(0, 2.6, 0), W.Wood, WOOD, solid("TableTop"))
	for _, z in { -1.9, 1.9 } do
		Kit.part(model, Vector3.new(6, 0.22, 0.9), cf * CFrame.new(0, 1.5, z), W.Wood, WOOD, solid("Seat"))
	end
	for _, x in { -2.3, 2.3 } do
		for _, s in { -1, 1 } do
			Kit.part(
				model,
				Vector3.new(0.3, 3.1, 0.3),
				cf * CFrame.new(x, 1.35, 0) * CFrame.Angles(math.rad(34 * s), 0, 0),
				W.BrownDark,
				WOOD,
				decor("Leg")
			)
		end
		Kit.part(model, Vector3.new(0.3, 0.25, 4.6), cf * CFrame.new(x, 1.3, 0), W.BrownDark, WOOD, decor("Brace"))
	end
	return model
end

-- Cobra-head street lamp; `light` adds a warm non-shadowed PointLight.
function Props.streetLamp(parent: Instance, cf: CFrame, light: boolean?, height: number?): Model
	local model = Kit.model(parent, "StreetLamp")
	local h = height or 16
	Kit.post(model, cf, 0.8, 1.1, W.ConcreteDark, CONCRETE, solid("Footing"))
	Kit.post(model, cf * CFrame.new(0, 0.8, 0), h - 0.8, 0.5, W.SteelDark, METAL, solid("Pole"))
	Kit.part(model, Vector3.new(0.3, 0.3, 3.2), cf * CFrame.new(0, h - 0.1, -1.4), W.SteelDark, METAL, decor("Arm"))
	Kit.part(model, Vector3.new(1.2, 0.5, 1.8), cf * CFrame.new(0, h - 0.2, -3.1), W.SteelDark, METAL, decor("Head"))
	local lens = Kit.part(
		model,
		Vector3.new(0.9, 0.12, 1.4),
		cf * CFrame.new(0, h - 0.5, -3.1),
		Props.LampColor,
		Enum.Material.Neon,
		decor("Lens")
	)
	if light then
		local point = Instance.new("PointLight")
		point.Name = "LampLight"
		point.Color = Props.LampColor
		point.Brightness = 1.1
		point.Range = 26
		point.Shadows = false
		point.Parent = lens
	end
	return model
end

-- Short bollard lamp for paths and courtyards (no light by default).
function Props.bollardLamp(parent: Instance, cf: CFrame, light: boolean?): Model
	local model = Kit.model(parent, "BollardLamp")
	Kit.post(model, cf, 3, 0.8, W.SteelDark, METAL, solid("Post"))
	local cap = Kit.post(model, cf * CFrame.new(0, 3, 0), 0.5, 0.9, Props.LampColor, Enum.Material.Neon, decor("Cap"))
	if light then
		local point = Instance.new("PointLight")
		point.Name = "LampLight"
		point.Color = Props.LampColor
		point.Brightness = 0.7
		point.Range = 12
		point.Shadows = false
		point.Parent = cap
	end
	return model
end

function Props.trashBin(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "TrashBin")
	Kit.post(model, cf, 2.6, 1.8, W.OliveDark, METAL, solid("Body"))
	Kit.post(model, cf * CFrame.new(0, 2.6, 0), 0.2, 2, W.SteelDark, METAL, decor("Lid"))
	return model
end

function Props.oilDrum(parent: Instance, cf: CFrame, color: Color3?): Model
	local model = Kit.model(parent, "OilDrum")
	local c = color or W.OliveDark
	Kit.post(model, cf, 2.9, 1.9, c, METAL, solid("Drum"))
	for _, y in { 0.9, 2 } do
		Kit.post(model, cf * CFrame.new(0, y, 0), 0.12, 1.98, W.SteelDark, METAL, decor("Hoop"))
	end
	return model
end

-- Cluster of drums around a point (deterministic by count).
function Props.drumCluster(parent: Instance, cf: CFrame, count: number, color: Color3?): Model
	local model = Kit.model(parent, "DrumCluster")
	local spots = { { 0, 0 }, { 2, 0.2 }, { 1, -1.8 }, { -1.1, -1.6 }, { 3, -1.6 }, { -2, 0.4 } }
	for i = 1, math.min(count, #spots) do
		local s = spots[i]
		Props.oilDrum(model, cf * CFrame.new(s[1], 0, s[2]) * CFrame.Angles(0, i * 0.7, 0), color)
	end
	return model
end

function Props.jerrycans(parent: Instance, cf: CFrame, count: number): Model
	local model = Kit.model(parent, "Jerrycans")
	for i = 1, count do
		local x = (i - (count + 1) / 2) * 0.8
		Kit.part(model, Vector3.new(0.6, 1.4, 1.1), cf * CFrame.new(x, 0.7, 0), W.OliveDark, METAL, decor("Can"))
		Kit.part(model, Vector3.new(0.3, 0.2, 0.5), cf * CFrame.new(x, 1.5, -0.2), W.OliveDark, METAL, decor("Handle"))
	end
	return model
end

-- Wooden / olive crate; returns the crate part (for stacking).
function Props.crate(parent: Instance, cf: CFrame, size: Vector3?, color: Color3?): Part
	local s = size or Vector3.new(2.6, 2, 2)
	local crate = Kit.part(
		parent,
		s,
		cf * CFrame.new(0, s.Y / 2, 0),
		color or W.OliveDark,
		WOOD,
		{ Name = "Crate", Shadow = true }
	)
	-- darker band so boxes read as crates, not blocks
	Kit.part(
		parent,
		Vector3.new(s.X + 0.06, 0.25, s.Z + 0.06),
		cf * CFrame.new(0, s.Y * 0.62, 0),
		W.BrownDark,
		WOOD,
		decor("CrateBand")
	)
	return crate
end

function Props.crateStack(parent: Instance, cf: CFrame, layout: string?): Model
	local model = Kit.model(parent, "CrateStack")
	local green, wood = W.OliveDark, W.Wood
	Props.crate(model, cf * CFrame.new(-1.4, 0, 0), nil, green)
	Props.crate(model, cf * CFrame.new(1.4, 0, 0.2) * CFrame.Angles(0, 0.08, 0), nil, green)
	Props.crate(model, cf * CFrame.new(-0.2, 2, 0.1) * CFrame.Angles(0, -0.12, 0), Vector3.new(2.4, 1.6, 1.8), wood)
	if layout == "wide" then
		Props.crate(model, cf * CFrame.new(3.9, 0, -0.4), Vector3.new(2, 1.4, 1.6), wood)
	end
	return model
end

function Props.pallet(parent: Instance, cf: CFrame, loaded: boolean?): Model
	local model = Kit.model(parent, "Pallet")
	Kit.part(model, Vector3.new(4, 0.5, 3.2), cf * CFrame.new(0, 0.25, 0), W.Wood, WOOD, solid("Deck"))
	if loaded then
		Kit.part(
			model,
			Vector3.new(3.6, 2.2, 2.8),
			cf * CFrame.new(0, 1.6, 0),
			Color3.fromRGB(118, 110, 86),
			FABRIC,
			solid("Load")
		)
	end
	return model
end

-- Row of sandbags along local X (two courses, staggered).
function Props.sandbags(parent: Instance, cf: CFrame, length: number, courses: number?): Model
	local model = Kit.model(parent, "Sandbags")
	local n = math.max(1, math.floor(length / 1.6))
	local tan = Color3.fromRGB(150, 136, 102)
	for course = 0, (courses or 2) - 1 do
		local offset = if course % 2 == 1 then 0.8 else 0
		for i = 0, n - 1 do
			local x = -length / 2 + 0.8 + i * 1.6 + offset
			if x <= length / 2 - 0.6 then
				Kit.part(
					model,
					Vector3.new(1.55, 0.7, 1.1),
					cf * CFrame.new(x, 0.35 + course * 0.66, 0) * CFrame.Angles(0, (i % 3 - 1) * 0.04, 0),
					if (i + course) % 2 == 0 then tan else Color3.fromRGB(138, 124, 92),
					FABRIC,
					{ Name = "Sandbag", Shadow = course == 0 }
				)
			end
		end
	end
	return model
end

function Props.jerseyBarrier(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "JerseyBarrier")
	Kit.part(model, Vector3.new(6, 1, 2), cf * CFrame.new(0, 0.5, 0), W.Concrete, CONCRETE, solid("Base"))
	Kit.part(model, Vector3.new(6, 1.8, 0.9), cf * CFrame.new(0, 1.9, 0), W.Concrete, CONCRETE, solid("Wall"))
	Kit.part(model, Vector3.new(6.05, 0.3, 0.95), cf * CFrame.new(0, 2.3, 0), W.HazardYellow, CONCRETE, decor("Stripe"))
	return model
end

function Props.tireStack(parent: Instance, cf: CFrame, count: number?): Model
	local model = Kit.model(parent, "TireStack")
	for i = 0, (count or 4) - 1 do
		Kit.post(
			model,
			cf * CFrame.new(0, i * 0.85, 0) * CFrame.Angles(0, i * 0.4, 0),
			0.8,
			3,
			W.Rubber,
			PLASTIC,
			{ Name = "Tire", Shadow = i == 0 }
		)
	end
	return model
end

function Props.fireExtinguisher(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "FireExtinguisher")
	Kit.post(model, cf, 1.5, 0.55, W.MutedRed, METAL, decor("Bottle"))
	Kit.part(model, Vector3.new(0.3, 0.25, 0.5), cf * CFrame.new(0, 1.62, -0.1), W.Charcoal, METAL, decor("Valve"))
	return model
end

-- Utility -------------------------------------------------------------------

-- Wooden telegraph pole with a cross-arm; returns the model and the world
-- positions of the three insulators (for wires).
function Props.utilityPole(parent: Instance, cf: CFrame, height: number?): (Model, { Vector3 })
	local model = Kit.model(parent, "UtilityPole")
	local h = height or 22
	Kit.post(model, cf, h, 0.9, W.BrownDark, WOOD, solid("Pole"))
	Kit.part(model, Vector3.new(6, 0.45, 0.45), cf * CFrame.new(0, h - 1.4, 0), W.BrownDark, WOOD, decor("CrossArm"))
	local tips = {}
	for _, x in { -2.6, 0, 2.6 } do
		local tip = cf * CFrame.new(x, h - 0.95, 0)
		Kit.post(model, cf * CFrame.new(x, h - 1.2, 0), 0.5, 0.3, W.OffWhite, PLASTIC, decor("Insulator"))
		table.insert(tips, tip.Position)
	end
	-- transformer can on every pole with a street lamp arm feel
	Kit.post(model, cf * CFrame.new(0.9, h - 5.5, 0), 2, 1.3, W.SteelDark, METAL, decor("Transformer"))
	return model, tips
end

-- Sagging wire between two points, built from short straight segments.
function Props.wire(parent: Instance, a: Vector3, b: Vector3, sag: number?, segments: number?)
	local n = segments or 4
	local droop = sag or 1.6
	local prev = a
	for i = 1, n do
		local t = i / n
		local point = a:Lerp(b, t) - Vector3.new(0, droop * 4 * t * (1 - t), 0)
		local mid = (prev + point) / 2
		local length = (point - prev).Magnitude
		if length > 0.05 then
			Kit.part(
				parent,
				Vector3.new(0.12, 0.12, length),
				CFrame.lookAt(mid, point),
				W.Charcoal,
				PLASTIC,
				decor("Wire")
			)
		end
		prev = point
	end
end

function Props.loudspeakerPole(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "LoudspeakerPole")
	Kit.post(model, cf, 14, 0.5, W.SteelDark, METAL, solid("Pole"))
	for i, angle in { 0, 2.3 } do
		local horn = cf * CFrame.new(0, 12.6 + i * 0.1, 0) * CFrame.Angles(0, angle, 0)
		Kit.part(model, Vector3.new(0.8, 0.8, 1.6), horn * CFrame.new(0, 0, -0.8), W.OliveLight, METAL, decor("Horn"))
		Kit.part(model, Vector3.new(1.4, 1.4, 0.2), horn * CFrame.new(0, 0, -1.65), W.OliveLight, METAL, decor("Bell"))
	end
	return model
end

-- Floodlight mast (compound / motor pool lighting).
function Props.floodlight(parent: Instance, cf: CFrame, light: boolean?): Model
	local model = Kit.model(parent, "Floodlight")
	Kit.post(model, cf, 18, 0.7, W.SteelDark, METAL, solid("Mast"))
	Kit.part(model, Vector3.new(4, 0.4, 0.4), cf * CFrame.new(0, 18, 0), W.SteelDark, METAL, decor("Bar"))
	for _, x in { -1.4, 1.4 } do
		local lamp = Kit.part(
			model,
			Vector3.new(1.2, 1, 0.5),
			cf * CFrame.new(x, 17.4, -0.4) * CFrame.Angles(math.rad(-30), 0, 0),
			W.Charcoal,
			METAL,
			decor("Lamp")
		)
		local lens = Kit.part(
			model,
			Vector3.new(1, 0.8, 0.1),
			lamp.CFrame * CFrame.new(0, 0, -0.28),
			Props.LampColor,
			Enum.Material.Neon,
			decor("Lens")
		)
		if light and x > 0 then
			local spot = Instance.new("SpotLight")
			spot.Name = "Flood"
			spot.Color = Props.LampColor
			spot.Brightness = 1.2
			spot.Range = 40
			spot.Angle = 70
			spot.Face = Enum.NormalId.Front
			spot.Shadows = false
			spot.Parent = lens
		end
	end
	return model
end

function Props.roadSign(parent: Instance, cf: CFrame, title: string, subtitle: string?, style: string?): Model
	local model = Kit.model(parent, "RoadSign")
	Kit.post(model, cf, 7, 0.3, W.Steel, METAL, solid("Post"))
	local colors = {
		halt = { bg = W.MutedRed, fg = W.OffWhite },
		info = { bg = W.SignGreen, fg = W.OffWhite },
		warn = { bg = W.HazardYellow, fg = W.Charcoal },
		white = { bg = W.OffWhite, fg = W.Charcoal },
	}
	local c = colors[style or "info"] or colors.info
	Kit.sign(model, cf * CFrame.new(0, 6.2, -0.2), Vector2.new(3.6, 2.2), title, {
		Background = c.bg,
		TextColor = c.fg,
		Subtitle = subtitle,
		Depth = 0.12,
		PixelsPerStud = 32,
		MaxDistance = 120,
	})
	return model
end

function Props.noticeBoard(parent: Instance, cf: CFrame, title: string, lines: { string }): Model
	local model = Kit.model(parent, "NoticeBoard")
	for _, x in { -2.4, 2.4 } do
		Kit.post(model, cf * CFrame.new(x, 0, 0), 7, 0.4, W.BrownDark, WOOD, solid("Post"))
	end
	local board = Kit.part(model, Vector3.new(5.4, 3.6, 0.3), cf * CFrame.new(0, 4.6, 0), W.Cork, WOOD, solid("Board"))
	Kit.part(model, Vector3.new(6, 0.3, 1), cf * CFrame.new(0, 6.65, 0.1), W.BrownDark, WOOD, decor("Roof"))
	local gui = Kit.surface(board, Enum.NormalId.Front, 40, 0.6, 60)
	Kit.frame(gui, UDim2.fromScale(0.05, 0.05), UDim2.fromScale(0.9, 0.9), W.Paper)
	Kit.text(gui, {
		Name = "Title",
		Text = title,
		Color = W.Charcoal,
		Font = Theme.font("Header", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(0.08, 0.07),
		Size = UDim2.fromScale(0.84, 0.18),
	})
	for i, line in lines do
		Kit.text(gui, {
			Name = "Line" .. i,
			Text = line,
			Color = W.Charcoal,
			Font = Theme.font("Document"),
			Position = UDim2.fromScale(0.08, 0.28 + (i - 1) * 0.13),
			Size = UDim2.fromScale(0.84, 0.11),
			XAlign = Enum.TextXAlignment.Left,
		})
	end
	return model
end

function Props.phoneBox(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "PhoneBox")
	local yellow = Color3.fromRGB(196, 168, 82) -- faded Bundespost yellow
	Kit.part(model, Vector3.new(3.4, 0.4, 3.4), cf * CFrame.new(0, 0.2, 0), W.ConcreteDark, CONCRETE, solid("Base"))
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.5, 1.5 } do
			Kit.part(model, Vector3.new(0.35, 7.4, 0.35), cf * CFrame.new(x, 4.1, z), yellow, METAL, solid("Frame"))
		end
	end
	Kit.part(model, Vector3.new(3.4, 0.6, 3.4), cf * CFrame.new(0, 8, 0), yellow, METAL, solid("Roof"))
	Kit.part(
		model,
		Vector3.new(3.2, 6.4, 0.15),
		cf * CFrame.new(0, 4, 1.5),
		W.Glass,
		Enum.Material.Glass,
		solid("Back")
	)
	Kit.part(model, Vector3.new(0.9, 1.2, 0.5), cf * CFrame.new(0, 5, 1.2), W.Charcoal, PLASTIC, decor("Phone"))
	Kit.sign(model, cf * CFrame.new(0, 8.8, -1.72), Vector2.new(2.8, 0.7), "TELEFON", {
		Background = W.Charcoal,
		TextColor = yellow,
		Depth = 0.1,
		PixelsPerStud = 40,
		MaxDistance = 80,
	})
	return model
end

-- Canvas camouflage net draped over poles (flat, slightly tilted panels).
function Props.camoNet(parent: Instance, cf: CFrame, size: Vector2, height: number): Model
	local model = Kit.model(parent, "CamoNet")
	for _, x in { -size.X / 2 + 0.5, size.X / 2 - 0.5 } do
		for _, z in { -size.Y / 2 + 0.5, size.Y / 2 - 0.5 } do
			Kit.post(model, cf * CFrame.new(x, 0, z), height, 0.35, W.BrownDark, WOOD, solid("Pole"))
		end
	end
	local tones = { W.Olive, W.OliveDark, Color3.fromRGB(92, 84, 60) }
	local nx, nz = 3, 2
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local px = -size.X / 2 + (i + 0.5) * size.X / nx
			local pz = -size.Y / 2 + (j + 0.5) * size.Y / nz
			Kit.part(
				model,
				Vector3.new(size.X / nx + 0.6, 0.15, size.Y / nz + 0.6),
				cf
					* CFrame.new(px, height + 0.1 - (i + j) % 2 * 0.3, pz)
					* CFrame.Angles(math.rad((j - 0.5) * 8), 0, math.rad((i - 1) * 5)),
				tones[(i + j) % #tones + 1],
				FABRIC,
				{ Name = "Net", Collide = false, Query = false, Shadow = true }
			)
		end
	end
	return model
end

function Props.fuelTank(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "FuelTank")
	for _, x in { -3, 3 } do
		Kit.part(model, Vector3.new(0.8, 2, 3.4), cf * CFrame.new(x, 1, 0), W.ConcreteDark, CONCRETE, solid("Cradle"))
	end
	Kit.cylinder(model, 10, 4.4, cf * CFrame.new(0, 3.9, 0), W.OliveDark, METAL, solid("Tank"))
	Kit.sign(model, cf * CFrame.new(0, 3.9, -2.25), Vector2.new(3.2, 1.2), "DIESEL", {
		Background = W.OliveDark,
		TextColor = W.OffWhite,
		Subtitle = "FLAMMABLE · FEUERGEFÄHRLICH",
		Depth = 0.1,
		PixelsPerStud = 36,
		MaxDistance = 90,
	})
	return model
end

-- GP medium tent (walls + ridge roof), opening to the front.
function Props.tent(parent: Instance, cf: CFrame, width: number?, depth: number?): Model
	local model = Kit.model(parent, "Tent")
	local w, d = width or 12, depth or 10
	local canvas = Color3.fromRGB(104, 104, 76)
	local wallH = 5
	for _, x in { -w / 2, w / 2 } do
		Kit.part(model, Vector3.new(0.2, wallH, d), cf * CFrame.new(x, wallH / 2, 0), canvas, FABRIC, solid("TentWall"))
	end
	Kit.part(model, Vector3.new(w, wallH, 0.2), cf * CFrame.new(0, wallH / 2, d / 2), canvas, FABRIC, solid("TentWall"))
	local rise = 3.2
	for _, s in { -1, 1 } do
		local slope = math.sqrt((w / 2) ^ 2 + rise ^ 2)
		local angle = math.atan2(rise, w / 2)
		Kit.part(
			model,
			Vector3.new(slope + 0.4, 0.2, d + 0.6),
			cf * CFrame.new(s * w / 4, wallH + rise / 2, 0) * CFrame.Angles(0, 0, s * -angle),
			canvas,
			FABRIC,
			{ Name = "TentRoof", Shadow = true }
		)
	end
	Kit.post(model, cf * CFrame.new(0, 0, 0), wallH + rise, 0.3, W.BrownDark, WOOD, decor("TentPole"))
	return model
end

-- Field kitchen trailer with a stove pipe (smoke anchor for Phase 5).
function Props.fieldKitchen(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "FieldKitchen")
	Kit.part(model, Vector3.new(6, 3.6, 3.6), cf * CFrame.new(0, 3, 0), W.OliveDark, METAL, solid("Body"))
	Kit.part(model, Vector3.new(6.2, 0.3, 3.8), cf * CFrame.new(0, 4.95, 0), W.SteelDark, METAL, decor("Lid"))
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1.9, 1.9 } do
			Kit.cylinder(
				model,
				0.5,
				2,
				cf * CFrame.new(x, 1, z) * CFrame.Angles(0, math.pi / 2, 0),
				W.Rubber,
				PLASTIC,
				decor("Wheel")
			)
		end
	end
	Kit.part(model, Vector3.new(0.4, 0.4, 3), cf * CFrame.new(0, 1.2, -3.2), W.SteelDark, METAL, decor("Drawbar"))
	Kit.post(model, cf * CFrame.new(2, 5.1, 0.8), 3.2, 0.5, W.Charcoal, METAL, decor("StovePipe"))
	return model
end

-- Interior furniture ---------------------------------------------------------

function Props.desk(parent: Instance, cf: CFrame, width: number?): Model
	local model = Kit.model(parent, "Desk")
	local w = width or 5
	Kit.part(model, Vector3.new(w, 0.25, 2.4), cf * CFrame.new(0, 2.8, 0), W.BrownDark, WOOD, solid("Top"))
	Kit.part(model, Vector3.new(1.6, 2.7, 2.2), cf * CFrame.new(w / 2 - 0.9, 1.35, 0), W.Brown, WOOD, solid("Drawers"))
	Kit.part(model, Vector3.new(0.2, 2.7, 2.2), cf * CFrame.new(-w / 2 + 0.2, 1.35, 0), W.Brown, WOOD, decor("Side"))
	return model
end

function Props.chair(parent: Instance, cf: CFrame, color: Color3?): Model
	local model = Kit.model(parent, "Chair")
	local c = color or W.SteelDark
	Kit.part(model, Vector3.new(1.8, 0.25, 1.8), cf * CFrame.new(0, 1.6, 0), c, PLASTIC, decor("Seat"))
	Kit.part(model, Vector3.new(1.8, 1.6, 0.2), cf * CFrame.new(0, 2.5, 0.85), c, PLASTIC, decor("Back"))
	Kit.post(model, cf, 1.5, 0.25, W.Charcoal, METAL, decor("Stem"))
	Kit.part(model, Vector3.new(1.6, 0.15, 1.6), cf * CFrame.new(0, 0.08, 0), W.Charcoal, METAL, decor("Base"))
	return model
end

function Props.cabinet(parent: Instance, cf: CFrame, color: Color3?): Model
	local model = Kit.model(parent, "Cabinet")
	local c = color or Color3.fromRGB(110, 114, 100)
	Kit.part(model, Vector3.new(2, 4.6, 2), cf * CFrame.new(0, 2.3, 0), c, METAL, solid("Body"))
	for i = 0, 3 do
		Kit.part(
			model,
			Vector3.new(0.6, 0.12, 0.1),
			cf * CFrame.new(0, 0.8 + i * 1.1, -1.03),
			W.Steel,
			METAL,
			decor("Handle")
		)
	end
	return model
end

function Props.bookshelf(parent: Instance, cf: CFrame, width: number?): Model
	local model = Kit.model(parent, "Bookshelf")
	local w = width or 5
	Kit.part(model, Vector3.new(w, 7, 1.4), cf * CFrame.new(0, 3.5, 0.3), W.BrownDark, WOOD, solid("Case"))
	local spines = { W.MutedRed, W.MutedBlue, W.OliveDark, W.Beige, W.BrownDark }
	for shelf = 0, 3 do
		local y = 1 + shelf * 1.6
		local x = -w / 2 + 0.4
		local i = shelf
		while x < w / 2 - 0.5 do
			local bw = 0.3 + (i % 3) * 0.1
			Kit.part(
				model,
				Vector3.new(bw, 1.1, 1),
				cf * CFrame.new(x + bw / 2, y + 0.55, -0.45),
				spines[i % #spines + 1],
				PLASTIC,
				decor("Books")
			)
			x += bw + 0.05
			i += 1
			if i - shelf > 6 then
				break
			end
		end
	end
	return model
end

function Props.waterCooler(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "WaterCooler")
	Kit.part(model, Vector3.new(1.4, 3.2, 1.4), cf * CFrame.new(0, 1.6, 0), W.OffWhite, PLASTIC, solid("Stand"))
	Kit.post(
		model,
		cf * CFrame.new(0, 3.2, 0),
		1.8,
		1.2,
		Color3.fromRGB(150, 170, 176),
		Enum.Material.Glass,
		{ Name = "Bottle", Transparency = 0.3, Decor = true }
	)
	return model
end

-- Round wall clock on a wall facing -Z of `cf` (cf = wall surface point).
function Props.wallClock(parent: Instance, cf: CFrame, label: string?, hours: number?): Model
	local model = Kit.model(parent, "WallClock")
	Kit.cylinder(model, 0.2, 2.2, cf * CFrame.Angles(0, math.pi / 2, 0), W.OffWhite, PLASTIC, decor("Face"))
	local h = (hours or 15) % 12
	local hourAngle = h / 12 * math.pi * 2
	local minuteAngle = 0.6 * math.pi * 2
	Kit.part(
		model,
		Vector3.new(0.12, 0.6, 0.05),
		cf * CFrame.new(0, 0, -0.13) * CFrame.Angles(0, 0, -hourAngle) * CFrame.new(0, 0.3, 0),
		W.Charcoal,
		PLASTIC,
		decor("HourHand")
	)
	Kit.part(
		model,
		Vector3.new(0.08, 0.9, 0.05),
		cf * CFrame.new(0, 0, -0.14) * CFrame.Angles(0, 0, -minuteAngle) * CFrame.new(0, 0.45, 0),
		W.Charcoal,
		PLASTIC,
		decor("MinuteHand")
	)
	if label then
		Kit.sign(model, cf * CFrame.new(0, -1.55, -0.02), Vector2.new(2.4, 0.5), label, {
			Background = W.Charcoal,
			TextColor = W.OffWhite,
			Depth = 0.06,
			PixelsPerStud = 40,
			MaxDistance = 60,
		})
	end
	return model
end

-- Fluorescent ceiling fitting hanging below `cf` (cf = ceiling point).
function Props.ceilingLight(parent: Instance, cf: CFrame, light: boolean?, length: number?): Model
	local model = Kit.model(parent, "CeilingLight")
	local l = length or 5
	Kit.part(model, Vector3.new(l, 0.3, 1.2), cf * CFrame.new(0, -0.15, 0), W.Steel, METAL, decor("Housing"))
	local tube = Kit.part(
		model,
		Vector3.new(l - 0.4, 0.12, 0.8),
		cf * CFrame.new(0, -0.35, 0),
		Props.TubeColor,
		Enum.Material.Neon,
		decor("Tube")
	)
	if light then
		local surface = Instance.new("SurfaceLight")
		surface.Name = "TubeLight"
		surface.Face = Enum.NormalId.Bottom
		surface.Color = Props.TubeColor
		surface.Brightness = 0.9
		surface.Range = 16
		surface.Angle = 120
		surface.Shadows = false
		surface.Parent = tube
	end
	return model
end

function Props.toolBench(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "ToolBench")
	Kit.part(model, Vector3.new(7, 0.4, 2.6), cf * CFrame.new(0, 3, 0), W.Wood, WOOD, solid("Top"))
	for _, x in { -3.2, 3.2 } do
		Kit.part(model, Vector3.new(0.4, 2.8, 2.4), cf * CFrame.new(x, 1.4, 0), W.SteelDark, METAL, solid("Leg"))
	end
	Kit.part(model, Vector3.new(7, 4, 0.2), cf * CFrame.new(0, 5.2, 1.2), W.SteelDark, METAL, decor("Pegboard"))
	local tools = { { -2.4, 5.8, 0.3, 1.4 }, { -1.2, 5.4, 0.8, 0.3 }, { 0.4, 6, 0.2, 1.8 }, { 2, 5.6, 1.2, 0.4 } }
	for _, t in tools do
		Kit.part(
			model,
			Vector3.new(t[3], t[4], 0.12),
			cf * CFrame.new(t[1], t[2], 1.05),
			W.Charcoal,
			METAL,
			decor("Tool")
		)
	end
	Kit.part(model, Vector3.new(1.2, 0.9, 0.9), cf * CFrame.new(2.4, 3.65, -0.3), W.MutedRed, METAL, decor("Toolbox"))
	return model
end

function Props.forklift(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "Forklift")
	local yellow = Color3.fromRGB(176, 146, 64)
	Kit.part(model, Vector3.new(3.6, 2.4, 5), cf * CFrame.new(0, 2, 0.6), yellow, METAL, solid("Body"))
	Kit.part(model, Vector3.new(3.4, 1.4, 1.6), cf * CFrame.new(0, 2.2, 3.2), W.Charcoal, METAL, solid("Counterweight"))
	Kit.part(model, Vector3.new(1.4, 1.2, 1.4), cf * CFrame.new(0, 3.6, 1), W.Charcoal, FABRIC, decor("Seat"))
	for _, x in { -1.6, 1.6 } do
		Kit.part(model, Vector3.new(0.2, 4.6, 0.2), cf * CFrame.new(x, 5.4, 2.8), W.Charcoal, METAL, decor("RoofPost"))
		Kit.part(model, Vector3.new(0.3, 6, 0.3), cf * CFrame.new(x * 0.6, 3.4, -2), W.SteelDark, METAL, decor("Mast"))
		Kit.part(
			model,
			Vector3.new(0.4, 0.2, 3),
			cf * CFrame.new(x * 0.5, 0.4, -3.4),
			W.SteelDark,
			METAL,
			decor("Fork")
		)
	end
	Kit.part(model, Vector3.new(3.6, 0.2, 3.4), cf * CFrame.new(0, 7.7, 1.5), W.Charcoal, METAL, decor("Roof"))
	for _, x in { -1.8, 1.8 } do
		for _, z in { -1, 2.6 } do
			Kit.cylinder(
				model,
				0.8,
				1.6,
				cf * CFrame.new(x, 0.8, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
				W.Rubber,
				PLASTIC,
				decor("Wheel")
			)
		end
	end
	return model
end

-- String of bulbs between two points (Decor), with `lights` real lights
-- spread along it (keep this small).
function Props.stringLights(parent: Instance, a: Vector3, b: Vector3, bulbs: number, lights: number?)
	Props.wire(parent, a, b, 0.9, 5)
	local placed = 0
	local every = if lights and lights > 0 then math.max(1, math.floor(bulbs / lights)) else math.huge
	for i = 1, bulbs do
		local t = i / (bulbs + 1)
		local point = a:Lerp(b, t) - Vector3.new(0, 0.9 * 4 * t * (1 - t) + 0.35, 0)
		local bulb = Kit.ball(parent, 0.45, CFrame.new(point), Props.LampColor, Enum.Material.Neon, decor("Bulb"))
		if lights and placed < lights and i % every == 0 then
			placed += 1
			local point2 = Instance.new("PointLight")
			point2.Name = "BulbLight"
			point2.Color = Props.LampColor
			point2.Brightness = 0.6
			point2.Range = 14
			point2.Shadows = false
			point2.Parent = bulb
		end
	end
end

function Props.coffeeUrn(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "CoffeeUrn")
	Kit.post(model, cf, 1.8, 1.1, W.Steel, METAL, decor("Urn"))
	Kit.post(model, cf * CFrame.new(0, 1.8, 0), 0.25, 0.7, W.Charcoal, PLASTIC, decor("Lid"))
	for i = 0, 2 do
		Kit.post(model, cf * CFrame.new(1.2 + i * 0.5, 0, -0.2), 0.45, 0.35, W.OffWhite, PLASTIC, decor("Mug"))
	end
	return model
end

function Props.radio(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "Radio")
	Kit.part(model, Vector3.new(1.8, 1.1, 0.7), cf * CFrame.new(0, 0.55, 0), W.BrownDark, WOOD, decor("Case"))
	Kit.part(model, Vector3.new(0.9, 0.7, 0.05), cf * CFrame.new(-0.3, 0.6, -0.36), W.Charcoal, FABRIC, decor("Grille"))
	Kit.part(model, Vector3.new(0.08, 1.6, 0.08), cf * CFrame.new(0.7, 1.8, 0.2), W.Steel, METAL, decor("Aerial"))
	return model
end

function Props.bicycle(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "Bicycle")
	for _, z in { -1.3, 1.3 } do
		Kit.cylinder(
			model,
			0.15,
			2.2,
			cf * CFrame.new(0, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
			W.Rubber,
			PLASTIC,
			decor("Wheel")
		)
	end
	Kit.part(
		model,
		Vector3.new(0.15, 0.15, 2.8),
		cf * CFrame.new(0, 1.9, 0) * CFrame.Angles(math.rad(8), 0, 0),
		W.MutedBlue,
		METAL,
		decor("Frame")
	)
	Kit.part(model, Vector3.new(0.15, 1.4, 0.15), cf * CFrame.new(0, 1.6, 0.6), W.MutedBlue, METAL, decor("SeatTube"))
	Kit.part(model, Vector3.new(0.5, 0.15, 0.8), cf * CFrame.new(0, 2.4, 0.7), W.Charcoal, FABRIC, decor("Saddle"))
	Kit.part(model, Vector3.new(1.4, 0.12, 0.12), cf * CFrame.new(0, 2.6, -1.1), W.Steel, METAL, decor("Handlebar"))
	return model
end

-- Generic hot-drinks vending machine (no brands).
function Props.vendingMachine(parent: Instance, cf: CFrame): Model
	local model = Kit.model(parent, "VendingMachine")
	local body = Kit.part(model, Vector3.new(3, 6.4, 2.4), cf * CFrame.new(0, 3.2, 0), W.MutedRed, METAL, solid("Body"))
	Kit.part(
		model,
		Vector3.new(2.2, 2.6, 0.1),
		cf * CFrame.new(-0.2, 4.2, -1.22),
		Color3.fromRGB(60, 58, 50),
		Enum.Material.Glass,
		decor("Window")
	)
	local gui = Kit.surface(body, Enum.NormalId.Front, 30, 0.4, 50)
	Kit.text(gui, {
		Name = "Label",
		Text = "KAFFEE · TEE",
		Color = W.OffWhite,
		Font = Theme.font("Header", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(0.05, 0.02),
		Size = UDim2.fromScale(0.9, 0.08),
	})
	Kit.text(gui, {
		Name = "Price",
		Text = "0,50 DM",
		Color = W.HazardYellow,
		Font = Theme.font("Mono", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(0.05, 0.62),
		Size = UDim2.fromScale(0.9, 0.06),
	})
	return model
end

return Props
