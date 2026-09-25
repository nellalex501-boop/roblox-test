--!strict
-- Interior detailing: light fittings, furniture and working clutter for the
-- Operations Center (hall + signals room + briefing room), Map Room,
-- Command HQ, Garage and the canteen. Positions are in each zone's frame
-- (see Layout.frame: -Z points into the building).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Common = require(World.Stations.Common)
local Kit = require(World.Kit)
local Props = require(World.Props)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Interior = {}

local LEFT = CFrame.Angles(0, math.pi / 2, 0) -- front toward -X
local RIGHT = CFrame.Angles(0, -math.pi / 2, 0) -- front toward +X
local BACK = CFrame.Angles(0, math.pi, 0) -- front toward +Z (the entrance)

local function grounded<T>(model: T): T
	(model :: any):SetAttribute("Grounded", true)
	return model
end

-- Small desk CRT + keyboard (decor only; the interactive CRTs live in
-- Stations). The screen faces +Z of `cf`, where the operator sits.
local function deskCrt(parent: Instance, cf: CFrame)
	Kit.part(parent, Vector3.new(1.6, 1.4, 1.6), cf * CFrame.new(0, 0.7, -0.1), W.Beige, Enum.Material.SmoothPlastic, {
		Name = "CrtCase",
		Decor = true,
	})
	local glass = Kit.part(
		parent,
		Vector3.new(1.2, 0.9, 0.05),
		cf * CFrame.new(0, 0.75, 0.72) * BACK,
		Color3.fromRGB(40, 64, 44),
		Enum.Material.SmoothPlastic,
		{ Name = "CrtGlass", Decor = true }
	)
	-- a live watch screen, not a dead one
	local _, content = Common.screen(glass, "WatchCrt", 60)
	Common.line(content, "Net", "C3-NET", 0.05, 0.4, Common.Phosphor)
	Common.line(content, "Link", "LINK OK", 0.52, 0.4, Common.Amber)
	Kit.part(
		parent,
		Vector3.new(1.5, 0.12, 0.55),
		cf * CFrame.new(0, 0.06, 1.2),
		W.Beige,
		Enum.Material.SmoothPlastic,
		{
			Name = "Keyboard",
			Decor = true,
		}
	)
end

local function phone(parent: Instance, cf: CFrame)
	Kit.part(
		parent,
		Vector3.new(0.9, 0.35, 0.7),
		cf * CFrame.new(0, 0.18, 0),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{
			Name = "Phone",
			Decor = true,
		}
	)
end

local function papers(parent: Instance, cf: CFrame)
	Kit.part(parent, Vector3.new(0.9, 0.05, 1.2), cf * CFrame.new(0, 0.03, 0), W.Paper, Enum.Material.SmoothPlastic, {
		Name = "Papers",
		Decor = true,
	})
end

-- Operations Center --------------------------------------------------------------

