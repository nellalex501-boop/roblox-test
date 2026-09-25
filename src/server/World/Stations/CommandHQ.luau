--!strict
-- Command HQ stations: commander's office (profile terminal), service
-- records room (statistics), quartermaster lockers (customisation) and the
-- trophy case (achievements).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Common = require(script.Parent.Common)
local Kit = require(World.Kit)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local MapDraw = require(ReplicatedStorage.Lobby.Util.MapDraw)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local CommandHQ = {}

CommandHQ.FloorY = 1.25

local function cabinet(parent: Instance, cf: CFrame, drawers: number, color: Color3?)
	local h = drawers * 1.3 + 0.4
	Kit.part(
		parent,
		Vector3.new(1.8, h, 2),
		cf * CFrame.new(0, h / 2, 0),
		color or Color3.fromRGB(96, 104, 92),
		Enum.Material.Metal,
		{ Name = "FilingCabinet" }
	)
	for i = 1, drawers do
		Kit.part(
			parent,
			Vector3.new(0.7, 0.14, 0.1),
			cf * CFrame.new(0, 0.2 + (i - 0.5) * 1.3, 1.02),
			W.Steel,
			Enum.Material.Metal,
			{
				Name = "Handle",
				Decor = true,
			}
		)
	end
end

local function office(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "CommanderOffice")
	local y = CommandHQ.FloorY
	-- desk faces the doorway (+Z of the desk frame toward the door at z=-20)
	local deskFrame = frame * CFrame.new(-11.5, y, -33) * CFrame.Angles(0, 0, 0)
	local desk = Kit.part(
		model,
		Vector3.new(9, 3, 4.2),
		deskFrame * CFrame.new(0, 1.5, 0),
		W.BrownDark,
		Enum.Material.Wood,
		{ Name = "Desk" }
	)
	Kit.part(
		model,
		Vector3.new(9.4, 0.3, 4.6),
		deskFrame * CFrame.new(0, 3.15, 0),
		W.Wood,
		Enum.Material.Wood,
		{ Name = "DeskTop" }
	)
	Kit.part(
		model,
		Vector3.new(3.6, 0.1, 2.4),
		deskFrame * CFrame.new(-2.2, 3.35, 0.6),
		Color3.fromRGB(46, 70, 52),
		Enum.Material.Fabric,
		{
			Name = "Blotter",
			Decor = true,
		}
	)
	-- large monitor turned toward the visitor, desk terminal, desk flags
	local screen = Common.crt(model, deskFrame * CFrame.new(1.8, 3.3, -0.8), 3.6, "Profile")
	local _, content = Common.screen(screen, "ProfileScreen", 60)
	Common.line(content, "Header", "PERSONNEL SYSTEM", 0, 0.14, Common.Phosphor)
	Common.line(content, "Title", "COMMANDER PROFILE", 0.22, 0.2, Common.Phosphor, nil, Enum.TextXAlignment.Center)
	Common.line(content, "Hint", "[E] LOG IN", 0.72, 0.16, Common.Amber, nil, Enum.TextXAlignment.Center)
	Interactions.attach(desk, "Profile", "PROFILE", "COMMANDER TERMINAL")
	for i, color in { Color3.fromRGB(34, 52, 94), Color3.fromRGB(78, 88, 54) } do
		local base = deskFrame * CFrame.new(-4 + i * 0.9, 3.3, -1.6)
		Kit.part(
			model,
			Vector3.new(0.08, 1.4, 0.08),
			base * CFrame.new(0, 0.7, 0),
			W.Steel,
			nil,
			{ Name = "DeskFlagPole", Decor = true }
		)
		Kit.part(
			model,
			Vector3.new(0.8, 0.5, 0.04),
			base * CFrame.new(0.44, 1.15, 0),
			color,
			Enum.Material.Fabric,
			{ Name = "DeskFlag", Decor = true }
		)
	end
	-- chair behind the desk: a swivel column on a cross base
	Kit.part(
		model,
		Vector3.new(0.35, 1.6, 0.35),
		deskFrame * CFrame.new(0, 0.8, -3.4),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "ChairColumn", Decor = true }
	)
	for _, rot in { 0, math.pi / 2 } do
		Kit.part(
			model,
			Vector3.new(1.9, 0.18, 0.3),
			deskFrame * CFrame.new(0, 0.09, -3.4) * CFrame.Angles(0, rot + math.pi / 4, 0),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "ChairBase", Decor = true }
		)
	end
	Kit.part(
		model,
		Vector3.new(2.4, 0.5, 2.4),
		deskFrame * CFrame.new(0, 1.8, -3.4),
		W.BrownDark,
		Enum.Material.Fabric,
		{ Name = "Chair" }
	)
	Kit.part(
		model,
		Vector3.new(2.2, 3, 0.5),
		deskFrame * CFrame.new(0, 3.3, -4.5),
		W.BrownDark,
		Enum.Material.Fabric,
		{ Name = "ChairBack" }
	)
	-- wall map behind the desk
	local mapPart = Kit.part(
		model,
		Vector3.new(12, 7, 0.2),
		-- on the back wall's inner face (z = -42.8), 0.02 into it
		Kit.facingOut(frame, Vector3.new(-11.5, y + 8, -42.72)),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{ Name = "OfficeMap" }
	)
	local gui = Kit.surface(mapPart, Enum.NormalId.Front, 22, 1, 100)
	MapDraw.theater(gui, 12 * 22, 7 * 22)
	-- filing cabinets and a radio set along the side wall
	for i = 0, 2 do
		cabinet(model, frame * CFrame.new(-21.6, y, -24 - i * 2.2) * CFrame.Angles(0, math.pi / 2, 0), 4)
	end
	local radio = Kit.part(
		model,
		Vector3.new(2.6, 1.6, 1.6),
		frame * CFrame.new(-21.4, y + 5.95, -26.2),
		Color3.fromRGB(70, 78, 60),
		Enum.Material.Metal,
		{
			Name = "RadioSet",
		}
	)
	Kit.anchor(radio, "Sound", "RadioChatter")
	return model
