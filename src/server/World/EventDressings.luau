--!strict
-- Replaceable set dressing for the Event Area, keyed by Event.Dressing.
-- Each function fills the (already cleared) Dressing model. Add a new key
-- here for a new seasonal theme; the permanent compound is untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(script.Parent.Effects)
local Kit = require(script.Parent.Kit)
local Nature = require(script.Parent.Nature)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World

local EventDressings: { [string]: (Model, CFrame) -> () } = {}

local function crate(parent: Instance, cf: CFrame, size: Vector3, color: Color3, snowy: boolean)
	Kit.part(parent, size, cf * CFrame.new(0, size.Y / 2, 0), color, Enum.Material.WoodPlanks, { Name = "Crate" })
	if snowy then
		Kit.part(
			parent,
			Vector3.new(size.X * 0.95, 0.25, size.Z * 0.95),
			cf * CFrame.new(0, size.Y + 0.12, 0),
			W.Snow,
			Enum.Material.Snow,
			{
				Name = "SnowCap",
				Decor = true,
			}
		)
	end
end

EventDressings.Winter = function(dressing: Model, frame: CFrame)
	local rng = Random.new(1941)
	-- snow cover over the yard: overlapping low patches
	for i = 1, 14 do
		local x = rng:NextNumber(-34, 34)
		local z = rng:NextNumber(-52, -4)
		local cf = frame * CFrame.new(x, 0.24, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local patch = Kit.part(
			dressing,
			Vector3.new(rng:NextNumber(10, 18), 0.1, rng:NextNumber(8, 14)),
			cf,
			W.Snow,
			Enum.Material.Snow,
			{
				Name = "SnowPatch",
				Collide = false,
				Query = false,
			}
		)
		patch.CastShadow = false
		local _ = i
	end
	-- snow banks along the fence
	for _, spec in { { -34, -2, 6 }, { 34, -2, 6 }, { -20, -54, 10 }, { 22, -54, 10 } } do
		Kit.part(
			dressing,
			Vector3.new(spec[3], 1.2, 3),
			frame * CFrame.new(spec[1], 0.6, spec[2] - (if spec[2] < -40 then 0 else 2)),
			W.Snow,
			Enum.Material.Snow,
			{
				Name = "SnowBank",
			}
		)
	end
	-- snowy pines
	for _, pos in
		{ Vector3.new(-30, 0, -20), Vector3.new(-26, 0, -30), Vector3.new(30, 0, -44), Vector3.new(-32, 0, -46) }
	do
		local tree = Nature.pine(dressing, frame * CFrame.new(pos), rng:NextNumber(14, 18), rng)
		for _, tier in tree:GetChildren() do
			if tier:IsA("BasePart") and tier.Name == "Tier" then
				local cap = tier:Clone()
				cap.Name = "SnowTier"
				cap.Size = Vector3.new(tier.Size.X * 0.3, tier.Size.Y * 0.8, tier.Size.Z * 0.8)
				cap.CFrame = tier.CFrame * CFrame.new(tier.Size.X * 0.36, 0, 0)
				cap.Color = W.Snow
				cap.Material = Enum.Material.Snow
				cap.Parent = tree
			end
		end
	end
	-- frosted supply crates
	for i, spec in { { -18, -12, 0 }, { -15.5, -12.5, 0.3 }, { -17, -15, -0.2 }, { 8, -30, 0.1 } } do
		crate(
			dressing,
			frame * CFrame.new(spec[1], 0.2, spec[2]) * CFrame.Angles(0, spec[3], 0),
			Vector3.new(3, 2.2, 2.4),
			W.OliveDark,
			true
		)
		local _ = i
	end
	-- whitewashed tent sign
	Kit.sign(dressing, Kit.facingOut(frame, Vector3.new(-9, 9.8, -34.8)), Vector2.new(8, 1.8), "WINTER WARFARE CELL", {
		Background = Color3.fromRGB(196, 206, 212),
		TextColor = W.Charcoal,
		PixelsPerStud = 40,
		Depth = 0.2,
		MaxDistance = 120,
	})
	-- brazier for warmth (fire effect added by the ambient pass)
	local brazier = Kit.cylinder(
		dressing,
		2.6,
		2,
		frame * CFrame.new(-6, 1.5, -26) * CFrame.Angles(0, 0, math.pi / 2),
		W.Charcoal,
		Enum.Material.CorrodedMetal,
		{
			Name = "Brazier",
		}
	)
	Kit.anchor(brazier, "Fire", "FireBarrel")
	local flameBase = Kit.part(
		dressing,
		Vector3.new(1.4, 0.4, 1.4),
		frame * CFrame.new(-6, 3, -26),
		W.Charcoal,
		nil,
		{ Name = "FlameBase", Transparency = 1, Decor = true }
	)
	Effects.fire(flameBase, 2.4)
	-- tyre tracks through the snow toward the display pad
	for i = 0, 5 do
		for _, dx in { -2.6, 2.6 } do
			Kit.part(
				dressing,
				Vector3.new(1.1, 0.05, 5.2),
				frame * CFrame.new(10 + dx + i * 0.5, 0.32, -6 - i * 4.6) * CFrame.Angles(0, math.rad(-8), 0),
				W.Dirt,
				Enum.Material.Ground,
				{
					Name = "Track",
					Decor = true,
				}
			)
		end
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
