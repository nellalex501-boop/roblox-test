--!strict
-- Garage stations: showcase vehicles in the six bays (each inspectable),
-- unit placards, the Unit Registry terminal (collection) and the Paint Shop
-- (cosmetic camo customisation).

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

-- Bay layout (garage frame, +Z toward the doors) and the unit shown.
Garage.Showcase = {
	{ Unit = "M1_ABRAMS", X = -26, Z = -19 },
	{ Unit = "T72", X = 0, Z = -19 },
	{ Unit = "M2_BRADLEY", X = 26, Z = -19 },
	{ Unit = "BMP2", X = -26, Z = -45 },
	{ Unit = "BTR70", X = 0, Z = -45 },
	{ Unit = "ZSU234", X = 26, Z = -45 },
}

local CATEGORY_SHORT = {
	MBT = "MAIN BATTLE TANK",
	IFV = "INFANTRY FIGHTING VEHICLE",
	APC = "ARMOURED CARRIER",
	RECON = "RECONNAISSANCE",
	AA = "AIR DEFENCE",
	SUPPLY = "LOGISTICS",
}

-- Places a unit on display with an inspect prompt and a placard.
-- Also used by the Event Area for the limited unit.
function Garage.display(
	parent: Instance,
	unitId: string,
	frame: CFrame,
	paint: Vehicles.Paint?,
	withPlacard: boolean?
): Model
	local unit = Units.List[unitId]
	assert(unit, "unknown unit " .. unitId)
	local model = Kit.model(parent, "Showcase_" .. unitId)
	local vehiclePaint = paint or Vehicles.DefaultPaint[unit.Faction] or Vehicles.DefaultPaint.NATO
	local vehicle = Vehicles.spawn(model, unitId, unit.Model, frame, vehiclePaint, Vector3.new(14, 11, 22))
	vehicle:SetAttribute("UnitId", unitId)
	-- invisible anchor carrying the prompt so it works for asset overrides too
	local anchor = Kit.part(model, Vector3.new(1, 1, 1), frame * CFrame.new(0, 5, 0), W.Screen, nil, {
		Name = "InspectAnchor",
		Transparency = 1,
		Decor = true,
	})
	Interactions.attach(anchor, "UnitInspect", unitId, unit.Name)
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

local function registry(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "UnitRegistry")
	local y = Garage.FloorY
	local base = frame * CFrame.new(-8, y, -58)
	local desk = Common.console(model, base, 7)
	local screen = Common.crt(model, base * CFrame.new(0, 3.9, -2.3), 3.4, "Registry")
	local _, content = Common.screen(screen, "RegistryScreen", 60)
	Common.line(content, "Header", "MOTOR POOL DATABASE", 0, 0.14, Common.Phosphor)
	Common.line(content, "Title", "UNIT REGISTRY", 0.24, 0.2, Common.Phosphor, nil, Enum.TextXAlignment.Center)
	Common.line(content, "Hint", "[E] OPEN FILES", 0.72, 0.16, Common.Amber, nil, Enum.TextXAlignment.Center)
	Interactions.attach(desk, "UnitCollection", "REGISTRY", "UNIT REGISTRY")
	-- big registry board on the back wall
	local board = Kit.part(
		model,
		Vector3.new(14, 7, 0.3),
		Kit.facingOut(frame, Vector3.new(-8, y + 10.5, -62.6)),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{
			Name = "RegistryBoard",
		}
	)
	local _, boardContent = Common.screen(board, "RegistryBoard", 24)
	Common.line(boardContent, "Header", "UNIT REGISTRY // FULDA SECTOR", 0, 0.14, Common.Amber)
	local y0 = 0.18
	for i, category in { "MBT", "IFV", "APC", "RECON", "AA", "SUPPLY" } do
		local count = 0
		for _, unit in Units.List do
			if unit.Category == category then
				count += 1
			end
		end
		Common.line(
			boardContent,
			"Category_" .. category,
			("%-26s %2d UNITS"):format(Units.Categories[category], count),
			y0 + (i - 1) * 0.13,
			0.11,
			Common.Phosphor
		)
	end
	return model
end

local function paintShop(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "PaintShop")
	local y = Garage.FloorY
	local base = frame * CFrame.new(26, y, -57)
	-- booth frame
	for _, x in { -6, 6 } do
		Kit.part(
			model,
			Vector3.new(0.6, 12, 0.6),
			base * CFrame.new(x, 6, 1),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "BoothPost" }
		)
	end
	Kit.part(
		model,
		Vector3.new(12.6, 0.6, 6),
		base * CFrame.new(0, 12, -1.5),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "BoothRoof" }
	)
	Kit.part(
		model,
		Vector3.new(12, 10, 0.3),
		base * CFrame.new(0, 5.4, -4.4),
		Color3.fromRGB(150, 150, 140),
		Enum.Material.Concrete,
		{ Name = "BoothWall" }
	)
	-- camo swatch board
	local board = Kit.part(
		model,
		Vector3.new(8, 4.4, 0.2),
		base * CFrame.new(0, 7.4, -4.15) * CFrame.Angles(0, math.pi, 0),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{
			Name = "SwatchBoard",
		}
	)
	local gui = Kit.surface(board, Enum.NormalId.Front, 30, 0.3, 90)
	Kit.text(gui, {
		Name = "Title",
		Text = "PAINT SHOP · CAMOUFLAGE",
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
	local desk = Common.console(model, base * CFrame.new(0, 0, 2.2), 5, Color3.fromRGB(88, 84, 70))
	Interactions.attach(desk, "UnitCosmetics", "PAINT", "PAINT SHOP")
	-- paint drums
	for i, color in { Color3.fromRGB(86, 94, 58), Color3.fromRGB(128, 126, 118), Color3.fromRGB(176, 156, 112) } do
		Kit.cylinder(
			model,
			1.8,
			1.5,
			base * CFrame.new(-5 + i * 1.7, 0.9, -3) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			Enum.Material.Metal,
			{
				Name = "PaintDrum",
			}
		)
	end
	return model
end

function Garage.build(zoneModel: Instance, frame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	local showcase = Kit.folder(folder, "Showcase")
	for _, slot in Garage.Showcase do
		-- vehicles face the doors (+Z of the garage frame)
		local vehicleFrame = frame * CFrame.new(slot.X, Garage.FloorY, slot.Z) * CFrame.Angles(0, math.pi, 0)
		Garage.display(showcase, slot.Unit, vehicleFrame)
	end
	registry(folder, frame)
	paintShop(folder, frame)
end

return Garage