end

local function records(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "RecordsRoom")
	local y = CommandHQ.FloorY
	for _, z in { -41.2, -37 } do
		for i = 0, 3 do
			cabinet(model, frame * CFrame.new(3 + i * 2.1, y, z), 5, Color3.fromRGB(104, 110, 96))
		end
	end
	for i = 0, 3 do
		cabinet(model, frame * CFrame.new(21.6, y, -24 - i * 2.2) * CFrame.Angles(0, -math.pi / 2, 0), 4)
	end
	local deskFrame = frame * CFrame.new(12, y, -27)
	local desk = Common.console(model, deskFrame, 7, Color3.fromRGB(80, 74, 60))
	local screen = Common.crt(model, deskFrame * CFrame.new(0, 3.9, -2.3), 3.2, "Records")
	local _, content = Common.screen(screen, "RecordsScreen", 60)
	Common.line(content, "Header", "SERVICE RECORDS", 0, 0.16, Common.Phosphor)
	Common.line(content, "Title", "STATISTICS", 0.24, 0.2, Common.Phosphor, nil, Enum.TextXAlignment.Center)
	Common.line(content, "Hint", "[E] VIEW FILE", 0.72, 0.16, Common.Amber, nil, Enum.TextXAlignment.Center)
	Interactions.attach(desk, "Statistics", "RECORDS", "SERVICE RECORDS")
	return model
end

