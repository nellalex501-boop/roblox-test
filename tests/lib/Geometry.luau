--!nocheck
-- Exact part geometry for the visual checks:
--   * planar faces of blocks, wedges and cylinder caps,
--   * ray casts against oriented blocks, wedges, cylinders and balls through
--     a uniform grid (fast enough for thousands of rays),
--   * a coplanar-face detector: two parts whose faces point the same way,
--     lie within a few hundredths of a stud of each other and overlap will
--     z-fight (flicker) in Roblox.

local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local Enum = roblox.Enum

local Geometry = {}

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

function Geometry.shape(part): string
	if part:IsA("WedgePart") then
		return "Wedge"
	end
	if part:IsA("Part") then
		local shape = part.Shape
		if shape == Enum.PartType.Cylinder then
			return "Cylinder"
		elseif shape == Enum.PartType.Ball then
			return "Ball"
		elseif shape == Enum.PartType.Wedge then
			return "Wedge"
		elseif shape == Enum.PartType.Block then
			return "Block"
		end
	end
	return "Other"
end

--------------------------------------------------------------------------
-- Faces
--------------------------------------------------------------------------

local CAP_SIDES = 16

-- Planar faces: { part, normal, d (= normal·point), points (world, convex) }
function Geometry.faces(part)
	local shape = Geometry.shape(part)
	local cf, h = part.CFrame, part.Size / 2
	local faces = {}
	local function add(localNormal, localPoints, name)
		local n = cf:VectorToWorldSpace(localNormal.Unit)
		local pts = table.create(#localPoints)
		for i, p in localPoints do
			pts[i] = cf:PointToWorldSpace(p)
		end
		table.insert(faces, { part = part, normal = n, d = n:Dot(pts[1]), points = pts, name = name })
	end
	local x, y, z = h.X, h.Y, h.Z
	if shape == "Block" then
		add(V(1, 0, 0), { V(x, -y, -z), V(x, y, -z), V(x, y, z), V(x, -y, z) }, "Right")
		add(V(-1, 0, 0), { V(-x, -y, -z), V(-x, -y, z), V(-x, y, z), V(-x, y, -z) }, "Left")
		add(V(0, 1, 0), { V(-x, y, -z), V(-x, y, z), V(x, y, z), V(x, y, -z) }, "Top")
		add(V(0, -1, 0), { V(-x, -y, -z), V(x, -y, -z), V(x, -y, z), V(-x, -y, z) }, "Bottom")
		add(V(0, 0, 1), { V(-x, -y, z), V(x, -y, z), V(x, y, z), V(-x, y, z) }, "Back")
		add(V(0, 0, -1), { V(-x, -y, -z), V(-x, y, -z), V(x, y, -z), V(x, -y, -z) }, "Front")
	elseif shape == "Wedge" then
		-- full bottom and back (+Z); the slope falls toward the front (-Z)
		add(V(0, -1, 0), { V(-x, -y, -z), V(x, -y, -z), V(x, -y, z), V(-x, -y, z) }, "Bottom")
		add(V(0, 0, 1), { V(-x, -y, z), V(x, -y, z), V(x, y, z), V(-x, y, z) }, "Back")
		add(V(1, 0, 0), { V(x, -y, -z), V(x, y, z), V(x, -y, z) }, "Right")
		add(V(-1, 0, 0), { V(-x, -y, -z), V(-x, -y, z), V(-x, y, z) }, "Left")
		add(V(0, z, -y), { V(-x, -y, -z), V(-x, y, z), V(x, y, z), V(x, -y, -z) }, "Slope")
	elseif shape == "Cylinder" then
		local r = math.min(y, z)
		for _, side in { 1, -1 } do
			local pts = {}
			for i = 0, CAP_SIDES - 1 do
				local a = i / CAP_SIDES * math.pi * 2
				table.insert(pts, V(side * x, math.cos(a) * r, math.sin(a) * r))
			end
			add(V(side, 0, 0), pts, if side > 0 then "Right" else "Left")
		end
	end
	return faces
end

--------------------------------------------------------------------------
-- 2D convex polygon helpers
--------------------------------------------------------------------------

local function signedArea(poly)
	local a = 0
	for i = 1, #poly do
		local p, q = poly[i], poly[i % #poly + 1]
		a += p[1] * q[2] - q[1] * p[2]
	end
	return a / 2
end

local function clip(subject, clipper)
	local output = subject
	local n = #clipper
	for i = 1, n do
		if #output == 0 then
			break
		end
		local a, b = clipper[i], clipper[i % n + 1]
		local ex, ey = b[1] - a[1], b[2] - a[2]
		local function inside(p)
			return ex * (p[2] - a[2]) - ey * (p[1] - a[1]) >= -1e-9
		end
		local function cross(p, q)
			local dx, dy = q[1] - p[1], q[2] - p[2]
			local denom = dx * ey - dy * ex
			if math.abs(denom) < 1e-12 then
				return q
			end
			local t = ((a[1] - p[1]) * ey - (a[2] - p[2]) * ex) / denom
			return { p[1] + t * dx, p[2] + t * dy }
		end
		local input = output
		output = {}
		local prev = input[#input]
		for _, cur in input do
			if inside(cur) then
				if not inside(prev) then
					table.insert(output, cross(prev, cur))
				end
				table.insert(output, cur)
			elseif inside(prev) then
				table.insert(output, cross(prev, cur))
			end
			prev = cur
		end
	end
	return output
end

function Geometry.overlapArea(polyA, polyB): number
	local inter = clip(polyA, polyB)
	if #inter < 3 then
		return 0
	end
	return math.abs(signedArea(inter))
end

--------------------------------------------------------------------------
-- Coplanar faces (z-fighting)
--------------------------------------------------------------------------

-- (keyed by name: Lune enum items are not stable table keys)
local TEXTURELESS = { SmoothPlastic = true, Neon = true, Glass = true, ForceField = true }

-- Two coplanar faces render identically (no visible flicker) only when
-- both are untextured, opaque and the same colour.
local function sameLook(a, b): boolean
	return TEXTURELESS[a.Material.Name] == true
		and a.Material.Name == b.Material.Name
		and a.Transparency == 0
		and b.Transparency == 0
		and a.Color == b.Color
end

-- options: tolerance (studs, default 0.045), minArea (default 0.01),
-- include(part) -> boolean, grid (Geometry.index of opaque parts: skips
-- overlaps whose front is buried in a third part, e.g. bottoms resting on
-- the ground). Returns findings sorted by area (largest first):
-- { a, b, faceA, faceB, gap, area, sameLook, point }.
function Geometry.coplanar(root, options)
	options = options or {}
	local tol = options.tolerance or 0.045
	local minArea = options.minArea or 0.01
	local include = options.include
	local grid = options.grid
	local buckets = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and (include == nil or include(part)) then
			for _, face in Geometry.faces(part) do
				local n = face.normal
				local key = ("%d,%d,%d"):format(math.round(n.X * 60), math.round(n.Y * 60), math.round(n.Z * 60))
				local bucket = buckets[key]
				if not bucket then
					bucket = { normal = n, faces = {} }
					buckets[key] = bucket
				end
				table.insert(bucket.faces, face)
			end
		end
	end
	local findings = {}
	for _, bucket in buckets do
		local n = bucket.normal
		local helper = if math.abs(n.Y) < 0.9 then V(0, 1, 0) else V(1, 0, 0)
		local u = n:Cross(helper).Unit
		local v = n:Cross(u).Unit
		local faces = bucket.faces
		for _, face in faces do
			local poly = table.create(#face.points)
			local minU, maxU, minV, maxV = math.huge, -math.huge, math.huge, -math.huge
			for i, p in face.points do
				local pu, pv = p:Dot(u), p:Dot(v)
				poly[i] = { pu, pv }
				minU, maxU = math.min(minU, pu), math.max(maxU, pu)
				minV, maxV = math.min(minV, pv), math.max(maxV, pv)
			end
			if signedArea(poly) < 0 then
				local reversed = table.create(#poly)
				for i = #poly, 1, -1 do
					table.insert(reversed, poly[i])
				end
				poly = reversed
			end
			face.poly = poly
			face.box = { minU, maxU, minV, maxV }
			face.d = n:Dot(face.points[1])
		end
		table.sort(faces, function(a, b)
			return a.d < b.d
		end)
		for i = 1, #faces do
			local fa = faces[i]
			local j = i + 1
			while j <= #faces and faces[j].d - fa.d < tol do
				local fb = faces[j]
				if fb.part ~= fa.part and fa.normal:Dot(fb.normal) > 0.9995 then
					local ba, bb = fa.box, fb.box
					if ba[1] < bb[2] and bb[1] < ba[2] and ba[3] < bb[4] and bb[3] < ba[4] then
						local inter = clip(fa.poly, fb.poly)
						local area = if #inter >= 3 then math.abs(signedArea(inter)) else 0
						if area >= minArea then
							-- sample the overlap just in front of the outer face
							local cu, cv = 0, 0
							for _, q in inter do
								cu += q[1]
								cv += q[2]
							end
							cu, cv = cu / #inter, cv / #inter
							local front = fb.d + 0.03
							local samples = { u * cu + v * cv + n * front }
							local stride = math.max(1, #inter // 4)
							for k = 1, #inter, stride do
								local q = inter[k]
								local su, sv = cu + (q[1] - cu) * 0.8, cv + (q[2] - cv) * 0.8
								table.insert(samples, u * su + v * sv + n * front)
							end
							local hidden = false
							if grid then
								hidden = true
								for _, point in samples do
									if
										not Geometry.inside(grid, point, function(part)
											return part == fa.part or part == fb.part or part.Transparency > 0.1
										end)
									then
										hidden = false
										break
									end
								end
							end
							if not hidden then
								table.insert(findings, {
									a = fa.part,
									b = fb.part,
									faceA = fa.name,
									faceB = fb.name,
									gap = fb.d - fa.d,
									area = area,
									sameLook = sameLook(fa.part, fb.part),
									point = samples[1],
								})
							end
						end
					end
				end
				j += 1
			end
		end
	end
	table.sort(findings, function(a, b)
		return a.area > b.area
	end)
	return findings
end

--------------------------------------------------------------------------
-- Ray casts
--------------------------------------------------------------------------

-- Convex solids as half-spaces in part space: { normal, d } with n·p <= d.
local function planesOf(part, shape)
	local h = part.Size / 2
	local planes = {
		{ V(1, 0, 0), h.X },
		{ V(-1, 0, 0), h.X },
		{ V(0, 1, 0), h.Y },
		{ V(0, -1, 0), h.Y },
		{ V(0, 0, 1), h.Z },
		{ V(0, 0, -1), h.Z },
	}
	if shape == "Wedge" then
		-- the slope plane replaces the top and front faces
		local n = V(0, h.Z, -h.Y).Unit
		planes = {
			{ V(1, 0, 0), h.X },
			{ V(-1, 0, 0), h.X },
			{ V(0, -1, 0), h.Y },
			{ V(0, 0, 1), h.Z },
			{ n, n:Dot(V(0, h.Y, h.Z)) },
		}
	end
	return planes
end

-- Entry distance of the ray o + t*d (part space, 0 <= t <= maxT) into the
-- part's solid, or nil.
local function hitLocal(part, shape, o, d, maxT)
	if shape == "Ball" then
		local r = math.min(part.Size.X, part.Size.Y, part.Size.Z) / 2
		local b = o:Dot(d)
		local c = o:Dot(o) - r * r
		local a = d:Dot(d)
		local disc = b * b - a * c
		if disc < 0 then
			return nil
		end
		local t = (-b - math.sqrt(disc)) / a
		if t < 0 then
			t = (-b + math.sqrt(disc)) / a
			if t < 0 then
				return nil
			end
			return 0
		end
		return if t <= maxT then t else nil
	end
	local tmin, tmax = 0, maxT
	if shape == "Cylinder" then
		local h = part.Size / 2
		local r = math.min(h.Y, h.Z)
		-- slab along the axis (local X)
		if math.abs(d.X) < 1e-12 then
			if math.abs(o.X) > h.X then
				return nil
			end
		else
			local t1, t2 = (-h.X - o.X) / d.X, (h.X - o.X) / d.X
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
		-- infinite cylinder around X
		local a = d.Y * d.Y + d.Z * d.Z
		local b = o.Y * d.Y + o.Z * d.Z
		local c = o.Y * o.Y + o.Z * o.Z - r * r
		if a < 1e-12 then
			if c > 0 then
				return nil
			end
		else
			local disc = b * b - a * c
			if disc < 0 then
				return nil
			end
			local s = math.sqrt(disc)
			local t1, t2 = (-b - s) / a, (-b + s) / a
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
		return tmin
	end
	for _, plane in planesOf(part, shape) do
		local n, dist = plane[1], plane[2]
		local denom = n:Dot(d)
		local num = dist - n:Dot(o)
		if math.abs(denom) < 1e-12 then
			if num < 0 then
				return nil
			end
		elseif denom < 0 then
			tmin = math.max(tmin, num / denom)
		else
			tmax = math.min(tmax, num / denom)
		end
		if tmin > tmax then
			return nil
		end
	end
	return tmin
end

local function insideLocal(part, shape, p): boolean
	local h = part.Size / 2
	if shape == "Ball" then
		return p.Magnitude <= math.min(h.X, h.Y, h.Z)
	elseif shape == "Cylinder" then
		local r = math.min(h.Y, h.Z)
		return math.abs(p.X) <= h.X and p.Y * p.Y + p.Z * p.Z <= r * r
	end
	for _, plane in planesOf(part, shape) do
		if plane[1]:Dot(p) > plane[2] then
			return false
		end
	end
	return true
end

-- Whether a world point lies inside any indexed part (ignore(part) skips).
function Geometry.inside(grid, point: Vector3, ignore): boolean
	local cell = grid.cell
	local key = math.floor(point.X / cell) .. "," .. math.floor(point.Y / cell) .. "," .. math.floor(point.Z / cell)
	local list = grid.cells[key]
	if not list then
		return false
	end
	for _, entry in list do
		local part = entry.part
		if not (ignore and ignore(part)) and insideLocal(part, entry.shape, part.CFrame:PointToObjectSpace(point)) then
			return true
		end
	end
	return false
end

-- Uniform grid over part bounding boxes.
function Geometry.index(root, include, cellSize)
	local cell = cellSize or 8
	local grid = { cell = cell, cells = {}, parts = {} }
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and (include == nil or include(part)) then
			local shape = Geometry.shape(part)
			if shape ~= "Other" then
				local cf, h = part.CFrame, part.Size / 2
				local ext = V(
					math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
					math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
					math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
				)
				local lo, hi = cf.Position - ext, cf.Position + ext
				local entry = { part = part, shape = shape }
				table.insert(grid.parts, entry)
				for gx = math.floor(lo.X / cell), math.floor(hi.X / cell) do
					for gy = math.floor(lo.Y / cell), math.floor(hi.Y / cell) do
						for gz = math.floor(lo.Z / cell), math.floor(hi.Z / cell) do
							local key = gx .. "," .. gy .. "," .. gz
							local list = grid.cells[key]
							if not list then
								list = {}
								grid.cells[key] = list
							end
							table.insert(list, entry)
						end
					end
				end
			end
		end
	end
	return grid
end

-- First hit along origin + t*direction (direction need not be unit;
-- t in [0, 1]). ignore(part) -> true skips a part. Returns part, t.
function Geometry.raycast(grid, origin: Vector3, direction: Vector3, ignore)
	local length = direction.Magnitude
	if length < 1e-9 then
		return nil, nil
	end
	local cell = grid.cell
	local seen = {}
	local candidates = {}
	local steps = math.max(1, math.ceil(length / (cell * 0.5)))
	for i = 0, steps do
		local p = origin + direction * (i / steps)
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					local key = (math.floor(p.X / cell) + dx)
						.. ","
						.. (math.floor(p.Y / cell) + dy)
						.. ","
						.. (math.floor(p.Z / cell) + dz)
					local list = grid.cells[key]
					if list then
						for _, entry in list do
							if not seen[entry] then
								seen[entry] = true
								table.insert(candidates, entry)
							end
						end
					end
				end
			end
		end
	end
	local best, bestT = nil, math.huge
	for _, entry in candidates do
		local part = entry.part
		if not (ignore and ignore(part)) then
			local cf = part.CFrame
			local o = cf:PointToObjectSpace(origin)
			local d = cf:VectorToObjectSpace(direction)
			local t = hitLocal(part, entry.shape, o, d, 1)
			if t and t < bestT then
				best, bestT = part, t
			end
		end
	end
	return best, if best then bestT else nil
end

return Geometry
