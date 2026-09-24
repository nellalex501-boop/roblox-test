--!nocheck
-- 2.5D walkability analysis of a built world.
--
-- Every collidable part is rasterised onto a 1-stud grid as vertical solid
-- intervals. A cell is standable at height h if a solid top is at h and
-- there is 5 studs of headroom above it. Movement to a neighbour is allowed
-- when the step up is <= MAX_STEP and the drop is <= MAX_DROP, roughly
-- matching a Roblox humanoid. Obstacles are inflated by the character
-- radius. Dijkstra from the spawn gives walking distance to every target.

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local Nav = {}

Nav.CELL = 1
Nav.MAX_STEP = 1.1
Nav.MAX_DROP = 6
Nav.HEADROOM = 5
Nav.RADIUS_CELLS = 1
Nav.WALK_SPEED = 16

local function isCylinder(part)
	return part:IsA("Part") and part.Shape == roblox.Enum.PartType.Cylinder
end

local function isBall(part)
	return part:IsA("Part") and part.Shape == roblox.Enum.PartType.Ball
end

-- Returns (bottom, top) of the part's solid at world XZ point, or nil.
local function verticalSpan(part, x, z)
	local cf = part.CFrame
	local size = part.Size
	local half = size / 2
	local up = cf.UpVector
	local uprightish = math.abs(up.Y) > 0.999

	if isBall(part) then
		local r = math.min(size.X, size.Y, size.Z) / 2
		local c = cf.Position
		local d2 = (x - c.X) ^ 2 + (z - c.Z) ^ 2
		if d2 > r * r then
			return nil
		end
		local h = math.sqrt(r * r - d2)
		return c.Y - h, c.Y + h
	end

	if isCylinder(part) then
		local axis = cf.RightVector
		local r = math.min(size.Y, size.Z) / 2
		local c = cf.Position
		if math.abs(axis.Y) > 0.99 then -- upright post
			local d2 = (x - c.X) ^ 2 + (z - c.Z) ^ 2
			if d2 > r * r then
				return nil
			end
			return c.Y - half.X, c.Y + half.X
		end
		-- lying cylinder: treat as its oriented box (approximate)
	end

	if uprightish then
		-- Box rotated about Y only (or not at all): exact footprint test.
		local lp = cf:PointToObjectSpace(Vector3.new(x, cf.Position.Y, z))
		if math.abs(lp.X) > half.X or math.abs(lp.Z) > half.Z then
			return nil
		end
		local bottom = cf.Position.Y - half.Y
		local top = cf.Position.Y + half.Y
		if part:IsA("WedgePart") then
			-- slope rises from front (-Z, low) to back (+Z, high)
			local t = (lp.Z + half.Z) / size.Z
			top = bottom + size.Y * t
		end
		return bottom, top
	end

	-- Tilted parts: conservative vertical extent from the corners that lie
	-- over this XZ point (approximate via oriented bounds).
	local lp = cf:PointToObjectSpace(Vector3.new(x, cf.Position.Y, z))
	local horizontalReach = math.max(half.X, half.Z)
	if math.abs(lp.X) > horizontalReach + half.Y or math.abs(lp.Z) > horizontalReach + half.Y then
		return nil
	end
	local minY, maxY = math.huge, -math.huge
	local inside = false
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
				minY = math.min(minY, p.Y)
				maxY = math.max(maxY, p.Y)
			end
		end
	end
	-- footprint check with oriented box projected on XZ
	local corners = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for _, sy in { -1, 1 } do
				local p = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
				table.insert(corners, p)
			end
		end
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in corners do
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minZ = math.min(minZ, p.Z)
		maxZ = math.max(maxZ, p.Z)
	end
	inside = x >= minX and x <= maxX and z >= minZ and z <= maxZ
	if not inside then
		return nil
	end
	return minY, maxY
end

local function worldBounds(part)
	local cf, half = part.CFrame, part.Size / 2
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
				minX = math.min(minX, p.X)
				maxX = math.max(maxX, p.X)
				minY = math.min(minY, p.Y)
				maxY = math.max(maxY, p.Y)
				minZ = math.min(minZ, p.Z)
				maxZ = math.max(maxZ, p.Z)
			end
		end
	end
	return minX, maxX, minY, maxY, minZ, maxZ
end
Nav.worldBounds = worldBounds