local function lockers(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "Quartermaster")
	local y = CommandHQ.FloorY
	-- lockers along the right lobby wall, doors facing into the lobby (-X)
	local base = frame * CFrame.new(21.6, y, -12) * CFrame.Angles(0, -math.pi / 2, 0)
	local first
	for i = -2, 2 do
		local locker = Kit.part(
			model,
			Vector3.new(1.7, 7, 1.8),
			base * CFrame.new(i * 1.8, 3.5, 0),
			W.OliveLight,
			Enum.Material.Metal,
			{ Name = "Locker" }
		)
		first = first or locker
		for s = 0, 2 do
			Kit.part(
				model,
				Vector3.new(1, 0.1, 0.1),
				base * CFrame.new(i * 1.8, 6 - s * 0.35, 0.93),
				W.Charcoal,
				nil,
				{ Name = "Vent", Decor = true }
			)
		end
		Kit.part(
			model,
			Vector3.new(0.12, 0.6, 0.1),
			base * CFrame.new(i * 1.8 + 0.6, 3.6, 0.92),
			W.Steel,
			Enum.Material.Metal,
			{ Name = "Latch", Decor = true }
		)
	end
	-- uniform stand beside the lockers
	local stand = frame * CFrame.new(18.4, y, -5.6)
	Kit.part(
		model,
		Vector3.new(1.6, 0.2, 1.6),
		stand * CFrame.new(0, 0.1, 0),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "StandBase", Decor = true }
	)
	Kit.part(
		model,
		Vector3.new(0.2, 3, 0.2),
		stand * CFrame.new(0, 1.6, 0),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "StandPole", Decor = true }
	)
	Kit.part(
		model,
		Vector3.new(2.2, 2.4, 1.1),
		stand * CFrame.new(0, 4.1, 0),
		W.Olive,
		Enum.Material.Fabric,
		{ Name = "Uniform" }
	)
	-- a head form on the collar, the beret pulled to one side on top
	Kit.part(
		model,
		Vector3.new(0.6, 0.8, 0.6),
		stand * CFrame.new(0, 5.68, 0),
		W.BeigeDark,
		Enum.Material.SmoothPlastic,
		{ Name = "HeadForm", Decor = true }
	)
	Kit.part(
		model,
		Vector3.new(1.0, 0.3, 1.1),
		stand * CFrame.new(0.08, 6.12, 0) * CFrame.Angles(0, 0, math.rad(-9)),
		W.MutedRed,
		Enum.Material.Fabric,
		{ Name = "Beret", Decor = true }
	)
	local counter = Kit.part(
		model,
		Vector3.new(2, 3.2, 6),
		frame * CFrame.new(18.6, y + 1.6, -12),
		W.BrownDark,
		Enum.Material.Wood,
		{
			Name = "IssueCounter",
		}
	)
	Interactions.attach(counter, "Customize", "LOCKERS", "QUARTERMASTER")
	-- on the wall above the lockers (inner face 1.2 behind their centre),
	-- high enough that the locker tops never cut it
	local sign = Kit.sign(
		model,
		base * CFrame.new(0, 8.6, -1.145) * CFrame.Angles(0, math.pi, 0),
		Vector2.new(8, 1.2),
		"QUARTERMASTER · CUSTOMIZATION",
		{
			Background = W.SignGreen,
			PixelsPerStud = 40,
			Depth = 0.15,
			MaxDistance = 90,
		}
	)
	sign.Name = "RoomSign"
	return model
end

