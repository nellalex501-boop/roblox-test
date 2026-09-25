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
-- NE corner of the yard (zone-local +X points west here), angled at the
-- spawn; set back so posts and board stay inside the fence.
EventArea.Billboard = Vector3.new(-24, 0, -12)

-- The event HQ tent (zone-local): fabric gable on low walls, open front.
EventArea.Tent = { X0 = -16, X1 = 16, Z0 = -52, Z1 = EventArea.TentFront, EaveY = 7, Rise = 6, Overhang = 0.8 }
EventArea.FenceInset = 0.5 -- fence line inside the zone edge

-- Chain-link yard fence along an open polyline (zone-local XZ): one round
-- post at every corner and every ~8 studs between (never two at a
-- corner), a see-through mesh panel, top rail and bottom tension wire per
-- straight run, and an invisible collider. `bareStart` leaves out the
-- first post (the run starts against a gate post).
local function yardFence(parent: Instance, frame: CFrame, points: { Vector2 }, bareStart: boolean?)
	local height = 6
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local delta = b - a
		local length = delta.Magnitude
		local count = math.max(1, math.ceil(length / 8))
		local first = if i == 1 and bareStart then 1 elseif i == 1 then 0 else 1
		for k = first, count do
			local p = a + delta * (k / count)
			Kit.post(
				parent,
				frame * CFrame.new(p.X, 0.2, p.Y),
				height + 0.2,
				0.4,
				W.Steel,
				Enum.Material.Metal,
				{ Name = "FencePost" }
			)
		end
		local mid = (a + b) / 2
		local dir = Vector3.new(delta.X, 0, delta.Y).Unit
		local along = frame * CFrame.fromMatrix(Vector3.new(mid.X, 0, mid.Y), dir, Vector3.new(0, 1, 0))
		local mesh = Kit.part(
			parent,
			Vector3.new(length, height - 0.5, 0.06),
			along * CFrame.new(0, 0.2 + (height - 0.5) / 2 + 0.15, 0),
			Color3.fromRGB(150, 152, 146),
			Enum.Material.Fabric,
			{ Name = "ChainLink", Transparency = 0.55, Collide = false, Query = false, Shadow = false }
		)
		mesh:SetAttribute("ChainLink", true)
		Kit.cylinder(parent, length, 0.16, along * CFrame.new(0, height + 0.05, 0), W.Steel, Enum.Material.Metal, {
			Name = "TopRail",
			Decor = true,
		})
		Kit.cylinder(parent, length, 0.06, along * CFrame.new(0, 0.45, 0.06), W.SteelDark, Enum.Material.Metal, {
			Name = "TensionWire",
			Decor = true,
		})
		Kit.part(
			parent,
			Vector3.new(length, height, 0.3),
			along * CFrame.new(0, 0.2 + height / 2, 0),
			W.Steel,
			Enum.Material.SmoothPlastic,
			{ Name = "FenceCollider", Transparency = 1, Shadow = false, Query = false }
		)
	end
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

	-- chain-link fence from one gate post round the back to the other
	local fences = Kit.folder(shell, "Fence")
	local inset = EventArea.FenceInset
	local jamb = gate.Width / 2 + 1.8
	yardFence(fences, frame, {
		Vector2.new(gate.Offset - jamb, -inset),
		Vector2.new(-halfW + inset, -inset),
		Vector2.new(-halfW + inset, -depth + inset),
		Vector2.new(halfW - inset, -depth + inset),
		Vector2.new(halfW - inset, -inset),
		Vector2.new(gate.Offset + jamb, -inset),
	}, true)

	-- gate arch with the event banner
	local archH = 14
	for _, side in { -1, 1 } do
		local x = gate.Offset + side * (gate.Width / 2 + 1)
		-- the posts rise 0.4 above the beam (no shared top face)
		Kit.box(
			shell,
			frame,
			Vector3.new(x - 0.8, 0, -1.3),
			Vector3.new(x + 0.8, archH + 0.4, 0.3),
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
	local T = EventArea.Tent
	local tx0, tx1, tz0, tz1 = T.X0, T.X1, T.Z0, T.Z1
	Kit.box(
		tent,
		frame,
		Vector3.new(tx0, 0.2, tz0),
		Vector3.new(tx1, 0.5, tz1),
		W.BrownDark,
		Enum.Material.WoodPlanks,
		{ Name = "TentFloor" }
	)
	-- side walls butt against the back wall (no overlapping corners)
	for _, x in { tx0, tx1 - 0.4 } do
		Kit.box(
			tent,
			frame,
			Vector3.new(x, 0.5, tz0 + 0.4),
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
		T.EaveY,
		T.Rise,
		T.Overhang,
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