local function operationsCenter(parent: Instance)
	local folder = Kit.folder(parent, "OperationsCenter")
	local frame = Layout.frame(Layout.Zones.OperationsCenter)
	local floor = 0.65
	local ceiling = 22.6
	-- light fittings on short drop cords: a 3 x 3 grid over the whole hall,
	-- all lit, hung above the terminal signs' top edge (19.1) so they never
	-- come between the doorway and a sign
	local hang = 20.5
	for _, x in { -22, 0, 22 } do
		for _, z in { -12, -30, -48 } do
			local fitting = frame * CFrame.new(x, hang, z)
			Props.ceilingLight(folder, fitting, true, 6, 26)
			for _, dx in { -2.4, 2.4 } do
				Kit.part(
					folder,
					Vector3.new(0.08, ceiling - hang, 0.08),
					fitting * CFrame.new(dx, (ceiling - hang) / 2, 0),
					W.Charcoal,
					nil,
					{ Name = "Cord", Decor = true }
				)
			end
		end
	end
	-- watch desks facing the command wall
	for _, x in { -14, -4.7, 4.7, 14 } do
		local desk = frame * CFrame.new(x, floor, -52)
		grounded(Props.desk(folder, desk, 5))
		deskCrt(folder, desk * CFrame.new(-0.6, 2.93, -0.2))
		phone(folder, desk * CFrame.new(1.7, 2.93, 0.2))
		papers(folder, desk * CFrame.new(1.2, 2.93, 0.6))
		grounded(Props.chair(folder, desk * CFrame.new(-0.4, 0, 2.4)))
	end
	-- world clocks beside the command wall (static, matching the lobby's
	-- 15:36 local light): Washington, Zulu, Bonn, Moscow
	local clocks: { { x: number, label: string, hours: number } } = {
		{ x = -30, label = "WASHINGTON", hours = 9.6 },
		{ x = -24, label = "ZULU", hours = 14.6 },
		{ x = 24, label = "BONN", hours = 15.6 },
		{ x = 30, label = "MOSCOW", hours = 17.6 },
	}
	for _, c in clocks do
		-- on the back wall (inner face z = -62.8)
		Props.wallClock(folder, Kit.facingOut(frame, Vector3.new(c.x, 12, -62.7)), c.label, c.hours)
	end
	-- entrance side: filing cabinets and a water cooler
	for i = 0, 2 do
		-- clear of the dado rail along the wall
		grounded(Props.cabinet(folder, frame * CFrame.new(-32.2, floor, -6 - i * 2.2) * RIGHT))
		grounded(Props.cabinet(folder, frame * CFrame.new(32.2, floor, -6 - i * 2.2) * LEFT))
	end
	grounded(Props.waterCooler(folder, frame * CFrame.new(32.6, floor, -14)))
	grounded(Props.fireExtinguisher(folder, frame * CFrame.new(-33, floor, -16)))

	-- west wing: signals room (radio racks, operator desks)
	local signals = Kit.folder(folder, "SignalsRoom")
	for i = 0, 5 do
		local z = -8 - i * 8.4
		local rack = grounded(Props.cabinet(signals, frame * CFrame.new(-47.6, floor, z) * RIGHT, W.SteelDark))
		local lamp = Kit.part(
			rack,
			Vector3.new(0.12, 0.3, 0.3),
			frame * CFrame.new(-46.5, floor + 3.8, z),
			if i % 2 == 0 then W.LampRed else Color3.fromRGB(150, 200, 130),
			Enum.Material.Neon,
			{ Name = "RackLamp", Decor = true }
		)
		Kit.anchor(lamp, if i % 3 == 0 then "BlinkFast" else "BlinkSlow")
	end
	for _, z in { -12, -30, -52 } do
		local desk = frame * CFrame.new(-41, floor, z) * RIGHT
		grounded(Props.desk(signals, desk, 5))
		Props.radio(signals, desk * CFrame.new(-0.8, 2.93, 0.3))
		papers(signals, desk * CFrame.new(1, 2.93, -0.2))
		grounded(Props.chair(signals, desk * CFrame.new(0, 0, 2.4)))
	end
	Props.ceilingLight(signals, frame * CFrame.new(-42, ceiling - 0.2, -20), true, 5, 24)
	Props.ceilingLight(signals, frame * CFrame.new(-42, ceiling - 0.2, -46), true, 5, 24)

	-- east wing: briefing room (rows of chairs facing the briefing board)
	local briefing = Kit.folder(folder, "BriefingRoom")
	-- board on the outer (east) wall; three rows of chairs face it (+X)
	local screen = Kit.part(
		briefing,
		Vector3.new(0.3, 7, 11),
		-- against the wall's inner face (x = 48.8), 0.02 into it
		frame * CFrame.new(48.67, floor + 7, -54),
		W.Beige,
		Enum.Material.SmoothPlastic,
		{ Name = "BriefingBoard" }
	)
	-- the projected slide: a situation sketch and three points
	local slide = Kit.surface(screen, Enum.NormalId.Left, 30, 0.6, 120)
	slide.Name = "BriefingSlide"
	Kit.text(slide, {
		Name = "Title",
		Text = "SITREP 0600Z · FULDA GAP",
		Color = W.Charcoal,
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.9, 0.12),
	})
	Kit.frame(slide, UDim2.fromScale(0.05, 0.19), UDim2.fromScale(0.9, 0.012), W.MutedRed)
	for i, line in { "1  ENEMY: 8TH GUARDS ARMY", "2  FRIENDLY: 11TH ACR SCREEN", "3  MISSION: HOLD THE GAP" } do
		Kit.text(slide, {
			Name = "Point" .. i,
			Text = line,
			Color = W.Charcoal,
			Font = Theme.font("Mono", Enum.FontWeight.Bold),
			XAlign = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.06, 0.26 + (i - 1) * 0.2),
			Size = UDim2.fromScale(0.88, 0.14),
		})
	end
	for row = 0, 2 do
		for seat = 0, 3 do
			local cf = frame * CFrame.new(36.5 + row * 2.8, floor, -50 - seat * 2.3) * RIGHT
			grounded(Props.chair(briefing, cf, W.OliveDark))
		end
	end
	grounded(Props.desk(briefing, frame * CFrame.new(46.4, floor, -44.5) * LEFT, 4))
	Props.ceilingLight(briefing, frame * CFrame.new(42, ceiling - 0.2, -48), true, 5, 24)
	Props.ceilingLight(briefing, frame * CFrame.new(42, ceiling - 0.2, -18), true, 5, 24)
