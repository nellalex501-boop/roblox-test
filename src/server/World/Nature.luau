--!strict
-- Low-poly vegetation and terrain shapes: stepped pines, round broadleaf
-- trees, hedges and grassy hills. All decorative parts skip collisions
-- except trunks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Nature = {}

local function shade(color: Color3, amount: number): Color3
	return Color3.new(
		math.clamp(color.R + amount, 0, 1),
		math.clamp(color.G + amount, 0, 1),
		math.clamp(color.B + amount, 0, 1)
	)
end

-- Stepped conifer: trunk + 3 stacked tiers.
function Nature.pine(parent: Instance, base: CFrame, height: number, rng: Random): Model
	local model = Kit.model(parent, "Pine")
	local trunkH = height * 0.3
	Kit.post(
		model,
		base,
		trunkH,
		math.max(0.7, height * 0.05),
		W.BrownDark,
		Enum.Material.Wood,
		{ Name = "Trunk", Shadow = true }
	)
	local tone = rng:NextNumber(-0.03, 0.03)
	for i = 0, 2 do
		local tierH = height * 0.3
		local bottom = height * (0.2 + i * 0.24)
		local diameter = height * (0.5 - i * 0.14)
		Kit.post(
			model,
			base * CFrame.new(0, bottom, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			tierH,
			diameter,
			shade(if i % 2 == 0 then W.FoliageDark else W.Foliage, tone),
			Enum.Material.Grass,
			{ Name = "Tier", Collide = false, Query = false }
		)
	end
	return model
end

-- Broadleaf: trunk + clustered foliage balls.
function Nature.leafy(parent: Instance, base: CFrame, height: number, rng: Random): Model
	local model = Kit.model(parent, "Tree")
	Kit.post(model, base, height * 0.5, math.max(0.7, height * 0.06), W.Brown, Enum.Material.Wood, { Name = "Trunk" })
	local tone = rng:NextNumber(-0.04, 0.03)
	local crown = height * 0.55
	Kit.ball(model, crown, base * CFrame.new(0, height * 0.66, 0), shade(W.Foliage, tone), Enum.Material.Grass, {
		Name = "Crown",
		Collide = false,
		Query = false,
	})
	for i = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		Kit.ball(
			model,
			crown * 0.7,
			base * CFrame.new(math.cos(a) * crown * 0.32, height * (0.56 + i * 0.08), math.sin(a) * crown * 0.32),
			shade(W.FoliageDark, tone + 0.02 * i),
			Enum.Material.Grass,
			{ Name = "Crown", Collide = false, Query = false, Shadow = false }
		)
	end
	return model
end

-- Planter box with a tree (courtyards, plaza corners).
function Nature.planter(parent: Instance, position: Vector3, rng: Random, size: number?): Model
	local model = Kit.model(parent, "Planter")
	local s = size or 5
	local base = CFrame.new(position)
	Kit.box(
		model,
		base,
		Vector3.new(-s / 2, 0, -s / 2),
		Vector3.new(s / 2, 1.4, s / 2),
		W.Concrete,
		Enum.Material.Concrete,
		{ Name = "Box" }
	)
	Kit.box(
		model,
		base,
		Vector3.new(-s / 2 + 0.4, 1.2, -s / 2 + 0.4),
		Vector3.new(s / 2 - 0.4, 1.35, s / 2 - 0.4),
		W.Dirt,
		Enum.Material.Ground,
		{
			Name = "Soil",
			Decor = true,
		}
	)
	Nature.leafy(model, base * CFrame.new(0, 1.3, 0), rng:NextNumber(12, 15), rng)
	return model
end

-- Trimmed hedge along a line.
function Nature.hedge(parent: Instance, a: Vector3, b: Vector3, height: number, width: number): Part
	local mid = (a + b) / 2
	local delta = b - a
	local dir = Vector3.new(delta.X, 0, delta.Z).Unit
	return Kit.part(
		parent,
		Vector3.new(delta.Magnitude, height, width),
		CFrame.fromMatrix(mid + Vector3.new(0, height / 2, 0), dir, Vector3.new(0, 1, 0)),
		W.FoliageDark,
		Enum.Material.Grass,
		{ Name = "Hedge" }
	)
end

-- Grassy hill: a sunken sphere cap.
function Nature.hill(parent: Instance, x: number, z: number, radius: number, height: number, color: Color3?): Part
	local part = Kit.ball(
		parent,
		radius * 2,
		CFrame.new(x, height - radius, z),
		color or W.GrassDark,
		Enum.Material.Grass,
		{ Name = "Hill" }
	)
	part.CastShadow = false
	return part
end

type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

local function inside(rect: Rect, x: number, z: number): boolean
	return x >= rect.MinX and x <= rect.MaxX and z >= rect.MinZ and z <= rect.MaxZ
end

-- Forest band outside the perimeter fence, with gaps for keep-out areas.
function Nature.forest(parent: Instance, inner: Rect, band: number, count: number, keepOut: { Rect }, rng: Random)
	local folder = Kit.folder(parent, "Forest")
	local placed = 0
	local attempts = 0
	while placed < count and attempts < count * 20 do
		attempts += 1
		local x = rng:NextNumber(inner.MinX - band, inner.MaxX + band)
		local z = rng:NextNumber(inner.MinZ - band, inner.MaxZ + band)
		local ok = not inside(
			{ MinX = inner.MinX - 6, MaxX = inner.MaxX + 6, MinZ = inner.MinZ - 6, MaxZ = inner.MaxZ + 6 },
			x,
			z
		)
		if ok then
			for _, rect in keepOut do
				if inside(rect, x, z) then
					ok = false
					break
				end
			end
		end
		if ok then
			local base = CFrame.new(x, 0, z)
			if rng:NextNumber() < 0.72 then
				Nature.pine(folder, base, rng:NextNumber(18, 30), rng)
			else
				Nature.leafy(folder, base, rng:NextNumber(16, 24), rng)
			end
			placed += 1
		end
	end
	return folder
end

return Nature
