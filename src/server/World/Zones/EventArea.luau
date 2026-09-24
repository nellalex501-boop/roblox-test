--!strict
-- EVENT AREA — permanent compound for temporary operations.
--
-- Permanent: fenced gravel yard, gate arch, event HQ tent, billboard frame,
-- limited-unit display pad. Replaceable: everything under the "Dressing"
-- model and the texts on the gate banner/billboard, which are driven by the
-- active event (Config/Events). Swapping events rebuilds only those parts
-- (see EventArea.applyEvent).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Architecture = require(World.Architecture)
local Kit = require(World.Kit)
local Layout = require(ReplicatedStorage.Lobby.Config.Layout)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local EventArea = {}

EventArea.TentFront = -36
EventArea.DisplayPad = Vector3.new(16, 0, -22)
-- NE corner of the yard (zone-local +X points west here), angled at the spawn.
EventArea.Billboard = Vector3.new(-26, 0, -6)

local function fence(parent: Instance, frame: CFrame, a: Vector2, b: Vector2)
	local delta = b - a
	local length = delta.Magnitude
	local count = math.max(1, math.floor(length / 8))
	for i = 0, count do
		local p = a + delta * (i / count)
		Kit.post(
			parent,
			frame * CFrame.new(p.X, 0.2, p.Y),
			6,
			0.45,
			W.Steel,
			Enum.Material.Metal,
			{ Name = "FencePost" }
		)
	end
	local dir = Vector3.new(delta.X, 0, delta.Y).Unit
	for _, y in { 1.2, 3.4, 5.6 } do
		local mid = (a + b) / 2
		Kit.part(
			parent,
			Vector3.new(length, 0.18, 0.18),
			frame * CFrame.fromMatrix(Vector3.new(mid.X, y, mid.Y), dir, Vector3.new(0, 1, 0)),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "FenceRail", Decor = true }
		)
	end
	-- collision panel (chain-link is too fine to model; keep players out)
	local mid = (a + b) / 2
	Kit.part(
		parent,
		Vector3.new(length, 6, 0.3),
		frame * CFrame.fromMatrix(Vector3.new(mid.X, 3.2, mid.Y), dir, Vector3.new(0, 1, 0)),
		W.Steel,
		Enum.Material.SmoothPlastic,
		{ Name = "FenceCollider", Transparency = 1, Shadow = false, Query = false }
	)
end