end

-- Map Room --------------------------------------------------------------------------

local function mapRoom(parent: Instance)
	local folder = Kit.folder(parent, "MapRoom")
	local frame = Layout.frame(Layout.Zones.MapRoom)
	local floor = 0.6
	-- four fluorescent fittings under the 18-stud ceiling
	for _, x in { -12, 12 } do
		for _, z in { -12, -36 } do
			-- mounted on the ceiling (underside at 17.8)
			Props.ceilingLight(folder, frame * CFrame.new(x, 17.8, z), true, 6, 22)
		end
	end
	-- chairs around the planning table (centre (0, -26), 20 x 13)
	for _, x in { -6, 0, 6 } do
		grounded(Props.chair(folder, frame * CFrame.new(x, floor, -26 + 8.6)))
		grounded(Props.chair(folder, frame * CFrame.new(x, floor, -26 - 8.6) * BACK))
	end
	grounded(Props.cabinet(folder, frame * CFrame.new(-23.6, floor, -3.5) * RIGHT))
	grounded(Props.cabinet(folder, frame * CFrame.new(-23.6, floor, -5.7) * RIGHT))
	local side = frame * CFrame.new(21.5, floor, -4.5) * LEFT
	grounded(Props.desk(folder, side, 4))
	Props.coffeeUrn(folder, side * CFrame.new(-0.6, 2.93, 0))
	-- over the door, on the front wall's inner face (z = -1)
	Props.wallClock(folder, frame * CFrame.new(0, 14.2, -1.1), "ZULU", 14.6)
end

-- Command HQ --------------------------------------------------------------------------

local function commandHQ(parent: Instance)
	local folder = Kit.folder(parent, "CommandHQ")
	local frame = Layout.frame(Layout.Zones.CommandHQ)
	local floor = 1.25
	local ceiling = 17
	-- lobby
	for _, x in { -12, 12 } do
		Props.ceilingLight(folder, frame * CFrame.new(x, ceiling, -10), true, 5)
	end
	local plant = Kit.model(folder, "Plant")
	Kit.post(plant, frame * CFrame.new(-17, floor, -3.2), 1.8, 1.6, W.BrownDark, Enum.Material.Wood, {
		Name = "Pot",
		Shadow = true,
	})
	Kit.ball(plant, 2.8, frame * CFrame.new(-17, floor + 3.2, -3.2), W.Foliage, Enum.Material.Grass, {
		Name = "Leaves",
		Decor = true,
	})
	grounded(plant)
	grounded(Props.bench(folder, frame * CFrame.new(11, floor, -3.2), 5))
	-- commander's office
	local office = Kit.folder(folder, "Office")
	Props.ceilingLight(office, frame * CFrame.new(-11.5, ceiling, -31), true, 5)
	Kit.box(
		office,
		frame,
		Vector3.new(-18, floor, -38.5),
		Vector3.new(-5, floor + 0.06, -27.5),
		W.MutedRed,
		Enum.Material.Fabric,
		{ Name = "Rug", Decor = true }
	)
	grounded(Props.bookshelf(office, frame * CFrame.new(-21.6, floor, -37) * RIGHT, 6))
	local globe = Kit.model(office, "Globe")
	Kit.post(globe, frame * CFrame.new(-3.5, floor, -39), 3, 0.3, W.BrownDark, Enum.Material.Wood, {
		Name = "Stand",
		Shadow = true,
	})
	Kit.ball(globe, 2.2, frame * CFrame.new(-3.5, floor + 4, -39), W.MutedBlue, Enum.Material.SmoothPlastic, {
		Name = "Globe",
		Decor = true,
	})
	grounded(globe)
	-- records room
	Props.ceilingLight(folder, frame * CFrame.new(11.5, ceiling, -31), true, 5)
end

-- Garage --------------------------------------------------------------------------------

