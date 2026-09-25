--!strict
-- Garage showroom: one vehicle on a lit turntable in the middle of the hall.
-- The vehicle on the turntable is chosen by each player in the showroom
-- viewer (the client swaps its own copy in, see ShowroomController); the
-- server places a featured vehicle so the hall is never empty in Studio.
-- Around it: the showroom control console, a spotlight truss, the
-- regimental backdrop and working service bays (tarped vehicle, engine on
-- a hoist, tool carts, parts shelving, the old paint booth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Common = require(script.Parent.Common)
local Kit = require(World.Kit)
local Vehicles = require(World.Vehicles)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Units = require(ReplicatedStorage.Lobby.Config.Units)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Garage = {}

Garage.FloorY = 0.4
-- Turntable centre (garage frame) and size.
Garage.Turntable = { X = 0, Z = -34, Radius = 12.5, TopY = 1.1 }
Garage.Featured = "M1_ABRAMS"
Garage.ConsoleZ = -16

local CATEGORY_SHORT = {
	MBT = "MAIN BATTLE TANK",
	IFV = "INFANTRY FIGHTING VEHICLE",
	APC = "ARMORED CARRIER",
	RECON = "RECONNAISSANCE",
	AA = "AIR DEFENSE",
	SUPPLY = "LOGISTICS",
}

-- Places a unit on display with an inspect prompt and a placard (the Event
-- Area's limited unit). `inspect = false` leaves the prompt out.
function Garage.display(
	parent: Instance,
	unitId: string,
	frame: CFrame,
	paint: Vehicles.Paint?,
	withPlacard: boolean?,
	inspect: boolean?
): Model
	local unit = Units.List[unitId]
	assert(unit, "unknown unit " .. unitId)
	local model = Kit.model(parent, "Showcase_" .. unitId)
	local vehiclePaint = paint or Vehicles.DefaultPaint[unit.Faction] or Vehicles.DefaultPaint.NATO
	local vehicle = Vehicles.spawn(model, unitId, unit.Model, frame, vehiclePaint, Vector3.new(14, 11, 22))
	vehicle:SetAttribute("UnitId", unitId)
	if inspect ~= false then
		-- invisible anchor carrying the prompt so it works for asset overrides too
		local anchor = Kit.part(model, Vector3.new(1, 1, 1), frame * CFrame.new(0, 5, 0), W.Screen, nil, {
			Name = "InspectAnchor",
			Transparency = 1,
			Decor = true,
		})
		Interactions.attach(anchor, "UnitInspect", unitId, unit.Name)
	end
	if withPlacard ~= false then
		local placardCf = frame * CFrame.new(-8.5, 0, -11.5) * CFrame.Angles(0, math.pi, 0)
		local plate = Common.placard(
			model,
			placardCf,
			unit.Name,
			("%s · %s"):format(CATEGORY_SHORT[unit.Category] or unit.Category, Units.Factions[unit.Faction].Name),
			if unit.Faction == "PACT" then W.MutedRed else W.MutedBlue
		)
		plate:SetAttribute("UnitId", unitId)
	end
	return model
end

-- Turntable: steel base ring, a rotating deck (turned client-side), a
-- hazard band round the base and a painted safety circle on the floor.
local function turntable(parent: Instance, frame: CFrame): (Model, CFrame)
	local model = Kit.model(parent, "Turntable")
	local t = Garage.Turntable
	local y = Garage.FloorY
	local center = frame * CFrame.new(t.X, y, t.Z)
	Kit.post(model, center, 0.8, t.Radius * 2, W.SteelDark, Enum.Material.DiamondPlate, { Name = "TurntableBase" })
	Kit.post(
		model,
		center * CFrame.new(0, 0.3, 0),
		0.1,
		t.Radius * 2 + 0.2,
		W.HazardYellow,
		Enum.Material.SmoothPlastic,
		{ Name = "BaseBand", Decor = true }
	)
	local deck = Kit.post(
		model,
		center * CFrame.new(0, 0.8, 0),
		t.TopY - 0.8,
		t.Radius * 2 - 1.2,
		Color3.fromRGB(64, 66, 62),
		Enum.Material.SmoothPlastic,
		{ Name = "ShowroomTurntable" }
	)
	deck:SetAttribute("Showroom", "Turntable")
	-- painted safety circle: 20 short segments, 0.06 above the floor
	local r = t.Radius + 2.2
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		Kit.part(
			model,
			Vector3.new(r * 2 * math.sin(math.pi / 20) * 0.92, 0.1, 0.4),
			center * CFrame.new(math.cos(a) * r, 0.01, math.sin(a) * r) * CFrame.Angles(0, -a - math.pi / 2, 0),
			W.HazardYellow,
			nil,
			{ Name = "SafetyLine", Decor = true }
		)
	end
	-- rope barrier on stanchions, and an invisible collider over the deck:
	-- each player's vehicle on show is a local, non-colliding copy
	local ring = t.Radius + 1.1
	local posts = 16
	for i = 0, posts - 1 do
		local a = i / posts * math.pi * 2
		local base = center * CFrame.new(math.cos(a) * ring, 0, math.sin(a) * ring)
		Kit.post(model, base, 0.2, 0.9, W.Charcoal, Enum.Material.Metal, { Name = "StanchionFoot" })
		Kit.post(model, base * CFrame.new(0, 0.2, 0), 2.6, 0.18, W.Steel, Enum.Material.Metal, { Name = "Stanchion" })
		local b = (i + 0.5) / posts * math.pi * 2
		local chord = 2 * ring * math.sin(math.pi / posts)
		Kit.part(
			model,
			Vector3.new(chord - 0.2, 0.1, 0.1),
			center
				* CFrame.new(
					math.cos(b) * ring * math.cos(math.pi / posts),
					2.45,
					math.sin(b) * ring * math.cos(math.pi / posts)
				)
				* CFrame.Angles(0, -b - math.pi / 2, 0),
			W.MutedRed,
			Enum.Material.Fabric,
			{ Name = "Rope", Decor = true }
		)
	end
	local collider = Kit.post(
		model,
		center * CFrame.new(0, 0.8, 0),
		10,
		t.Radius * 2,
		W.Screen,
		nil,
		{ Name = "DeckCollider", Transparency = 1, Collide = true, Query = false, Shadow = false }
	)
	collider:SetAttribute("Showroom", "Collider")
	return model, center * CFrame.new(0, t.TopY, 0)
end

-- Square truss over the turntable with four spotlights on the vehicle.
local function spotlightTruss(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "SpotlightTruss")
	local t = Garage.Turntable
	local y = 18.5
	local half = 11
	local steel = W.SteelDark
	for _, side in { -1, 1 } do
		Kit.part(
			model,
			Vector3.new(half * 2 + 0.8, 0.8, 0.8),
			frame * CFrame.new(t.X, y, t.Z + side * half),
			steel,
			Enum.Material.Metal,
			{ Name = "TrussBeam", Decor = true }
		)
		Kit.part(
			model,
			Vector3.new(0.8, 0.8, half * 2 - 0.8),
			frame * CFrame.new(t.X + side * half, y, t.Z),
			steel,
			Enum.Material.Metal,
			{ Name = "TrussBeam", Decor = true }
		)
	end
	local target = (frame * CFrame.new(t.X, Garage.FloorY + 3.5, t.Z)).Position
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local mount = frame * CFrame.new(t.X + corner[1] * (half - 1.2), y - 0.4, t.Z + corner[2] * (half - 1.2))
		-- hanging cable to the roof
		Kit.part(
			model,
			Vector3.new(0.08, 5.6, 0.08),
			frame * CFrame.new(t.X + corner[1] * half, y + 3.2, t.Z + corner[2] * half),
			W.Charcoal,
			nil,
			{ Name = "TrussCable", Decor = true }
		)
		local aim = CFrame.lookAt(mount.Position - Vector3.new(0, 0.9, 0), target)
		Kit.part(model, Vector3.new(0.3, 0.9, 0.3), mount * CFrame.new(0, -0.45, 0), steel, Enum.Material.Metal, {
			Name = "LampYoke",
			Decor = true,
		})
		local lamp = Kit.cylinder(
			model,
			1.6,
			1.2,
			aim * CFrame.Angles(0, math.pi / 2, 0),
			W.Charcoal,
			Enum.Material.Metal,
			{ Name = "Spotlight", Decor = true }
		)
		local lens = Kit.part(
			model,
			Vector3.new(0.9, 0.9, 0.05),
			aim * CFrame.new(0, 0, -0.83),
			Color3.fromRGB(255, 240, 210),
			Enum.Material.Glass,
			{ Name = "Lens", Decor = true }
		)
		local spot = Instance.new("SpotLight")
		spot.Name = "ShowroomSpot"
		spot.Face = Enum.NormalId.Front
		spot.Angle = 55
		spot.Range = 34
		spot.Brightness = 2
		spot.Color = Color3.fromRGB(255, 240, 214)
		spot.Shadows = false
		spot.Parent = lens
		lamp:SetAttribute("Showroom", "Spot")
	end
end

-- The backdrop on the back wall: regimental colours and the unit name.
local function backdrop(parent: Instance, frame: CFrame)
	local board = Kit.part(
		parent,
		Vector3.new(34, 12, 0.3),
		Kit.facingOut(frame, Vector3.new(0, Garage.FloorY + 9.5, -62.45)),
		Color3.fromRGB(46, 50, 40),
		Enum.Material.SmoothPlastic,
		{ Name = "ShowroomBackdrop" }
	)
	local gui = Kit.surface(board, Enum.NormalId.Front, 14, 1, 0)
	Kit.frame(gui, UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.09), Color3.fromRGB(170, 34, 38))
	Kit.frame(gui, UDim2.fromScale(0, 0.71), UDim2.fromScale(1, 0.09), Color3.fromRGB(232, 230, 222))
	Kit.text(gui, {
		Name = "Title",
		Text = "BLACKHORSE",
		Color = Color3.fromRGB(232, 230, 222),
		Font = Theme.font("Header", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(0.08, 0.1),
		Size = UDim2.fromScale(0.84, 0.36),
	})
	Kit.text(gui, {
		Name = "Subtitle",
		Text = "11TH ARMORED CAVALRY REGIMENT · MOTOR POOL",
		Color = Color3.fromRGB(206, 196, 160),
		Font = Theme.font("Header"),
		Position = UDim2.fromScale(0.08, 0.46),
		Size = UDim2.fromScale(0.84, 0.13),
	})
	Kit.text(gui, {
		Name = "Motto",
		Text = '"ALLONS"',
		Color = Color3.fromRGB(206, 196, 160),
		Font = Theme.font("Header"),
		Position = UDim2.fromScale(0.3, 0.84),
		Size = UDim2.fromScale(0.4, 0.12),
	})
	return board
end

local function console(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "ShowroomConsole")
	local base = frame * CFrame.new(0, Garage.FloorY, Garage.ConsoleZ)
	local desk = Common.console(model, base, 6)
	local screen = Common.crt(model, base * CFrame.new(0, 3.9, -2.3), 3.4, "Showroom")
	local _, content = Common.screen(screen, "ShowroomScreen", 60)
	Common.line(content, "Header", "MOTOR POOL // SHOWROOM", 0, 0.14, Common.Phosphor)
	Common.line(content, "Title", "VEHICLE FILES", 0.24, 0.22, Common.Phosphor, nil, Enum.TextXAlignment.Center)
	Common.line(
		content,
		"Units",
		("%d VEHICLES ON FILE"):format(#Units.Order),
		0.5,
		0.14,
		Common.Phosphor,
		nil,
		Enum.TextXAlignment.Center
	)
	Common.line(content, "Hint", "[E] OPEN SHOWROOM", 0.74, 0.16, Common.Amber, nil, Enum.TextXAlignment.Center)
	Interactions.attach(desk, "Showroom", "SHOWROOM", "VEHICLE SHOWROOM")
	return model
end

-- A vehicle under a canvas tarp: draped body, turret bump, tie-down ropes.
local function tarpedVehicle(parent: Instance, cf: CFrame)
	local model = Kit.model(parent, "TarpedVehicle")
	local canvas = Color3.fromRGB(92, 94, 66)
	Kit.part(model, Vector3.new(7, 3.4, 12.6), cf * CFrame.new(0, 1.9, 0), canvas, Enum.Material.Fabric, {
		Name = "Tarp",
	})
	Kit.wedge(model, Vector3.new(7, 0.9, 2.2), cf * CFrame.new(0, 4.05, -5.2), canvas, Enum.Material.Fabric, {
		Name = "TarpSlope",
	})
	Kit.part(model, Vector3.new(4.6, 1.5, 5), cf * CFrame.new(0, 4.35, 0.6), canvas, Enum.Material.Fabric, {
		Name = "TarpTurret",
	})
	for _, z in { -4, 0.6, 4.8 } do
		Kit.part(model, Vector3.new(7.08, 0.12, 0.12), cf * CFrame.new(0, 3.66, z), W.Paper, Enum.Material.Fabric, {
			Name = "Rope",
			Decor = true,
		})
	end
	for _, x in { -3.2, 3.2 } do
		for _, z in { -5.6, 5.6 } do
			Kit.part(
				model,
				Vector3.new(0.6, 0.8, 0.9),
				cf * CFrame.new(x * 1.03, 0.4, z),
				W.Charcoal,
				Enum.Material.Rubber,
				{
					Name = "TrackEnd",
				}
			)
		end
	end
	return model
end

-- Engine pack on a stand under an A-frame hoist with a chain block.
local function engineHoist(parent: Instance, cf: CFrame)
	local model = Kit.model(parent, "EngineHoist")
	local steel = W.SteelDark
	for _, x in { -3.6, 3.6 } do
		for _, z in { -1.4, 1.4 } do
			local lean = if z < 0 then -0.2 else 0.2
			-- the two legs of each A-frame stand side by side
			local lx = x + (if z < 0 then 0 else -math.sign(x) * 0.4)
			Kit.part(
				model,
				Vector3.new(0.35, 9.2, 0.35),
				cf * CFrame.new(lx, 4.5, z * 0.5) * CFrame.Angles(lean, 0, 0),
				steel,
				Enum.Material.Metal,
				{ Name = "HoistLeg" }
			)
		end
	end
	Kit.part(model, Vector3.new(8, 0.5, 0.5), cf * CFrame.new(0, 9.2, 0), W.HazardYellow, Enum.Material.Metal, {
		Name = "HoistBeam",
	})
	Kit.part(model, Vector3.new(0.9, 1.1, 0.7), cf * CFrame.new(0.6, 8.3, 0), W.Charcoal, Enum.Material.Metal, {
		Name = "ChainBlock",
		Decor = true,
	})
	Kit.part(model, Vector3.new(0.12, 3.2, 0.12), cf * CFrame.new(0.6, 6.1, 0), W.Steel, Enum.Material.Metal, {
		Name = "Chain",
		Decor = true,
	})
	-- engine block on its stand
	Kit.part(model, Vector3.new(2.6, 1.4, 1.6), cf * CFrame.new(0.6, 0.7, 0), steel, Enum.Material.Metal, {
		Name = "EngineStand",
	})
	Kit.part(
		model,
		Vector3.new(2.4, 2.2, 3.2),
		cf * CFrame.new(0.6, 2.5, 0),
		Color3.fromRGB(70, 74, 64),
		Enum.Material.Metal,
		{
			Name = "EngineBlock",
		}
	)
	Kit.part(model, Vector3.new(1.6, 0.6, 2.8), cf * CFrame.new(0.6, 3.9, 0), W.Charcoal, Enum.Material.Metal, {
		Name = "EngineHead",
	})
	return model
end

local function toolCart(parent: Instance, cf: CFrame)
	local model = Kit.model(parent, "ToolCart")
	local red = Color3.fromRGB(136, 44, 38)
	Kit.part(
		model,
		Vector3.new(2.6, 3, 1.5),
		cf * CFrame.new(0, 1.8, 0),
		red,
		Enum.Material.Metal,
		{ Name = "Cabinet" }
	)
	for i = 0, 3 do
		Kit.part(
			model,
			Vector3.new(2.3, 0.08, 0.06),
			cf * CFrame.new(0, 0.9 + i * 0.7, -0.78),
			W.Steel,
			Enum.Material.Metal,
			{
				Name = "DrawerPull",
				Decor = true,
			}
		)
	end
	for _, x in { -1, 1 } do
		for _, z in { -0.5, 0.5 } do
			Kit.cylinder(
				model,
				0.25,
				0.5,
				cf * CFrame.new(x, 0.25, z) * CFrame.Angles(0, math.pi / 2, 0),
				W.Charcoal,
				Enum.Material.Rubber,
				{
					Name = "Caster",
					Decor = true,
				}
			)
		end
	end
	return model
end

local function partsShelf(parent: Instance, cf: CFrame)
	local model = Kit.model(parent, "PartsShelf")
	local steel = Color3.fromRGB(82, 88, 76)
	for _, x in { -3.4, 3.4 } do
		for _, z in { -0.9, 0.9 } do
			Kit.part(
				model,
				Vector3.new(0.2, 7.5, 0.2),
				cf * CFrame.new(x, 3.75, z),
				steel,
				Enum.Material.Metal,
				{ Name = "Upright" }
			)
		end
	end
	local boxes = { Color3.fromRGB(92, 96, 64), Color3.fromRGB(150, 128, 92), Color3.fromRGB(70, 74, 64) }
	for level = 0, 3 do
		local y = 0.6 + level * 2.1
		Kit.part(
			model,
			Vector3.new(6.7, 0.15, 1.7),
			cf * CFrame.new(0, y, 0),
			steel,
			Enum.Material.Metal,
			{ Name = "ShelfBoard" }
		)
		for i = 0, 2 do
			Kit.part(
				model,
				Vector3.new(1.8, 1.2 - (i % 2) * 0.3, 1.4),
				cf * CFrame.new(-2.2 + i * 2.2, y + 0.075 + (1.2 - (i % 2) * 0.3) / 2, 0),
				boxes[(level + i) % 3 + 1],
				if (level + i) % 3 == 1 then Enum.Material.Cardboard else Enum.Material.Metal,
				{ Name = "PartsBox" }
			)
		end
	end
	return model
end

-- The old paint booth, kept as scenery (paint schemes are applied in the
-- showroom viewer now).
local function paintBooth(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "PaintBooth")
	local y = Garage.FloorY
	local base = frame * CFrame.new(28, y, -56)
	for _, x in { -6, 6 } do
		Kit.part(model, Vector3.new(0.6, 12, 0.6), base * CFrame.new(x, 6, 1), W.SteelDark, Enum.Material.Metal, {
			Name = "BoothPost",
		})
	end
	Kit.part(model, Vector3.new(12.6, 0.6, 6), base * CFrame.new(0, 12.3, -1.5), W.SteelDark, Enum.Material.Metal, {
		Name = "BoothRoof",
	})
	Kit.part(
		model,
		Vector3.new(12, 10, 0.3),
		base * CFrame.new(0, 5.4, -4.4),
		Color3.fromRGB(150, 150, 140),
		Enum.Material.Concrete,
		{
			Name = "BoothWall",
		}
	)
	local board = Kit.part(
		model,
		Vector3.new(8, 4.4, 0.2),
		base * CFrame.new(0, 7.4, -4.15) * CFrame.Angles(0, math.pi, 0),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{ Name = "SwatchBoard" }
	)
	local gui = Kit.surface(board, Enum.NormalId.Front, 30, 1, 120)
	Kit.text(gui, {
		Name = "Title",
		Text = "PAINT SCHEMES",
		Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.92, 0.18),
	})
	for i, camoId in Units.Camos.Order do
		local camo = Units.Camos.List[camoId]
		local x = 0.04 + (i - 1) * 0.19
		Kit.frame(gui, UDim2.fromScale(x, 0.28), UDim2.fromScale(0.17, 0.3), camo.Colors[1])
		Kit.frame(gui, UDim2.fromScale(x + 0.05, 0.34), UDim2.fromScale(0.08, 0.14), camo.Colors[2])
		Kit.text(gui, {
			Name = "Camo_" .. camoId,
			Text = camo.Name,
			Position = UDim2.fromScale(x, 0.62),
			Size = UDim2.fromScale(0.17, 0.3),
			Font = Theme.font("Body", Enum.FontWeight.Bold),
		})
	end
	for i, color in { Color3.fromRGB(86, 94, 58), Color3.fromRGB(128, 126, 118), Color3.fromRGB(176, 156, 112) } do
		Kit.cylinder(
			model,
			1.8,
			1.5,
			base * CFrame.new(-5 + i * 1.7, 0.9, -3) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			Enum.Material.Metal,
			{ Name = "PaintDrum" }
		)
	end
	return model
end

function Garage.build(zoneModel: Instance, frame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	local stage = Kit.folder(folder, "Showroom")
	local _, top = turntable(stage, frame)
	-- featured vehicle facing the doors; clients replace it with their pick
	local featured =
		Garage.display(stage, Garage.Featured, top * CFrame.Angles(0, math.pi * 0.85, 0), nil, false, false)
	featured:SetAttribute("ShowroomFeatured", true)
	spotlightTruss(stage, frame)
	backdrop(stage, frame)
	console(folder, frame)
	local y = Garage.FloorY
	local bays = Kit.folder(folder, "ServiceBays")
	tarpedVehicle(bays, frame * CFrame.new(-27, y, -24))
	engineHoist(bays, frame * CFrame.new(-27, y, -45))
	toolCart(bays, frame * CFrame.new(-21.5, y, -45) * CFrame.Angles(0, math.pi / 2, 0))
	toolCart(bays, frame * CFrame.new(30, y, -13) * CFrame.Angles(0, math.pi, 0))
	partsShelf(bays, frame * CFrame.new(29, y, -30) * CFrame.Angles(0, -math.pi / 2, 0))
	paintBooth(bays, frame)
end

return Garage
