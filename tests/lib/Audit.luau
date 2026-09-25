--!nocheck
-- World audits for the visual review: parts that float (not connected to
-- the ground through other visible parts), text on a surface with a part
-- standing in front of it, and trees grown into structures. Boxes are
-- oriented bounding boxes (cylinders and balls count as their boxes).

local roblox = require("@lune/roblox")

local Geometry = require("./Geometry")

local Vector3 = roblox.Vector3

local Audit = {}

local function path(root, inst)
	local names = {}
	local p = inst
	while p and p ~= root do
		table.insert(names, 1, p.Name)
		p = p.Parent
	end
	return table.concat(names, "/")
end
Audit.path = path

local function obb(part)
	local cf = part.CFrame
	return {
		c = cf.Position,
		a = { cf.RightVector, cf.UpVector, cf.LookVector },
		h = { part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2 },
	}
end

local function radius(o, axis)
	return o.h[1] * math.abs(o.a[1]:Dot(axis))
		+ o.h[2] * math.abs(o.a[2]:Dot(axis))
		+ o.h[3] * math.abs(o.a[3]:Dot(axis))
end

-- Penetration depth of two boxes along their best separating axis
-- (negative: the gap between them).
local function overlap(A, B)
	local d = B.c - A.c
	local best = math.huge
	local function test(ax)
		local o = radius(A, ax) + radius(B, ax) - math.abs(d:Dot(ax))
		if o < best then
			best = o
		end
	end
	for i = 1, 3 do
		test(A.a[i])
		test(B.a[i])
	end
	for i = 1, 3 do
		for j = 1, 3 do
			local c = A.a[i]:Cross(B.a[j])
			if c.Magnitude > 1e-6 then
				test(c.Unit)
			end
		end
	end
	return best
end
Audit.overlap = overlap

-- Spatial hash over the boxes of the parts inside `bounds` (XZ rect).
function Audit.index(root, bounds, include)
	local cell = 8
	local index = { cell = cell, cells = {}, boxes = {}, parts = {} }
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and (include == nil or include(d)) then
			local p = d.CFrame.Position
			local big = math.max(d.Size.X, d.Size.Y, d.Size.Z) >= 400
			if not big and p.X > bounds.MinX and p.X < bounds.MaxX and p.Z > bounds.MinZ and p.Z < bounds.MaxZ then
				local cf, h = d.CFrame, d.Size / 2
				local ext = Vector3.new(
					math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
					math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
					math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
				)
				local lo, hi = p - ext, p + ext
				index.boxes[d] = { lo = lo, hi = hi, o = obb(d) }
				table.insert(index.parts, d)
				for gx = math.floor(lo.X / cell), math.floor(hi.X / cell) do
					for gy = math.floor(lo.Y / cell), math.floor(hi.Y / cell) do
						for gz = math.floor(lo.Z / cell), math.floor(hi.Z / cell) do
							local key = gx .. "," .. gy .. "," .. gz
							local list = index.cells[key]
							if not list then
								list = {}
								index.cells[key] = list
							end
							table.insert(list, d)
						end
					end
				end
			end
		end
	end
	return index
end

local function neighbours(index, part, pad)
	local b = index.boxes[part]
	local cell = index.cell
	local seen, out = {}, {}
	for gx = math.floor((b.lo.X - pad) / cell), math.floor((b.hi.X + pad) / cell) do
		for gy = math.floor((b.lo.Y - pad) / cell), math.floor((b.hi.Y + pad) / cell) do
			for gz = math.floor((b.lo.Z - pad) / cell), math.floor((b.hi.Z + pad) / cell) do
				for _, q in index.cells[gx .. "," .. gy .. "," .. gz] or {} do
					if q ~= part and not seen[q] then
						seen[q] = true
						local c = index.boxes[q]
						if
							c.lo.X <= b.hi.X + pad
							and c.hi.X >= b.lo.X - pad
							and c.lo.Y <= b.hi.Y + pad
							and c.hi.Y >= b.lo.Y - pad
							and c.lo.Z <= b.hi.Z + pad
							and c.hi.Z >= b.lo.Z - pad
						then
							table.insert(out, q)
						end
					end
				end
			end
		end
	end
	return out