local function garage(parent: Instance)
	local folder = Kit.folder(parent, "Garage")
	local frame = Layout.frame(Layout.Zones.Garage)
	local floor = 0.4
	-- high-bay fittings over the service bays and the console area (the
	-- spotlight truss lights the turntable), all lit, reaching the floor
	-- (each on two drop cords from a tie beam, underside at 23.2)
	for _, spot in { { -26, -23 }, { 26, -23 }, { -26, -45 }, { 26, -45 }, { 0, -8 } } do
		local fitting = frame * CFrame.new(spot[1], 21.5, spot[2])
		Props.ceilingLight(folder, fitting, true, 7, 28)
		for _, dx in { -2.8, 2.8 } do
			Kit.part(folder, Vector3.new(0.08, 1.8, 0.08), fitting * CFrame.new(dx, 0.85, 0), W.Charcoal, nil, {
				Name = "Cord",
				Decor = true,
			})
		end
	end
	-- workshop walls: benches, tyres, drums, extinguishers
	for _, side in { -1, 1 } do
		local x = side * 39.3
		local facing = if side < 0 then RIGHT else LEFT
		for _, z in { -8, -32 } do
			-- pegboard (+Z of the bench) against the side wall
			grounded(Props.toolBench(folder, frame * CFrame.new(x, floor, z) * facing))
		end
		grounded(Props.tireStack(folder, frame * CFrame.new(side * 38.8, floor, -20), 4))
		grounded(Props.fireExtinguisher(folder, frame * CFrame.new(side * 40.2, floor, -40)))
	end
	grounded(Props.drumCluster(folder, frame * CFrame.new(37, floor, -52), 4))
	grounded(Props.jerrycans(folder, frame * CFrame.new(38.6, floor, -46) * LEFT, 4))
	-- back of the hall: forklift and loaded pallets
	-- (back-row display vehicles reach local z -53.5)
	grounded(Props.forklift(folder, frame * CFrame.new(-36, floor, -58.5) * RIGHT))
	for i, x in { -25, -19.5 } do
		grounded(Props.pallet(folder, frame * CFrame.new(x, floor, -60), i == 1))
	end
	grounded(Props.crateStack(folder, frame * CFrame.new(-37, floor, -46)))
end

-- Canteen --------------------------------------------------------------------------------