function Nav.build(root, bounds)
	local cell = Nav.CELL
	local minX, maxX, minZ, maxZ = bounds.MinX, bounds.MaxX, bounds.MinZ, bounds.MaxZ
	local cols = math.floor((maxX - minX) / cell)
	local rows = math.floor((maxZ - minZ) / cell)
	local spans = table.create(cols * rows, false)

	local collidable = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			table.insert(collidable, d)
		end
	end

	for _, part in collidable do
		local pminX, pmaxX, _, _, pminZ, pmaxZ = worldBounds(part)
		local c0 = math.max(0, math.floor((pminX - minX) / cell))
		local c1 = math.min(cols - 1, math.floor((pmaxX - minX) / cell))
		local r0 = math.max(0, math.floor((pminZ - minZ) / cell))
		local r1 = math.min(rows - 1, math.floor((pmaxZ - minZ) / cell))
		for c = c0, c1 do
			local x = minX + (c + 0.5) * cell
			for r = r0, r1 do
				local z = minZ + (r + 0.5) * cell
				local bottom, top = verticalSpan(part, x, z)
				if bottom then
					local idx = r * cols + c + 1
					local list = spans[idx]
					if not list then
						list = {}
						spans[idx] = list
					end
					table.insert(list, { bottom, top })
				end
			end
		end
	end

	-- Standable surfaces per cell (sorted ascending).
	local surfaces = table.create(cols * rows, false)
	for idx = 1, cols * rows do
		local list = spans[idx]
		if list then
			local tops = {}
			for _, span in list do
				local h = span[2]
				local clear = true
				for _, other in list do
					if other[1] < h + Nav.HEADROOM and other[2] > h + 0.05 then
						clear = false
						break
					end
				end
				if clear then
					table.insert(tops, h)
				end
			end
			table.sort(tops)
			surfaces[idx] = tops
		end
	end

	return {
		cols = cols,
		rows = rows,
		minX = minX,
		minZ = minZ,
		cell = cell,
		spans = spans,
		surfaces = surfaces,
		partCount = #collidable,
	}
end

local function idxOf(grid, x, z)
	local c = math.floor((x - grid.minX) / grid.cell)
	local r = math.floor((z - grid.minZ) / grid.cell)
	if c < 0 or r < 0 or c >= grid.cols or r >= grid.rows then
		return nil
	end
	return r * grid.cols + c + 1, c, r
end
Nav.idxOf = idxOf

-- Is there a solid obstacle in the body band above surface h at this cell?
local function bodyBlocked(grid, idx, h)
	local list = grid.spans[idx]
	if not list then
		return false
	end
	for _, span in list do
		if span[1] < h + Nav.HEADROOM and span[2] > h + Nav.MAX_STEP then
			return true
		end
	end
	return false
end

local function surfaceNear(grid, idx, fromH)
	local tops = grid.surfaces[idx]
	if not tops then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, h in tops do
		local rise = h - fromH
		if rise <= Nav.MAX_STEP and -rise <= Nav.MAX_DROP then
			local d = math.abs(rise)
			if d < bestD then
				best, bestD = h, d
			end
		end
	end
	return best
end