end
Audit.neighbours = neighbours

local function treeOf(part)
	local m = part:FindFirstAncestorOfClass("Model")
	if m and (m.Name == "Pine" or m.Name == "Tree") then
		return m
	end
	return nil
end
Audit.treeOf = treeOf

-- Groups of visible parts that no chain of touching visible parts (gaps
-- up to `tolerance`) connects to the ground. A tree counts as one piece:
-- its hollow tiers stand on the trunk. Returns { { path, parts, at } }.
function Audit.islands(root, bounds, tolerance)
	local tol = tolerance or 0.08
	local index = Audit.index(root, bounds, function(p)
		return p.Transparency < 0.95
	end)
	local reached, queue = {}, {}
	for _, part in index.parts do
		if index.boxes[part].lo.Y <= 0.12 then
			reached[part] = true
			table.insert(queue, part)
		end
	end
	local head = 1
	while head <= #queue do
		local part = queue[head]
		head += 1
		for _, q in neighbours(index, part, tol + 0.02) do
			if not reached[q] and overlap(index.boxes[part].o, index.boxes[q].o) > -tol then
				reached[q] = true
				table.insert(queue, q)
			end
		end
	end
	local groundedTree = {}
	for part in reached do
		local tree = treeOf(part)
		if tree then
			groundedTree[tree] = true
		end
	end
	-- a tree straddling the bounds has its trunk outside the index
	local cut = {}
	local function straddles(tree)
		if cut[tree] == nil then
			cut[tree] = false
			for _, d in tree:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 0.95 and not index.boxes[d] then
					cut[tree] = true
					break
				end
			end
		end
		return cut[tree]
	end
	local groups, order = {}, {}
	for _, part in index.parts do
		local tree = treeOf(part)
		if not reached[part] and not (tree and (groundedTree[tree] or straddles(tree))) then
			local owner = part:FindFirstAncestorOfClass("Model") or part.Parent
			local key = path(root, owner)
			if not groups[key] then
				groups[key] = { path = key, parts = {}, at = part.CFrame.Position }
				table.insert(order, key)
			end
			table.insert(groups[key].parts, part.Name)
		end
	end
	local list = {}
	for _, key in order do
		table.insert(list, groups[key])
	end
	return list
end

-- Face normal, GUI x and GUI y directions (part space) of a SurfaceGui face.
local FACES = {
	Front = { Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0) },
	Back = { Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(0, -1, 0) },
	Right = { Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0) },
	Left = { Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0) },
	Top = { Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) },
	Bottom = { Vector3.new(0, -1, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1) },
}

local function extent(h, axis)
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end

-- A label's box on its SurfaceGui in scale units (0..1), through parent
-- frames.
local function labelRect(label, gui)
	local x0, y0, w, h = 0, 0, 1, 1
	local chain = {}
	local node = label
	while node and node ~= gui do
		table.insert(chain, 1, node)
		node = node.Parent
	end
	for _, g in chain do
		if g:IsA("GuiObject") then
			local sx, sy = g.Size.X.Scale, g.Size.Y.Scale
			x0 += (g.Position.X.Scale - g.AnchorPoint.X * sx) * w
			y0 += (g.Position.Y.Scale - g.AnchorPoint.Y * sy) * h
			w, h = w * sx, h * sy
		end
	end
	return x0, y0, w, h
end

Audit.labelRect = labelRect