local function trophies(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "TrophyCase")
	local y = CommandHQ.FloorY
	local base = frame * CFrame.new(-21.4, y, -12) * CFrame.Angles(0, math.pi / 2, 0)
	-- an open-fronted cabinet against the wall (inner face at base z = -1.4):
	-- back panel, sides, top and plinth, a velvet back, three shelves of cups
	-- and two front mullions. Nothing sits inside a solid block.
	local wood = W.BrownDark
	local function slab(size: Vector3, pos: Vector3, name: string, color: Color3?, material: Enum.Material?)
		return Kit.part(model, size, base * CFrame.new(pos), color or wood, material or Enum.Material.Wood, {
			Name = name,
		})
	end
	-- the sides stand on the floor under an overhanging top, the plinth sits
	-- between them: no two parts share an outer face
	slab(Vector3.new(9, 7, 0.3), Vector3.new(0, 3.5, -1.27), "CaseBackPanel")
	for _, x in { -4.35, 4.35 } do
		slab(Vector3.new(0.3, 6.6, 2.1), Vector3.new(x, 3.3, -0.07), "CaseSide")
	end
	slab(Vector3.new(9.2, 0.4, 2.25), Vector3.new(0, 6.8, 0.005), "CaseTop")
	local case = slab(Vector3.new(8.4, 1, 2.1), Vector3.new(0, 0.5, -0.07), "Case")
	slab(
		Vector3.new(8.4, 5.6, 0.1),
		Vector3.new(0, 3.8, -1.07),
		"CaseVelvet",
		Color3.fromRGB(70, 30, 28),
		Enum.Material.Fabric
	)
	local gold = Color3.fromRGB(176, 146, 78)
	for shelf = 0, 2 do
		local sy = 1 + shelf * 1.85
		if shelf > 0 then
			slab(Vector3.new(8.4, 0.15, 1.9), Vector3.new(0, sy, -0.07), "Shelf", W.Wood)
		end
		local top = if shelf == 0 then 1 else sy + 0.075
		for i = -1, 1 do
			local cup = base * CFrame.new(i * 2.6 + shelf * 0.3 - 0.3, top, -0.25)
			Kit.part(
				model,
				Vector3.new(0.6, 0.3, 0.6),
				cup * CFrame.new(0, 0.15, 0),
				W.Charcoal,
				nil,
				{ Name = "TrophyBase", Decor = true }
			)
			Kit.part(
				model,
				Vector3.new(0.18, 0.7, 0.18),
				cup * CFrame.new(0, 0.65, 0),
				gold,
				Enum.Material.Metal,
				{ Name = "TrophyStem", Decor = true }
			)
			Kit.ball(
				model,
				0.7,
				cup * CFrame.new(0, 1.25, 0),
				gold,
				Enum.Material.Metal,
				{ Name = "TrophyCup", Decor = true }
			)
		end
	end
	-- front mullions from the plinth to the top (no glass: no transparency cost)
	for _, x in { -1.45, 1.45 } do
		Kit.part(
			model,
			Vector3.new(0.15, 5.6, 0.15),
			base * CFrame.new(x, 3.8, 0.9),
			W.Wood,
			Enum.Material.Wood,
			{ Name = "Mullion", Decor = true }
		)
	end
	Interactions.attach(case, "Achievements", "TROPHIES", "AWARDS CASE")
	-- on the wall above the case
	local sign = Kit.sign(
		model,
		base * CFrame.new(0, 8.3, -1.345) * CFrame.Angles(0, math.pi, 0),
		Vector2.new(7, 1.2),
		"AWARDS CASE · ACHIEVEMENTS",
		{
			Background = W.BrownDark,
			TextColor = Color3.fromRGB(214, 190, 120),
			PixelsPerStud = 40,
			Depth = 0.15,
			MaxDistance = 90,
		}
	)
	sign.Name = "RoomSign"
	return model
end

function CommandHQ.build(zoneModel: Instance, frame: CFrame)
	local folder = Kit.folder(zoneModel, "Stations")
	office(folder, frame)
	records(folder, frame)
	lockers(folder, frame)
	trophies(folder, frame)
	-- door plates over the back-room doorways, 0.02 into the lintel (its
	-- face is at z -19.7)
	for _, spec in { { X = -11.5, Text = "COMMANDING OFFICER" }, { X = 11.5, Text = "SERVICE RECORDS" } } do
		local plate = Kit.sign(
			folder,
			Kit.facingOut(frame, Vector3.new(spec.X, CommandHQ.FloorY + 10.9, -19.66)),
			Vector2.new(7, 1),
			spec.Text,
			{
				Background = W.OffWhite,
				TextColor = W.Charcoal,
				Depth = 0.12,
				PixelsPerStud = 40,
				MaxDistance = 80,
			}
		)
		plate.Name = "DoorPlate"
	end
end

return CommandHQ