local function canteen(parent: Instance)
	local folder = Kit.folder(parent, "Canteen")
	-- canteen frame: door at z = 0, interior x ±27, z -1 .. -25
	local frame = Layout.frame(Layout.Zones.SocialArea) * CFrame.new(0, 0, -44)
	local floor = 0.65
	for _, x in { -16, 0, 16 } do
		-- mounted on the ceiling (underside at 10.8)
		Props.ceilingLight(folder, frame * CFrame.new(x, 10.8, -13), true, 6, 16)
	end
	-- eight tables in two blocks either side of the aisle from the door
	for _, spot in
		{ { -17, -7 }, { -17, -15 }, { -8, -7 }, { -8, -15 }, { 8, -7 }, { 8, -15 }, { 17, -7 }, { 17, -15 } }
	do
		local table_ = Kit.model(folder, "CanteenTable")
		Kit.part(
			table_,
			Vector3.new(6, 0.25, 3),
			frame * CFrame.new(spot[1], floor + 2.7, spot[2]),
			W.Wood,
			Enum.Material.Wood,
			{
				Name = "Top",
				Shadow = true,
			}
		)
		Kit.post(table_, frame * CFrame.new(spot[1], floor, spot[2]), 2.6, 0.4, W.SteelDark, Enum.Material.Metal, {
			Name = "Stem",
			Decor = true,
		})
		grounded(table_)
		for _, dx in { -1.6, 1.6 } do
			grounded(Props.chair(folder, frame * CFrame.new(spot[1] + dx, floor, spot[2] - 2.3) * BACK, W.Wood))
			grounded(Props.chair(folder, frame * CFrame.new(spot[1] + dx, floor, spot[2] + 2.3), W.Wood))
		end
	end
	-- serving counter along the back wall with the menu board
	local counter = Kit.model(folder, "Counter")
	Kit.box(
		counter,
		frame,
		Vector3.new(-9, floor, -24.6),
		Vector3.new(9, floor + 3.4, -22.4),
		W.BrownDark,
		Enum.Material.Wood,
		{
			Name = "Counter",
		}
	)
	grounded(counter)
	Props.coffeeUrn(folder, frame * CFrame.new(-5, floor + 3.4, -23.5))
	-- till, tray stack and a bread basket on the counter
	local counterTop = floor + 3.4
	Kit.part(folder, Vector3.new(1.4, 1, 1.1), frame * CFrame.new(4.5, counterTop + 0.5, -23.4), W.Beige, nil, {
		Name = "Till",
		Decor = true,
	})
	Kit.part(folder, Vector3.new(1.8, 0.6, 1.3), frame * CFrame.new(7.2, counterTop + 0.3, -23.3), W.SteelDark, nil, {
		Name = "Trays",
		Decor = true,
	})
	Kit.part(
		folder,
		Vector3.new(1.3, 0.5, 0.9),
		frame * CFrame.new(1.6, counterTop + 0.25, -23.4),
		W.Wood,
		Enum.Material.Wood,
		{
			Name = "BreadBasket",
			Decor = true,
		}
	)
	-- wall clock on the back wall over the till (there is no room above
	-- the door under the ceiling), a dartboard and a corner television
	Props.wallClock(folder, frame * CFrame.new(7.2, 8.8, -24.9) * BACK, "BONN", 15.6)
	Kit.cylinder(
		folder,
		0.2,
		1.8,
		-- on the solid wall between the last side window and the back wall
		frame * CFrame.new(-26.9, floor + 5.6, -22.6),
		Color3.fromRGB(46, 44, 40),
		Enum.Material.Fabric,
		{ Name = "Dartboard", Decor = true }
	)
	Kit.cylinder(
		folder,
		0.25,
		0.6,
		frame * CFrame.new(-26.825, floor + 5.6, -22.6),
		W.MutedRed,
		Enum.Material.Fabric,
		{ Name = "Bullseye", Decor = true }
	)
	local tv = Kit.model(folder, "Television")
	Kit.part(tv, Vector3.new(2, 0.2, 2), frame * CFrame.new(-26, 8.1, -2.3), W.SteelDark, Enum.Material.Metal, {
		Name = "Bracket",
	})
	Kit.part(tv, Vector3.new(1.8, 1.7, 2.2), frame * CFrame.new(-25.9, 9.05, -2.3), W.Charcoal, nil, {
		Name = "TvCase",
	})
	local tvGlass = Kit.part(
		tv,
		Vector3.new(1.7, 1.2, 0.1),
		frame * CFrame.new(-24.96, 9.05, -2.3) * CFrame.Angles(0, -math.pi / 2, 0),
		Color3.fromRGB(40, 64, 44),
		nil,
		{ Name = "TvGlass", Decor = true }
	)
	local _, tvContent = Common.screen(tvGlass, "CanteenTv", 50)
	Common.line(tvContent, "Channel", "AFN", 0.08, 0.45, Common.Amber)
	Common.line(tvContent, "Show", "NEWS", 0.52, 0.4, Common.Phosphor)
	-- coat rack by the door
	local rack = Kit.model(folder, "CoatRack")
	Kit.post(rack, frame * CFrame.new(-7, floor, -2.4), 6.4, 0.25, W.BrownDark, Enum.Material.Wood, { Name = "Stand" })
	Kit.post(rack, frame * CFrame.new(-7, floor, -2.4), 0.2, 1.6, W.BrownDark, Enum.Material.Wood, { Name = "Foot" })
	Kit.part(
		rack,
		Vector3.new(1.2, 2.2, 0.7),
		frame * CFrame.new(-7, floor + 4.4, -2.05),
		W.OliveDark,
		Enum.Material.Fabric,
		{
			Name = "Parka",
			Decor = true,
		}
	)
	grounded(rack)
	-- menu board on the back wall (inner face z = -25), 0.02 into it
	Kit.sign(folder, frame * CFrame.new(0, 7.6, -24.945) * BACK, Vector2.new(9, 2.6), "HEUTE: ERBSENSUPPE", {
		Background = W.Charcoal,
		TextColor = W.Paper,
		Subtitle = "KAFFEE 0,50 DM · TEE 0,40 DM",
		Depth = 0.15,
		PixelsPerStud = 32,
		MaxDistance = 70,
	})
	grounded(Props.vendingMachine(folder, frame * CFrame.new(24.4, floor, -3.2) * LEFT))
end

function Interior.build(parent: Instance)
	local folder = Kit.folder(parent, "Interior")
	operationsCenter(folder)
	mapRoom(folder)
	commandHQ(folder)
	garage(folder)
	canteen(folder)
end

return Interior
