--!strict
-- Low-poly vegetation and terrain shapes: pyramid-tier pines, round
-- broadleaf trees, hedges, irregular hills and snow drifts. All decorative
-- parts skip collisions except trunks.

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

-- One pyramid face half as a thin right-triangle plate (a WedgePart): the
-- right angle at `m` (base-edge midpoint), one leg up the face to the apex
-- `a`, the other along the base edge by `half` in direction `t`. The plate
-- lies on the outside of the face plane (its inner side on the plane), so
-- the edge strips of opposite faces only meet at the apex, never overlap.
local function facePlate(
	parent: Instance,
	m: Vector3,
	apex: Vector3,
	t: Vector3,
	half: number,
	outward: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	opts: Kit.Opts
): WedgePart
	local slant = apex - m
	local s = slant.Magnitude
	local eY = slant / s
	local eZ = -t
	local eX = eY:Cross(eZ)
	local center = m + eY * (s / 2) + t * (half / 2) + outward * (thickness / 2)
	return Kit.wedge(
		parent,
		Vector3.new(thickness, s, half),
		CFrame.fromMatrix(center, eX, eY, eZ),
		color,
		material,
		opts
	)
end

-- Square pyramid (four faces, eight plates) standing on `base` (centre of
-- its base, turned by the frame's yaw): apothem `a`, height `h`. Returns
-- the face normal's vertical component (for snow caps).
function Nature.pyramid(
	parent: Instance,
	base: CFrame,
	a: number,
	h: number,
	color: Color3,
	material: Enum.Material,
	opts: Kit.Opts,
	thickness: number?
): number
	local apex = base.Position + base.UpVector * h
	local slant = math.sqrt(a * a + h * h)
	for k = 0, 3 do
		local yaw = k * math.pi / 2
		local dir = (base * CFrame.Angles(0, yaw, 0)).LookVector
		local up = base.UpVector
		local t = up:Cross(dir).Unit
		local m = base.Position + dir * a
		local outward = (dir * h + up * a) / slant
		for _, side in { 1, -1 } do
			facePlate(parent, m, apex, t * side, a, outward, thickness or 0.3, color, material, opts)
		end
	end
	return a / slant
end

-- Conifer: trunk + three pyramid tiers, each turned 45 degrees from the one
-- below, with a slight lean. `snowy` lays a snow cap (same slope, 0.08
-- proud of the needles) over the upper half of every tier. Only the
-- trunk and the widest tier cast shadows.
function Nature.pine(parent: Instance, base: CFrame, height: number, rng: Random, snowy: boolean?): Model
	local model = Kit.model(parent, "Pine")
	local lean =
		CFrame.Angles(rng:NextNumber(-0.035, 0.035), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.035, 0.035))
	local root = base * lean
	Kit.post(
		model,
		root,
		height * 0.4,
		math.max(0.7, height * 0.05),
		W.BrownDark,
		Enum.Material.Wood,
		{ Name = "Trunk", Shadow = true }
	)
	local tone = rng:NextNumber(-0.03, 0.03)
	for i = 0, 2 do
		local bottom = height * (0.16 + i * 0.22)
		local top = height * (0.62 + i * 0.19)
		local tierH = top - bottom
		local a = height * (0.26 - i * 0.06) * rng:NextNumber(0.92, 1.08)
		local tierBase = root * CFrame.new(0, bottom, 0) * CFrame.Angles(0, i * math.pi / 4, 0)
		local color = shade(if i % 2 == 0 then W.FoliageDark else W.Foliage, tone)
		local ny = Nature.pyramid(
			model,
			tierBase,
			a,
			tierH,
			color,
			Enum.Material.Grass,
			{ Name = "Tier", Collide = false, Query = false, Shadow = i == 0 }
		)
		if snowy then
			-- the cap's inner side sits 0.06 outside the needles' outer side
			-- (0.3 plates): apex raised by 0.36 / ny, base halfway up the tier
			local lift = 0.36 / ny
			local capH = tierH * 0.5 + lift
			Nature.pyramid(
				model,
				tierBase * CFrame.new(0, tierH * 0.5, 0),
				capH * a / tierH,
				capH,
				W.Snow,
				Enum.Material.Snow,
				{ Name = "SnowCap", Decor = true },
				0.2
			)
		end
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

