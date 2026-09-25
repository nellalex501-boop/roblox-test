--!strict
-- Replaceable set dressing for the Event Area, keyed by Event.Dressing.
-- Each function fills the (already cleared) Dressing model. Add a new key
-- here for a new seasonal theme; the permanent compound is untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(script.Parent.Effects)
local EventAreaZone = require(script.Parent.Zones.EventArea)
local Kit = require(script.Parent.Kit)
local Nature = require(script.Parent.Nature)
local Props = require(script.Parent.Props)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World

local EventDressings: { [string]: (Model, CFrame) -> () } = {}

local function crate(parent: Instance, cf: CFrame, size: Vector3, color: Color3, snowy: boolean)
	Kit.part(parent, size, cf * CFrame.new(0, size.Y / 2, 0), color, Enum.Material.WoodPlanks, { Name = "Crate" })
	if snowy then
		-- the cap rests on the lid, a little smaller than it
		Kit.part(
			parent,
			Vector3.new(size.X * 0.92, 0.25, size.Z * 0.92),
			cf * CFrame.new(0, size.Y + 0.125, 0),
			W.Snow,
			Enum.Material.Snow,
			{
				Name = "SnowCap",
				Decor = true,
			}
		)
	end
end

-- Winter yard constants (zone-local; see Zones/EventArea).
local SNOW_TOP = 0.32 -- snow cover 0.2 .. 0.32 (the yard is dirt up to 0.2)
local SLUSH = Color3.fromRGB(122, 118, 110)