-- World point on a SurfaceGui face at GUI scale position (gx, gy), `lift`
-- studs off the face.
function Audit.facePoint(part, faceName, gx, gy, lift)
	local f = FACES[faceName]
	local n, u, v = f[1], f[2], f[3]
	local hs = part.Size / 2
	local hu, hv, hn = extent(hs, u), extent(hs, v), extent(hs, n)
	return part.CFrame:PointToWorldSpace(n * (hn + lift) + u * ((gx - 0.5) * 2 * hu) + v * ((gy - 0.5) * 2 * hv))
end

-- Text on a surface with a part standing within `range` studs in front of
-- it. Rays leave a grid of points on every label (and on the face of any
-- part tagged EventSurface, whose text is set at runtime). `allow(hit,
-- part)` excuses intended overlaps. Returns { { part, face, blockers,
-- covered, total } }.
function Audit.coveredText(root, bounds, range, allow)
	local grid = Geometry.index(root, function(p)
		local q = p.CFrame.Position
		return p.Transparency < 0.5
			and q.X > bounds.MinX
			and q.X < bounds.MaxX
			and q.Z > bounds.MinZ
			and q.Z < bounds.MaxZ
			and math.max(p.Size.X, p.Size.Y, p.Size.Z) < 400
	end, 8)
	local findings = {}
	local function check(part, faceName, rects)
		local n = FACES[faceName][1]
		local covered, total, blockers = 0, 0, {}
		for _, r in rects do
			for i = 0, 4 do
				for j = 0, 2 do
					local gx = r[1] + r[3] * (0.1 + 0.8 * i / 4)
					local gy = r[2] + r[4] * (0.2 + 0.6 * j / 2)
					local p = Audit.facePoint(part, faceName, gx, gy, 0.03)
					total += 1
					local hit = Geometry.raycast(grid, p, part.CFrame:VectorToWorldSpace(n) * range, function(q)
						return q == part
					end)
					if hit and not (allow and allow(hit, part)) then
						covered += 1
						blockers[path(root, hit)] = true
					end
				end
			end
		end
		if covered > 0 then
			local names = {}
			for k in blockers do
				table.insert(names, k)
			end
			table.sort(names)
			table.insert(findings, {
				part = part,
				face = faceName,
				blockers = names,
				covered = covered,
				total = total,
			})
		end
	end
	for _, gui in root:GetDescendants() do
		local part = gui.Parent
		if gui:IsA("SurfaceGui") and part and part:IsA("BasePart") then
			local q = part.CFrame.Position
			if q.X > bounds.MinX and q.X < bounds.MaxX and q.Z > bounds.MinZ and q.Z < bounds.MaxZ then
				local rects = {}
				for _, t in gui:GetDescendants() do
					if t:IsA("TextLabel") and t.Text ~= "" and t.Visible then
						local x0, y0, w, h = labelRect(t, gui)
						table.insert(rects, { x0, y0, w, h })
					end
				end
				if #rects > 0 then
					check(part, gui.Face.Name, rects)
				end
			end
		end
	end
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("EventSurface") then
			check(part, "Front", { { 0.05, 0.05, 0.9, 0.9 } })
		end
	end
	return findings
end

-- Tree parts (pines, broadleaves) intersecting anything that is not a tree
-- by more than `depth`. Returns { "tree path x other path" }.
function Audit.treeClashes(root, bounds, depth)
	local index = Audit.index(root, bounds, function(p)
		return p.Transparency < 0.9
	end)
	local found, list = {}, {}
	for _, part in index.parts do
		if treeOf(part) then
			for _, q in neighbours(index, part, 0) do
				-- snow drifts are sunken spheres: their boxes reach far beyond them
				if not treeOf(q) and q.Name ~= "Drift" and index.boxes[q].hi.Y > 0.3 then
					if overlap(index.boxes[part].o, index.boxes[q].o) > depth then
						local key = path(root, treeOf(part)) .. " x " .. path(root, q)
						if not found[key] then
							found[key] = true
							table.insert(list, key)
						end
					end
				end
			end
		end
	end
	return list
end

return Audit