-- Irregular hill: a main sunken sphere plus shoulders strung along a
-- random ridge line, each a different size, height and green, with a few
-- rock outcrops on the slopes. Reads as a ridge, not a dome.
function Nature.ridge(parent: Instance, x: number, z: number, radius: number, height: number, rng: Random): Model
	local model = Kit.model(parent, "Ridge")
	local heading = rng:NextNumber(0, math.pi * 2)
	local along = Vector3.new(math.cos(heading), 0, math.sin(heading))
	local across = Vector3.new(-along.Z, 0, along.X)
	local greens = { W.GrassDark, W.Grass, Color3.fromRGB(96, 110, 70), Color3.fromRGB(84, 98, 64) }
	Nature.hill(model, x, z, radius, height, greens[1])
	for i = 1, 4 do
		local sideways = rng:NextNumber(-0.25, 0.25) * radius
		local offset = along * ((if i % 2 == 0 then 1 else -1) * rng:NextNumber(0.45, 0.95) * radius)
			+ across * sideways
		local r = radius * rng:NextNumber(0.45, 0.75)
		local h = height * rng:NextNumber(0.45, 0.85)
		Nature.hill(model, x + offset.X, z + offset.Z, r, h, greens[1 + (i % #greens)])
	end
	-- rock outcrops, half buried on the upper slopes
	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = radius * rng:NextNumber(0.1, 0.35)
		local px, pz = x + math.cos(angle) * dist, z + math.sin(angle) * dist
		-- height of the main cap at that distance
		local centerY = height - radius
		local surface = centerY + math.sqrt(math.max(radius * radius - dist * dist, 0))
		local size = Vector3.new(rng:NextNumber(5, 11), rng:NextNumber(3, 6), rng:NextNumber(5, 9))
		Kit.part(
			model,
			size,
			CFrame.new(px, surface, pz)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Color3.fromRGB(118, 116, 108),
			Enum.Material.Slate,
			{ Name = "Rock", Collide = false, Query = false, Shadow = false }
		)
	end
	return model
end

-- Soft snow drift: a large sphere sunk so only a low mound of `height`
-- shows above `y`.
function Nature.drift(parent: Instance, position: Vector3, radius: number, height: number): Part
	local part = Kit.ball(
		parent,
		radius * 2,
		CFrame.new(position.X, position.Y + height - radius, position.Z),
		W.Snow,
		Enum.Material.Snow,
		{ Name = "Drift", Collide = false, Query = false }
	)
	part.CastShadow = false
	return part
end

type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

local function inside(rect: Rect, x: number, z: number): boolean
	return x >= rect.MinX and x <= rect.MaxX and z >= rect.MinZ and z <= rect.MaxZ
end

-- Forest band outside the perimeter fence, grown in clusters (a few trees
-- around each seed point, varied heights, mostly pines), with gaps for
-- keep-out areas.
function Nature.forest(parent: Instance, inner: Rect, band: number, count: number, keepOut: { Rect }, rng: Random)
	local folder = Kit.folder(parent, "Forest")
	local fence = { MinX = inner.MinX - 6, MaxX = inner.MaxX + 6, MinZ = inner.MinZ - 6, MaxZ = inner.MaxZ + 6 }
	local placed: { Vector3 } = {}
	local function free(x: number, z: number): boolean
		if inside(fence, x, z) then
			return false
		end
		for _, rect in keepOut do
			if inside(rect, x, z) then
				return false
			end
		end
		for _, p in placed do
			if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < 36 then
				return false
			end
		end
		return true
	end
	local attempts = 0
	while #placed < count and attempts < count * 20 do
		attempts += 1
		local cx = rng:NextNumber(inner.MinX - band, inner.MaxX + band)
		local cz = rng:NextNumber(inner.MinZ - band, inner.MaxZ + band)
		if free(cx, cz) then
			local size = rng:NextInteger(4, 9)
			for _ = 1, size * 3 do
				if #placed >= count then
					break
				end
				local angle = rng:NextNumber(0, math.pi * 2)
				local dist = rng:NextNumber(0, 16)
				local x, z = cx + math.cos(angle) * dist, cz + math.sin(angle) * dist
				if free(x, z) then
					table.insert(placed, Vector3.new(x, 0, z))
					local base = CFrame.new(x, 0, z)
					if rng:NextNumber() < 0.75 then
						Nature.pine(folder, base, rng:NextNumber(14, 30), rng)
					else
						Nature.leafy(folder, base, rng:NextNumber(15, 24), rng)
					end
					size -= 1
					if size <= 0 then
						break
					end
				end
			end
		end
	end
	return folder
end

return Nature