function EventArea.build(parent: Instance): (Model, CFrame)
	local zone = Layout.Zones.EventArea
	local frame = Layout.frame(zone)
	local model = Kit.model(parent, zone.Id)
	local shell = Kit.folder(model, "Architecture")
	local halfW, depth = zone.Width / 2, zone.Depth
	local gate = zone.Entrances[1]

	Kit.box(
		shell,
		frame,
		Vector3.new(-halfW, 0, -depth),
		Vector3.new(halfW, 0.2, 0),
		W.Dirt,
		Enum.Material.Ground,
		{ Name = "Yard", Shadow = false }
	)
	-- concrete walkway from the gate to the tent
	Kit.box(
		shell,
		frame,
		Vector3.new(-3, 0.2, EventArea.TentFront),
		Vector3.new(3, 0.3, 0),
		W.Concrete,
		Enum.Material.Concrete,
		{
			Name = "Walkway",
			Shadow = false,
		}
	)

	-- fence with the gate gap on the front edge
	local fences = Kit.folder(shell, "Fence")
	fence(fences, frame, Vector2.new(-halfW, -0.5), Vector2.new(gate.Offset - gate.Width / 2 - 1, -0.5))
	fence(fences, frame, Vector2.new(gate.Offset + gate.Width / 2 + 1, -0.5), Vector2.new(halfW, -0.5))
	fence(fences, frame, Vector2.new(-halfW, -0.5), Vector2.new(-halfW, -depth))
	fence(fences, frame, Vector2.new(halfW, -0.5), Vector2.new(halfW, -depth))
	fence(fences, frame, Vector2.new(-halfW, -depth), Vector2.new(halfW, -depth))

	-- gate arch with the event banner
	local archH = 14
	for _, side in { -1, 1 } do
		local x = gate.Offset + side * (gate.Width / 2 + 1)
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.8, 0, -1.3),
			Vector3.new(x + 0.8, archH, 0.3),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "GatePost" }
		)
	end
	Kit.box(
		shell,
		frame,
		Vector3.new(gate.Offset - gate.Width / 2 - 2, archH - 1.6, -1.2),
		Vector3.new(gate.Offset + gate.Width / 2 + 2, archH, 0.2),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "GateBeam" }
	)
	local banner = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(gate.Offset, archH - 3.4, 0.25)),
		Vector2.new(gate.Width + 3, 2.6),
		"CURRENT OPERATION",
		{ Background = W.Charcoal, PixelsPerStud = 30 }
	)
	banner.Name = "EventBanner"

	-- event HQ tent (fabric gable on low walls, open front)
	local tent = Kit.folder(shell, "Tent")
	local tx0, tx1, tz0, tz1 = -16, 16, -52, EventArea.TentFront
	Kit.box(
		tent,
		frame,
		Vector3.new(tx0, 0.2, tz0),
		Vector3.new(tx1, 0.5, tz1),
		W.BrownDark,
		Enum.Material.WoodPlanks,
		{ Name = "TentFloor" }
	)
	for _, x in { tx0, tx1 - 0.4 } do
		Kit.box(
			tent,
			frame,
			Vector3.new(x, 0.5, tz0),
			Vector3.new(x + 0.4, 7, tz1),
			W.Olive,
			Enum.Material.Fabric,
			{ Name = "TentWall" }
		)
	end
	Kit.box(
		tent,
		frame,
		Vector3.new(tx0, 0.5, tz0),
		Vector3.new(tx1, 7, tz0 + 0.4),
		W.Olive,
		Enum.Material.Fabric,
		{ Name = "TentWall" }
	)
	Architecture.gableRoof(
		tent,
		frame,
		tx0 - 0.5,
		tx1 + 0.5,
		tz0 - 0.5,
		tz1 + 1.5,
		7,
		6,
		0.8,
		W.OliveDark,
		W.Olive,
		Enum.Material.Fabric,
		Enum.Material.Fabric
	)
	for _, x in { tx0 + 0.2, 0, tx1 - 0.2 } do
		Kit.post(tent, frame * CFrame.new(x, 0.5, tz1 + 1), 7, 0.4, W.Wood, Enum.Material.Wood, { Name = "TentPole" })
	end

	-- limited-unit display pad
	local pad = EventArea.DisplayPad
	Kit.box(
		shell,
		frame,
		Vector3.new(pad.X - 9, 0.2, pad.Z - 6),
		Vector3.new(pad.X + 9, 0.6, pad.Z + 6),
		W.Concrete,
		Enum.Material.Concrete,
		{
			Name = "DisplayPad",
		}
	)

	-- billboard facing the plaza (text set by applyEvent)
	local bb = EventArea.Billboard
	local bbFrame = frame * CFrame.new(bb.X, 0, bb.Z) * CFrame.Angles(0, math.rad(-55), 0)
	for _, x in { -8, 8 } do
		Kit.box(
			shell,
			bbFrame,
			Vector3.new(x - 0.5, 0, -0.5),
			Vector3.new(x + 0.5, 16, 0.5),
			W.SteelDark,
			Enum.Material.Metal,
			{ Name = "BillboardPost" }
		)
	end
	local board = Kit.part(
		shell,
		Vector3.new(22, 10, 0.6),
		bbFrame * CFrame.new(0, 11.2, 0) * CFrame.Angles(0, math.pi, 0),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{
			Name = "Billboard",
		}
	)
	board:SetAttribute("EventSurface", "Billboard")
	Kit.box(
		shell,
		bbFrame,
		Vector3.new(-11.5, 5.8, -0.6),
		Vector3.new(11.5, 6.2, 0.6),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "BillboardFrame" }
	)
	Kit.box(
		shell,
		bbFrame,
		Vector3.new(-11.5, 16.2, -0.6),
		Vector3.new(11.5, 16.6, 0.6),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "BillboardFrame" }
	)

	local sign = Kit.sign(
		shell,
		Kit.facingOut(frame, Vector3.new(gate.Offset - gate.Width / 2 - 6, 3.2, 0.4)),
		Vector2.new(7, 2.4),
		zone.DisplayName,
		{ Background = W.SignGreen, Stripe = W.HazardYellow, PixelsPerStud = 30 }
	)
	sign.Name = "ZoneName"

	Kit.model(model, "Dressing")
	return model, frame
end

return EventArea