-- A fan snow gun on its wheeled carriage at `cf` (ground centre), barrel
-- aimed along the frame's -Z and tilted up; blows a plume of snow. A hose
-- runs from the carriage to a hydrant at `hydrant` (world position).
local function snowGun(parent: Instance, cf: CFrame, hydrant: Vector3)
	local model = Kit.model(parent, "SnowGun")
	local body = W.HazardYellow
	local dark = W.SteelDark
	-- carriage: axle, two wheels, frame rail, tow bar and front stand
	Kit.cylinder(
		model,
		2.6,
		0.3,
		cf * CFrame.new(0, 1.1, 0.4),
		dark,
		Enum.Material.Metal,
		{ Name = "Axle", Decor = true }
	)
	for _, side in { -1, 1 } do
		Kit.cylinder(
			model,
			0.5,
			1.8,
			cf * CFrame.new(side * 1.45, 1.1, 0.4),
			W.Rubber,
			Enum.Material.SmoothPlastic,
			{ Name = "Wheel" }
		)
	end
	Kit.part(
		model,
		Vector3.new(1, 0.4, 3.4),
		cf * CFrame.new(0, 1.5, 0),
		dark,
		Enum.Material.Metal,
		{ Name = "Chassis" }
	)
	Kit.part(
		model,
		Vector3.new(0.3, 0.25, 2.4),
		cf * CFrame.new(0, 1.2, -2.6) * CFrame.Angles(math.rad(-14), 0, 0),
		dark,
		Enum.Material.Metal,
		{ Name = "TowBar", Decor = true }
	)
	Kit.post(
		model,
		cf * CFrame.new(0, 0.2, -1.5),
		1.2,
		0.3,
		dark,
		Enum.Material.Metal,
		{ Name = "Stand", Decor = true }
	)
	-- turntable post and yoke
	Kit.post(model, cf * CFrame.new(0, 1.7, 0), 1.3, 0.8, dark, Enum.Material.Metal, { Name = "Turntable" })
	for _, side in { -1, 1 } do
		Kit.part(
			model,
			Vector3.new(0.2, 1.8, 0.9),
			cf * CFrame.new(side * 1.5, 3.4, 0),
			dark,
			Enum.Material.Metal,
			{ Name = "Yoke", Decor = true }
		)
	end
	-- barrel (fan shroud) tilted up 18 degrees; axis along the aim
	local aim = cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(18), 0, 0)
	local axis = CFrame.Angles(0, math.pi / 2, 0) -- cylinder X axis onto the aim (-Z)
	Kit.cylinder(model, 2.8, 2.7, aim * axis, body, Enum.Material.Metal, { Name = "Barrel" })
	-- nozzle ring proud of the mouth, fan grille and motor at the back
	Kit.cylinder(
		model,
		0.3,
		2.95,
		aim * CFrame.new(0, 0, -1.4) * axis,
		dark,
		Enum.Material.Metal,
		{ Name = "NozzleRing", Decor = true }
	)
	Kit.cylinder(
		model,
		0.12,
		2.3,
		aim * CFrame.new(0, 0, 1.44) * axis,
		W.Charcoal,
		Enum.Material.DiamondPlate,
		{ Name = "Grille", Decor = true }
	)
	Kit.cylinder(
		model,
		1,
		1.3,
		aim * CFrame.new(0, 0, 2) * axis,
		dark,
		Enum.Material.Metal,
		{ Name = "Motor", Decor = true }
	)
	for i = 0, 5 do
		local a = i * math.pi / 3
		Kit.cylinder(
			model,
			0.35,
			0.14,
			aim * CFrame.new(math.cos(a) * 1.3, math.sin(a) * 1.3, -1.7) * axis,
			W.Steel,
			Enum.Material.Metal,
			{ Name = "Nozzle", Decor = true }
		)
	end
	-- the plume leaves the mouth (the emitter's Front face points along the aim)
	local mouth = Kit.part(
		model,
		Vector3.new(1.6, 1.6, 0.2),
		aim * CFrame.new(0, 0, -1.8),
		W.Snow,
		nil,
		{ Name = "Mouth", Transparency = 1, Decor = true }
	)
	Effects.snowPlume(mouth, 8)
	Kit.anchor(mouth, "Sound", "SnowGun")
	-- hose along the snow to the hydrant, and the hydrant itself
	local hoseY = SNOW_TOP + 0.15
	local rear = (cf * CFrame.new(0, 0, 1.9)).Position
	local start = Vector3.new(rear.X, hoseY, rear.Z)
	local stop = Vector3.new(hydrant.X, hoseY, hydrant.Z)
	local mid = start:Lerp(stop, 0.5) + Vector3.new(0.8, 0, -0.6)
	for _, pair in { { start, mid }, { mid, stop } } do
		local a, b = pair[1], pair[2]
		Kit.cylinder(
			model,
			(b - a).Magnitude + 0.2,
			0.3,
			CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
			W.Charcoal,
			Enum.Material.SmoothPlastic,
			{ Name = "Hose", Decor = true }
		)
	end
	Kit.post(
		model,
		CFrame.new(hydrant.X, 0.2, hydrant.Z),
		2.2,
		0.6,
		W.MutedRed,
		Enum.Material.Metal,
		{ Name = "Hydrant" }
	)
	Kit.cylinder(
		model,
		0.12,
		0.9,
		CFrame.new(hydrant.X, 2.5, hydrant.Z) * CFrame.Angles(0, 0, math.pi / 2),
		dark,
		Enum.Material.Metal,
		{ Name = "Valve", Decor = true }
	)
	return model
end

-- Pulk (man-hauled supply sled) with a lashed load.
local function pulk(parent: Instance, cf: CFrame)
	local model = Kit.model(parent, "Pulk")
	local y = SNOW_TOP
	Kit.part(model, Vector3.new(1.5, 0.35, 3.4), cf * CFrame.new(0, y + 0.2, 0), W.OliveDark, Enum.Material.Fabric, {
		Name = "Hull",
	})
	Kit.wedge(
		model,
		Vector3.new(1.5, 0.35, 0.8),
		cf * CFrame.new(0, y + 0.2, -2.1) * CFrame.Angles(0, math.pi, 0),
		W.OliveDark,
		Enum.Material.Fabric,
		{ Name = "Nose", Decor = true }
	)
	Kit.part(model, Vector3.new(1.2, 0.7, 2.4), cf * CFrame.new(0, y + 0.72, 0.2), W.Olive, Enum.Material.Fabric, {
		Name = "Load",
		Decor = true,
	})
	for _, z in { -0.5, 0.9 } do
		Kit.part(
			model,
			Vector3.new(1.26, 0.08, 0.14),
			cf * CFrame.new(0, y + 1.1, z),
			W.Charcoal,
			Enum.Material.Fabric,
			{ Name = "Strap", Decor = true }
		)
	end
	-- the two hauling poles lie crossed on the snow in front
	for _, side in { -1, 1 } do
		Kit.cylinder(
			model,
			3,
			0.12,
			cf * CFrame.new(side * 0.5, y + 0.1, -3.8) * CFrame.Angles(0, math.pi / 2 + side * 0.12, 0),
			W.Wood,
			Enum.Material.Wood,
			{ Name = "Shaft", Decor = true }
		)
	end
	return model
end

EventDressings.Winter = function(dressing: Model, frame: CFrame)
	local rng = Random.new(1941)
	local T = EventAreaZone.Tent
	local edge = 38 - EventAreaZone.FenceInset - 0.3 -- snow stops 0.3 short of the fence
	local back = -56 + EventAreaZone.FenceInset + 0.3
	local front = -EventAreaZone.FenceInset - 0.3
	-- the yard is a winter warfare training area kept white by snow guns:
	-- one snow cover over the whole yard, cut around the cleared walkway and
	-- the tent (the pieces butt, so no two share a top face)
	local walk = 3.1
	local tentSide = T.X1 + 0.3
	local tentFront = T.Z1 + 1.6 -- the roof's front overhang
	local snowFolder = Kit.folder(dressing, "Snow")
	for _, rect in
		{
			{ -edge, -tentSide, back, front },
			{ tentSide, edge, back, front },
			{ -tentSide, -walk, tentFront, front },
			{ walk, tentSide, tentFront, front },
			{ -tentSide, tentSide, back, T.Z0 - 0.6 },
		}
	do
		local cover = Kit.box(
			snowFolder,
			frame,
			Vector3.new(rect[1], 0.2, rect[3]),
			Vector3.new(rect[2], SNOW_TOP, rect[4]),
			W.Snow,
			Enum.Material.Snow,
			{ Name = "SnowCover", Collide = false, Query = false, Shadow = false }
		)
		cover.CastShadow = false
	end
	-- soft drifts piled against the fence and the tent (sunken spheres; the
	-- mound's rim is kept inside the fence)
	local function drift(x: number, z: number, radius: number, height: number)
		local rim = math.sqrt(radius * radius - (radius - height) ^ 2)
		local cx = math.clamp(x, -edge + rim, edge - rim)
		local cz = math.clamp(z, back + rim, front - rim)
		Nature.drift(snowFolder, (frame * CFrame.new(cx, SNOW_TOP, cz)).Position, radius, height)
	end
	for _, d in
		{
			-- (none straight behind the tent: the gap to the fence is too
			-- narrow for a mound that stays out of the tent)
			{ -24, -56, 10, 1.6 },
			{ 28, -56, 10, 1.5 },
			{ -22, -56, 7, 1.0 },
			{ 21, -56, 7, 1.1 },
			{ -38, -40, 9, 1.4 },
			{ -38, -22, 11, 1.2 },
			{ 38, -44, 10, 1.5 },
			{ 38, -30, 7, 0.9 },
			{ 38, -18, 9, 1.4 },
			{ -38, 0, 8, 1.2 },
			{ -19, -44, 6, 0.9 },
			{ 19, -40, 6, 0.9 },
		}
	do
		drift(d[1], d[2], d[3], d[4])
	end
	-- ploughed ridges along both sides of the cleared walkway: broad, low
	-- and uneven (wide cylinders sunk to show 0.2-0.3, staggered)
	for _, side in { -1, 1 } do
		for i, seg in { { -33, -21, 0.3 }, { -22, -11, 0.22 }, { -12, -1.6, 0.26 } } do
			local length = seg[2] - seg[1]
			local r = 2.4 + i * 0.15
			Kit.cylinder(
				snowFolder,
				length,
				r * 2,
				frame
					* CFrame.new(side * (walk + 1.2), SNOW_TOP + seg[3] - r, (seg[1] + seg[2]) / 2)
					* CFrame.Angles(0, math.pi / 2, 0),
				W.Snow,
				Enum.Material.Snow,
				{ Name = "Windrow", Decor = true }
			)
		end
	end
	-- snow on both slopes of the tent roof, 0.06 above the fabric, from
	-- just below the ridge cap to near the eave
	local depth = (T.Z1 + 1.5) - (T.Z0 - 0.5)
	local half = depth / 2
	local midZ = ((T.Z1 + 1.5) + (T.Z0 - 0.5)) / 2
	local angle = math.atan2(T.Rise, half)
	local slopeLen = math.sqrt(half * half + T.Rise * T.Rise)
	for _, side in { -1, 1 } do
		local normal = Vector3.new(0, math.cos(angle), side * math.sin(angle))
		local down = Vector3.new(0, -math.sin(angle), side * math.cos(angle))
		local ridge = Vector3.new(0, T.EaveY + T.Rise, midZ)
		local from, to = 1.1, slopeLen + T.Overhang - 0.3
		local center = ridge + down * ((from + to) / 2) + normal * (0.9 + 0.06 + 0.15)
		Kit.part(
			snowFolder,
			Vector3.new((T.X1 - T.X0) + 1 + T.Overhang * 2 - 0.6, 0.3, to - from),
			frame * CFrame.new(center) * CFrame.Angles(side * angle, 0, 0),
			W.Snow,
			Enum.Material.Snow,
			{ Name = "RoofSnow", Decor = true }
		)
	end
	-- snow guns in two corners, blowing across the yard; hose to hydrants
	snowGun(
		dressing,
		frame * CFrame.new(30, 0.2, -8) * CFrame.Angles(0, math.rad(80), 0),
		(frame * CFrame.new(35.8, 0, -3)).Position
	)
	snowGun(
		dressing,
		frame * CFrame.new(-32, 0.2, -47) * CFrame.Angles(0, math.rad(-128), 0),
		(frame * CFrame.new(-35.8, 0, -53.6)).Position
	)
	local warning = Kit.sign(
		dressing,
		-- wired to the fence, in front of its posts
		Kit.facingOut(frame, Vector3.new(14, 3.6, -EventAreaZone.FenceInset + 0.32)),
		Vector2.new(9, 2.4),
		"WINTER WARFARE TRAINING AREA",
		{
			Background = Color3.fromRGB(214, 220, 224),
			TextColor = W.Charcoal,
			Subtitle = "SNOW GUNS IN OPERATION",
			Stripe = W.HazardYellow,
			PixelsPerStud = 36,
			Depth = 0.1,
		}
	)
	warning.Name = "YardSign"
	-- light snow falling over the yard, and the frost tint for cameras
	-- inside it (client ambient pass)
	local sky = Kit.part(
		dressing,
		Vector3.new(72, 1, 52),
		frame * CFrame.new(0, 26, -28),
		W.Snow,
		nil,
		{ Name = "SnowSky", Transparency = 1, Decor = true }
	)
	Effects.snowfall(sky, 10)
	local zone = Kit.part(
		dressing,
		Vector3.new(76, 32, 56),
		frame * CFrame.new(0, 16, -28),
		W.Snow,
		nil,
		{ Name = "FrostZone", Transparency = 1, Decor = true }
	)
	Kit.anchor(zone, "FrostZone")
	-- snowy pines in two clusters
	for _, pos in
		{
			{ -30, -28, 16 },
			{ -25.5, -34, 13 },
			{ 31, -38, 17 },
			{ 26.5, -45, 13.5 },
			{ 33.5, -47, 15 },
		}
	do
		Nature.pine(dressing, frame * CFrame.new(pos[1], SNOW_TOP - 0.1, pos[2]), pos[3], rng, true)
	end
	-- supply dump: two crates with a third across them, snow on the top one;
	-- skis and poles leaning on the stack, a pulk alongside
	local dump = frame * CFrame.new(-20, SNOW_TOP - 0.1, -14)
	crate(dressing, dump * CFrame.new(-1.6, 0, 0), Vector3.new(3, 2.2, 2.4), W.OliveDark, false)
	crate(dressing, dump * CFrame.new(1.6, 0, -0.1), Vector3.new(3, 2.2, 2.4), W.OliveDark, false)
	crate(dressing, dump * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0.08, 0), Vector3.new(2.6, 2, 2.2), W.Olive, true)
	for i, x in { -2.2, -1.6 } do
		Kit.part(
			dressing,
			Vector3.new(0.3, 5.6, 0.08),
			dump * CFrame.new(x, 2.7, 1.5) * CFrame.Angles(math.rad(-14), 0, math.rad(i * 3 - 4)),
			W.Wood,
			Enum.Material.Wood,
			{ Name = "Ski", Decor = true }
		)
	end
	for _, x in { 2.2, 2.6 } do
		Kit.cylinder(
			dressing,
			4.6,
			0.08,
			dump * CFrame.new(x, 2.2, 1.6) * CFrame.Angles(math.rad(-12), 0, math.pi / 2),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "SkiPole", Decor = true }
		)
	end
	pulk(dressing, frame * CFrame.new(-25, 0, -19) * CFrame.Angles(0, math.rad(20), 0))
	crate(
		dressing,
		frame * CFrame.new(20, SNOW_TOP - 0.1, -32) * CFrame.Angles(0, 0.2, 0),
		Vector3.new(3, 2.2, 2.4),
		W.OliveDark,
		true
	)
	-- whitewashed tent sign
	Kit.sign(dressing, Kit.facingOut(frame, Vector3.new(-9, 9.8, -34.8)), Vector2.new(8, 1.8), "WINTER WARFARE CELL", {
		Background = Color3.fromRGB(196, 206, 212),
		TextColor = W.Charcoal,
		PixelsPerStud = 40,
		Depth = 0.2,
		MaxDistance = 120,
	})
	-- warming point: a fire barrel on a trampled patch, log seats around it
	local fire = frame * CFrame.new(-9, 0.2, -28)
	Kit.cylinder(
		dressing,
		0.08,
		7.4,
		fire * CFrame.new(0, SNOW_TOP + 0.02 - 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		SLUSH,
		Enum.Material.Ground,
		{ Name = "Trampled", Decor = true }
	)
	Props.oilDrum(dressing, fire, W.SteelDark)
	for i = 0, 2 do
		local a = math.rad(40 + i * 120)
		Kit.cylinder(
			dressing,
			2.8,
			0.9,
			fire * CFrame.new(math.cos(a) * 3, 0.45 + 0.12, math.sin(a) * 3) * CFrame.Angles(0, a + math.pi / 2, 0),
			W.Brown,
			Enum.Material.Wood,
			{ Name = "LogSeat" }
		)
	end
	-- glowing coals just above the drum's rim
	local coals =
		Kit.post(dressing, fire * CFrame.new(0, 2.96, 0), 0.08, 1.6, Color3.fromRGB(150, 58, 24), Enum.Material.Neon, {
			Name = "Coals",
			Decor = true,
		})
	coals.CastShadow = false
	local flameBase = Kit.part(
		dressing,
		Vector3.new(1.4, 0.2, 1.4),
		fire * CFrame.new(0, 2.95, 0),
		W.Charcoal,
		nil,
		{ Name = "FlameBase", Transparency = 1, Decor = true }
	)
	Kit.anchor(flameBase, "Fire", "FireBarrel")
	Effects.fire(flameBase, 2.4)
	-- the display vehicle's tracks through the snow, gate to pad
	local from, to = Vector3.new(4.5, 0, -1.6), Vector3.new(12.5, 0, -15.6)
	local dir = (to - from).Unit
	local sideways = Vector3.new(-dir.Z, 0, dir.X)
	for _, s in { -2.6, 2.6 } do
		local a, b = from + sideways * s, to + sideways * s
		Kit.part(
			dressing,
			Vector3.new(1.2, 0.06, (b - a).Magnitude),
			frame
				* CFrame.lookAt(
					(a + b) / 2 + Vector3.new(0, SNOW_TOP + 0.03, 0),
					b + Vector3.new(0, SNOW_TOP + 0.03, 0)
				),
			SLUSH,
			Enum.Material.Ground,
			{ Name = "Track", Decor = true }
		)
	end
end

EventDressings.Standby = function(dressing: Model, frame: CFrame)
	local stack = frame * CFrame.new(10, 0.2, -24)
	crate(dressing, stack, Vector3.new(4, 2.6, 3), W.OliveDark, false)
	crate(dressing, stack * CFrame.new(0.3, 2.6, 0), Vector3.new(3.4, 2.2, 2.6), W.Olive, false)
	Kit.part(
		dressing,
		Vector3.new(5, 0.2, 4),
		stack * CFrame.new(0, 4.95, 0),
		W.OliveDark,
		Enum.Material.Fabric,
		{ Name = "Tarp" }
	)
	Kit.sign(
		dressing,
		Kit.facingOut(frame, Vector3.new(-9, 9.8, -34.8)),
		Vector2.new(8, 1.8),
		"NEXT OPERATION PENDING",
		{
			Background = W.SignGreen,
			PixelsPerStud = 40,
			Depth = 0.2,
			MaxDistance = 120,
		}
	)
end

return EventDressings