-- Dijkstra over (cell, surface). Returns dist map [idx] = studs and
-- height map [idx] = surface used.
function Nav.distances(grid, start: Vector3)
	local startIdx = idxOf(grid, start.X, start.Z)
	assert(startIdx, "start outside grid")
	local startH = surfaceNear(grid, startIdx, start.Y)
	assert(startH, "no standable surface at start")

	local cols, rows = grid.cols, grid.rows
	local dist = {}
	local height = {}
	local prev = {}
	dist[startIdx] = 0
	height[startIdx] = startH

	-- binary heap
	local heap = { { 0, startIdx } }
	local function push(d, i)
		table.insert(heap, { d, i })
		local n = #heap
		while n > 1 do
			local p = n // 2
			if heap[p][1] <= heap[n][1] then
				break
			end
			heap[p], heap[n] = heap[n], heap[p]
			n = p
		end
	end
	local function pop()
		local top = heap[1]
		local last = table.remove(heap)
		if #heap > 0 then
			heap[1] = last
			local n = 1
			while true do
				local l, r = n * 2, n * 2 + 1
				local s = n
				if l <= #heap and heap[l][1] < heap[s][1] then
					s = l
				end
				if r <= #heap and heap[r][1] < heap[s][1] then
					s = r
				end
				if s == n then
					break
				end
				heap[s], heap[n] = heap[n], heap[s]
				n = s
			end
		end
		return top
	end

	local neighbours = {
		{ 1, 0, 1 },
		{ -1, 0, 1 },
		{ 0, 1, 1 },
		{ 0, -1, 1 },
		{ 1, 1, 1.4142 },
		{ 1, -1, 1.4142 },
		{ -1, 1, 1.4142 },
		{ -1, -1, 1.4142 },
	}
	local radius = Nav.RADIUS_CELLS

	local function clearAround(c, r, h)
		for dc = -radius, radius do
			for dr = -radius, radius do
				local cc, rr = c + dc, r + dr
				if cc < 0 or rr < 0 or cc >= cols or rr >= rows then
					return false
				end
				local i = rr * cols + cc + 1
				if bodyBlocked(grid, i, h) then
					return false
				end
			end
		end
		return true
	end

	while #heap > 0 do
		local item = pop()
		local d, i = item[1], item[2]
		if d <= (dist[i] or math.huge) then
			local c = (i - 1) % cols
			local r = (i - 1) // cols
			local h = height[i]
			for _, n in neighbours do
				local cc, rr = c + n[1], r + n[2]
				if cc >= 0 and rr >= 0 and cc < cols and rr < rows then
					local j = rr * cols + cc + 1
					local nh = surfaceNear(grid, j, h)
					if nh and clearAround(cc, rr, nh) then
						-- diagonal moves must not cut wall corners
						local ok = true
						if n[1] ~= 0 and n[2] ~= 0 then
							local a = r * cols + cc + 1
							local b = rr * cols + c + 1
							ok = not bodyBlocked(grid, a, h) and not bodyBlocked(grid, b, h)
						end
						local nd = d + n[3] * grid.cell
						if ok and nd < (dist[j] or math.huge) then
							dist[j] = nd
							height[j] = nh
							prev[j] = i
							push(nd, j)
						end
					end
				end
			end
		end
	end
	return dist, height, prev
end

-- Walking distance to the nearest reached cell within `reach` studs of a
-- target point (a prompt can be used from anywhere within its range).
function Nav.distanceTo(grid, dist, target: Vector3, reach: number)
	local best, bestIdx = math.huge, nil
	local cellReach = math.ceil(reach / grid.cell)
	local ti, tc, tr = idxOf(grid, target.X, target.Z)
	if not ti then
		return nil
	end
	for dc = -cellReach, cellReach do
		for dr = -cellReach, cellReach do
			local c, r = tc + dc, tr + dr
			if c >= 0 and r >= 0 and c < grid.cols and r < grid.rows then
				local i = r * grid.cols + c + 1
				local d = dist[i]
				if d then
					local x = grid.minX + (c + 0.5) * grid.cell
					local z = grid.minZ + (r + 0.5) * grid.cell
					local planar = math.sqrt((x - target.X) ^ 2 + (z - target.Z) ^ 2)
					if planar <= reach and d < best then
						best, bestIdx = d, i
					end
				end
			end
		end
	end
	if best == math.huge then
		return nil
	end
	return best, bestIdx
end

function Nav.path(grid, prev, endIdx)
	local points = {}
	local i = endIdx
	local guard = 0
	while i and guard < 100000 do
		guard += 1
		local c = (i - 1) % grid.cols
		local r = (i - 1) // grid.cols
		table.insert(points, 1, { grid.minX + (c + 0.5) * grid.cell, grid.minZ + (r + 0.5) * grid.cell })
		i = prev[i]
	end
	return points
end

-- Ray vs oriented boxes: returns list of occluding parts between a and b.
function Nav.occluders(root, a: Vector3, b: Vector3, ignore)
	local hits = {}
	local dir = b - a
	local length = dir.Magnitude
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.5 and not (ignore and ignore(part)) then
			local cf, half = part.CFrame, part.Size / 2
			local o = cf:PointToObjectSpace(a)
			local d = cf:VectorToObjectSpace(dir)
			local tmin, tmax = 0, 1
			local hit = true
			for _, axis in { "X", "Y", "Z" } do
				local oa, da, ha = o[axis], d[axis], half[axis]
				if math.abs(da) < 1e-9 then
					if math.abs(oa) > ha then
						hit = false
						break
					end
				else
					local t1 = (-ha - oa) / da
					local t2 = (ha - oa) / da
					if t1 > t2 then
						t1, t2 = t2, t1
					end
					tmin = math.max(tmin, t1)
					tmax = math.min(tmax, t2)
					if tmin > tmax then
						hit = false
						break
					end
				end
			end
			if hit and tmax > 0.02 and tmin < 0.98 and length > 0 then
				table.insert(hits, part)
			end
		end
	end
	return hits
end

return Nav
