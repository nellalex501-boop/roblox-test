--!strict
-- Reusable architectural elements. All positions are local to a zone frame
-- (see Layout.frame): -Z into the building, +Z out toward the road.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Architecture = {}

export type WindowStyle = {
	Glass: Color3?,
	Frame: Color3?, -- glazing bars (frame and mullions)
	Sill: Color3?,
	Depth: number?, -- (unused, kept for callers)
	Lit: boolean?,
	Inset: number?, -- glass set back from the wall face (default 0.4)
	Mullions: number?, -- vertical glazing bars (default 1)
	Transom: boolean?, -- horizontal bar at two thirds of the height
}

-- Walls no thicker than this are cut through; thicker solid blocks get a
-- protruding surround with the glass recessed inside it instead.
local CUT_MAX_THICKNESS = 1.6

local function axisVectors(cf: CFrame): { Vector3 }
	return { cf.XVector, cf.YVector, cf.ZVector }
end

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- The wall block among `root`'s children containing `point`, and its
-- thickness along `normal`.
local function wallAt(root: Instance, point: Vector3, normal: Vector3): (Part?, number)
	for _, child in root:GetChildren() do
		if child:IsA("Part") and child.Shape == Enum.PartType.Block and child.CanCollide then
			local lp = child.CFrame:PointToObjectSpace(point)
			local h = child.Size / 2
			if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z then
				local ln = child.CFrame:VectorToObjectSpace(normal)
				local thickness = math.abs(ln.X) * child.Size.X
					+ math.abs(ln.Y) * child.Size.Y
					+ math.abs(ln.Z) * child.Size.Z
				return child, thickness
			end
		end
	end
	return nil, 0
end

-- Cuts a rectangular opening (width along the wall, height up) through a
-- wall block along `normal`: the block is replaced by the pieces around
-- the opening, with the same look. Butt-jointed, so no faces overlap.
function Architecture.cutOpening(wall: Part, center: Vector3, normal: Vector3, width: number, height: number)
	local cf, size = wall.CFrame, wall.Size
	local vectors = axisVectors(cf)
	local sizes = { size.X, size.Y, size.Z }
	local through, bestT = 1, -1
	for i, v in vectors do
		local d = math.abs(v:Dot(normal))
		if d > bestT then
			through, bestT = i, d
		end
	end
	local up, bestU = 0, -1
	for i, v in vectors do
		if i ~= through then
			local d = math.abs(v.Y)
			if d > bestU then
				up, bestU = i, d
			end
		end
	end
	local along = 6 - through - up
	local lp = cf:PointToObjectSpace(center)
	local comps = { lp.X, lp.Y, lp.Z }
	local a0, u0 = comps[along], comps[up]
	local halfA, halfU = sizes[along] / 2, sizes[up] / 2
	local wa, hu = width / 2, height / 2
	local left, right = math.max(a0 - wa, -halfA), math.min(a0 + wa, halfA)
	local pieces = {
		{ -halfA, left, -halfU, halfU },
		{ right, halfA, -halfU, halfU },
		{ left, right, -halfU, math.max(u0 - hu, -halfU) },
		{ left, right, math.min(u0 + hu, halfU), halfU },
	}
	for _, piece in pieces do
		local pa0, pa1, pu0, pu1 = piece[1], piece[2], piece[3], piece[4]
		if pa1 - pa0 > 0.05 and pu1 - pu0 > 0.05 then
			local sz = { 0, 0, 0 }
			local ct = { 0, 0, 0 }
			sz[along], sz[up], sz[through] = pa1 - pa0, pu1 - pu0, sizes[through]
			ct[along], ct[up] = (pa0 + pa1) / 2, (pu0 + pu1) / 2
			local part = Instance.new("Part")
			part.Name = wall.Name
			part.Anchored = true
			part.Color = wall.Color
			part.Material = wall.Material
			part.Transparency = wall.Transparency
			part.Reflectance = wall.Reflectance
			part.CastShadow = wall.CastShadow
			part.CanCollide = wall.CanCollide
			part.CanQuery = wall.CanQuery
			part.CanTouch = wall.CanTouch
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Size = vec(sz)
			part.CFrame = cf * CFrame.new(vec(ct))
			part.Parent = wall.Parent
		end
	end
	wall:Destroy()
end

-- Glazing inside a window of width w and height h, glass front at local
-- z = glassZ (window frame: +Z out of the wall, origin at the centre).
-- A box from a to b (frame-local corners) split along local X around
-- `gaps` ({ from, to } in local X), e.g. a plinth band that stops at the
-- door jambs instead of running across the doorway.
function Architecture.boxRun(
	parent: Instance,
	frame: CFrame,
	a: Vector3,
	b: Vector3,
	gaps: { { number } },
	color: Color3,
	material: Enum.Material,
	opts: Kit.Opts?
): { Part }
	local x0, x1 = math.min(a.X, b.X), math.max(a.X, b.X)
	local sorted = table.clone(gaps)
	table.sort(sorted, function(l, r)
		return l[1] < r[1]
	end)
	local parts = {}
	local cursor = x0
	local function piece(from: number, to: number)
		if to - from > 0.05 then
			table.insert(
				parts,
				Kit.box(parent, frame, Vector3.new(from, a.Y, a.Z), Vector3.new(to, b.Y, b.Z), color, material, opts)
			)
		end
	end
	for _, gap in sorted do
		piece(cursor, math.min(gap[1], x1))
		cursor = math.max(cursor, gap[2])
	end
	piece(cursor, x1)
	return parts
end

local function glazing(parent: Instance, wf: CFrame, w: number, h: number, glassZ: number, s: WindowStyle)
	local glass = s.Glass or W.Glass
	local bars = s.Frame or W.DarkGrey
	Kit.part(
		parent,
		Vector3.new(w, h, 0.1),
		wf * CFrame.new(0, 0, glassZ - 0.05),
		if s.Lit then W.GlassLit else glass,
		Enum.Material.Glass,
		{ Name = "Window", Reflectance = 0.15, Shadow = false, Query = false }
	)
	-- frame: head and foot full width, jambs between them; 0.12 proud of
	-- the glass
	local fb = 0.18
	local frameZ = glassZ + 0.06
	for _, y in { h / 2 - fb / 2, -h / 2 + fb / 2 } do
		Kit.part(parent, Vector3.new(w, fb, 0.12), wf * CFrame.new(0, y, frameZ), bars, Enum.Material.SmoothPlastic, {
			Name = "WindowFrame",
			Decor = true,
		})
	end
	for _, x in { -w / 2 + fb / 2, w / 2 - fb / 2 } do
		Kit.part(
			parent,
			Vector3.new(fb, h - 2 * fb, 0.12),
			wf * CFrame.new(x, 0, frameZ),
			bars,
			Enum.Material.SmoothPlastic,
			{ Name = "WindowFrame", Decor = true }
		)
	end
	-- mullions and transom segments between them: 0.08 proud of the glass,
	-- butt-jointed so no two bars share a face
	local inner = w - 2 * fb
	local count = s.Mullions or 1
	local mw = 0.14
	local barZ = glassZ + 0.04
	local xs = { -inner / 2 }
	for i = 1, count do
		local x = -inner / 2 + inner * i / (count + 1)
		table.insert(xs, x)
		Kit.part(
			parent,
			Vector3.new(mw, h - 2 * fb, 0.08),
			wf * CFrame.new(x, 0, barZ),
			bars,
			Enum.Material.SmoothPlastic,
			{ Name = "Mullion", Decor = true }
		)
	end
	table.insert(xs, inner / 2)
	if s.Transom or (s.Transom == nil and h > 3.6) then
		local y = h / 2 - fb - (h - 2 * fb) / 3
		for i = 1, #xs - 1 do
			local a = xs[i] + (if i > 1 then mw / 2 else 0)
			local b = xs[i + 1] - (if i < #xs - 1 then mw / 2 else 0)
			if b - a > 0.1 then
				Kit.part(
					parent,
					Vector3.new(b - a, mw, 0.08),
					wf * CFrame.new((a + b) / 2, y, barZ),
					bars,
					Enum.Material.SmoothPlastic,
					{ Name = "Transom", Decor = true }
				)
			end
		end
	end
end

-- A row of windows on a wall face. The wall runs along local X at depth z,
-- with its outer face toward +Z (outward = 1) or -Z (outward = -1).
-- Thin walls get real openings with the glass set back (Inset) inside the
-- reveal, a frame, mullions, a sill and a lintel; solid blocks get a
-- protruding surround with the glass recessed 0.3 inside it.
function Architecture.windowRow(
	parent: Instance,
	frame: CFrame,
	x0: number,
	x1: number,
	z: number,
	outward: number,
	y0: number,
	y1: number,
	count: number,
	windowWidth: number,
	style: WindowStyle?
)
	local s: WindowStyle = style or {}
	local sillColor = s.Sill or W.ConcreteLight
	local inset = s.Inset or 0.4
	local span = x1 - x0
	local gap = (span - count * windowWidth) / (count + 1)
	local w, h = windowWidth, y1 - y0
	local overhang = math.clamp(gap / 2 - 0.08, 0.05, 0.3)
	local turn = if outward > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
	for i = 1, count do
		local cx = x0 + gap * i + windowWidth * (i - 0.5)
		local wf = frame * CFrame.new(cx, (y0 + y1) / 2, z) * turn
		local normal = wf.ZVector
		local probe = (wf * CFrame.new(0, 0, -0.1)).Position
		local wall, thickness = wallAt(parent, probe, normal)
		if wall and thickness <= CUT_MAX_THICKNESS then
			Architecture.cutOpening(wall, wf.Position, normal, w, h)
			glazing(parent, wf, w, h, -inset, s)
			Kit.part(
				parent,
				Vector3.new(w + overhang * 2, 0.3, 0.12),
				wf * CFrame.new(0, h / 2 + 0.15, 0.06),
				sillColor,
				Enum.Material.Concrete,
				{ Name = "Lintel", Shadow = false }
			)
		else
			-- surround protruding 0.38, glass 0.3 behind its face
			local sw = 0.3
			local depth = 0.38
			local pieces = {
				{ Vector3.new(w + 2 * sw, sw, depth), Vector3.new(0, h / 2 + sw / 2, depth / 2) },
				{ Vector3.new(w + 2 * sw, sw, depth), Vector3.new(0, -h / 2 - sw / 2, depth / 2) },
				{ Vector3.new(sw, h, depth), Vector3.new(-w / 2 - sw / 2, 0, depth / 2) },
				{ Vector3.new(sw, h, depth), Vector3.new(w / 2 + sw / 2, 0, depth / 2) },
			}
			for _, piece in pieces do
				Kit.part(parent, piece[1], wf * CFrame.new(piece[2]), sillColor, Enum.Material.Concrete, {
					Name = "Surround",
				})
			end
			glazing(parent, wf, w, h, depth - 0.3, s)
		end
		-- sill below the opening, clear of its neighbours
		local sillY = -h / 2 - (if wall and thickness <= CUT_MAX_THICKNESS then 0 else 0.3)
		Kit.part(
			parent,
			Vector3.new(w + overhang * 2 + 0.1, 0.22, 0.5),
			wf * CFrame.new(0, sillY - 0.11, 0.25),
			sillColor,
			Enum.Material.Concrete,
			{ Name = "Sill", Shadow = false, Collide = false, Query = false }
		)
	end
end

-- Same as windowRow but for a wall running along local Z at x (outward is
-- +1 for +X, -1 for -X).
function Architecture.windowColumn(
	parent: Instance,
	frame: CFrame,
	z0: number,
	z1: number,
	x: number,
	outward: number,
	y0: number,
	y1: number,
	count: number,
	windowWidth: number,
	style: WindowStyle?
)
	-- Rotate so the wall's outward normal becomes local +Z. Rotating by
	-- +90 deg maps local +Z to +X and local +X to -Z (and vice versa).
	local rotated = frame * CFrame.new(x, 0, 0) * CFrame.Angles(0, outward * math.pi / 2, 0)
	local a, b
	if outward > 0 then
		a, b = -z1, -z0
	else
		a, b = z0, z1
	end
	Architecture.windowRow(parent, rotated, a, b, 0, 1, y0, y1, count, windowWidth, style)
end

-- Flat roof slab with a parapet around its edge. The slab stops 0.06 short
-- of the parapet's outer faces, and the parapet and coping pieces butt at
-- the corners instead of overlapping, so no two faces share a plane (no
-- shimmering band along the roofline).
function Architecture.flatRoof(
	parent: Instance,
	frame: CFrame,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y: number,
	parapet: number,
	color: Color3,
	capColor: Color3?
)
	local inset = 0.06
	Kit.box(
		parent,
		frame,
		Vector3.new(x0 + inset, y, z0 + inset),
		Vector3.new(x1 - inset, y + 1, z1 - inset),
		W.ConcreteDark,
		Enum.Material.Concrete,
		{
			Name = "RoofSlab",
		}
	)
	local t = 0.8
	local top = y + 1 + parapet
	local cap = capColor or W.ConcreteLight
	local o = 0.15 -- coping overhang
	-- the two long runs (along X) take the corners; the Z runs fit between
	type Run = { a: Vector3, b: Vector3, long: boolean }
	local walls: { Run } = {
		{ a = Vector3.new(x0, y, z1 - t), b = Vector3.new(x1, top, z1), long = true },
		{ a = Vector3.new(x0, y, z0), b = Vector3.new(x1, top, z0 + t), long = true },
		{ a = Vector3.new(x0, y, z0 + t), b = Vector3.new(x0 + t, top, z1 - t), long = false },
		{ a = Vector3.new(x1 - t, y, z0 + t), b = Vector3.new(x1, top, z1 - t), long = false },
	}
	for _, w in walls do
		local a, b, long = w.a, w.b, w.long
		Kit.box(parent, frame, a, b, color, Enum.Material.Concrete, { Name = "Parapet" })
		local capA, capB
		if long then
			capA = Vector3.new(a.X - o, top, a.Z - o)
			capB = Vector3.new(b.X + o, top + 0.3, b.Z + o)
		else
			capA = Vector3.new(a.X - o, top, a.Z + o)
			capB = Vector3.new(b.X + o, top + 0.3, b.Z - o)
		end
		Kit.box(parent, frame, capA, capB, cap, Enum.Material.Concrete, { Name = "Coping", Shadow = false })
	end
end

-- Gable roof with its ridge running along local X, spanning z0..z1.
-- Returns the ridge height.
function Architecture.gableRoof(
	parent: Instance,
	frame: CFrame,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	eaveY: number,
	rise: number,
	overhang: number,
	roofColor: Color3,
	gableColor: Color3,
	roofMaterial: Enum.Material?,
	gableMaterial: Enum.Material?
): number
	local depth = z1 - z0
	local half = depth / 2
	local midZ = (z0 + z1) / 2
	local length = x1 - x0
	-- gable end triangles (two wedges back to back per end)
	for _, x in { x0, x1 } do
		for _, side in { -1, 1 } do
			local cz = midZ + side * half / 2
			-- wedge: high edge at back (+Z local of the wedge). Aim the high edge
			-- toward the ridge (midZ).
			local rot = if side < 0 then CFrame.Angles(0, 0, 0) else CFrame.Angles(0, math.pi, 0)
			Kit.wedge(
				parent,
				Vector3.new(0.8, rise, half),
				frame * CFrame.new(x + (if x == x0 then 0.4 else -0.4), eaveY + rise / 2, cz) * rot,
				gableColor,
				gableMaterial or Enum.Material.Concrete,
				{ Name = "Gable" }
			)
		end
	end
	-- infill wedges under the roof so the attic is solid (avoids see-through)
	for _, side in { -1, 1 } do
		local cz = midZ + side * half / 2
		local rot = if side < 0 then CFrame.Angles(0, 0, 0) else CFrame.Angles(0, math.pi, 0)
		Kit.wedge(
			parent,
			Vector3.new(length - 1.6, rise, half),
			frame * CFrame.new((x0 + x1) / 2, eaveY + rise / 2, cz) * rot,
			W.ConcreteDark,
			Enum.Material.Concrete,
			{ Name = "Attic", Shadow = false }
		)
	end
	-- roof planes: bottom face lies on the slope, extending past the eave
	local slopeLen = math.sqrt(half * half + rise * rise) + overhang
	local angle = math.atan2(rise, half)
	local oz = overhang * math.cos(angle)
	local oy = overhang * math.sin(angle)
	for _, side in { -1, 1 } do
		local normal = Vector3.new(0, math.cos(angle), side * math.sin(angle))
		local center = Vector3.new((x0 + x1) / 2, eaveY + (rise - oy) / 2, midZ + side * (half + oz) / 2)
			+ normal * 0.45
		Kit.part(
			parent,
			Vector3.new(length + overhang * 2, 0.9, slopeLen),
			frame * CFrame.new(center) * CFrame.Angles(side * angle, 0, 0),
			roofColor,
			roofMaterial or Enum.Material.Slate,
			{ Name = "RoofPlane" }
		)
	end
	-- ridge cap
	Kit.part(
		parent,
		Vector3.new(length + overhang * 2 + 0.4, 0.8, 1.6),
		frame * CFrame.new((x0 + x1) / 2, eaveY + rise + 0.75, midZ),
		W.Charcoal,
		Enum.Material.SmoothPlastic,
		{ Name = "Ridge", Shadow = false }
	)
	return eaveY + rise
end

-- Square column from ground up.
function Architecture.column(
	parent: Instance,
	frame: CFrame,
	x: number,
	z: number,
	y0: number,
	y1: number,
	size: number,
	color: Color3
)
	Kit.box(
		parent,
		frame,
		Vector3.new(x - size / 2, y0, z - size / 2),
		Vector3.new(x + size / 2, y1, z + size / 2),
		color,
		Enum.Material.Concrete,
		{ Name = "Column" }
	)
end

-- Steps rising toward -Z, starting at z (front edge) going inward.
function Architecture.steps(
	parent: Instance,
	frame: CFrame,
	x: number,
	z: number,
	width: number,
	count: number,
	rise: number,
	run: number,
	baseY: number,
	color: Color3
)
	for i = 1, count do
		local zFront = z - (i - 1) * run
		Kit.box(
			parent,
			frame,
			Vector3.new(x - width / 2, baseY, zFront - run * (count - i + 1)),
			Vector3.new(x + width / 2, baseY + rise * i, zFront),
			color,
			Enum.Material.Concrete,
			{ Name = "Step" }
		)
	end
end

-- Door frame trim around an opening in a wall at depth z (facing +Z).
function Architecture.doorFrame(
	parent: Instance,
	frame: CFrame,
	x: number,
	z: number,
	width: number,
	height: number,
	baseY: number,
	color: Color3
)
	local t = 0.8
	Kit.box(
		parent,
		frame,
		Vector3.new(x - width / 2 - t, baseY, z),
		Vector3.new(x - width / 2, baseY + height + t, z + 0.6),
		color,
		nil,
		{
			Name = "DoorFrame",
		}
	)
	Kit.box(
		parent,
		frame,
		Vector3.new(x + width / 2, baseY, z),
		Vector3.new(x + width / 2 + t, baseY + height + t, z + 0.6),
		color,
		nil,
		{
			Name = "DoorFrame",
		}
	)
	Kit.box(
		parent,
		frame,
		Vector3.new(x - width / 2 - t, baseY + height, z),
		Vector3.new(x + width / 2 + t, baseY + height + t, z + 0.6),
		color,
		nil,
		{ Name = "DoorFrame" }
	)
end

-- Two door leaves swung fully open against the inside of the wall.
function Architecture.openDoors(
	parent: Instance,
	frame: CFrame,
	x: number,
	z: number,
	width: number,
	height: number,
	baseY: number,
	color: Color3
)
	local leaf = width / 2
	for _, side in { -1, 1 } do
		local hingeX = x + side * width / 2
		Kit.box(
			parent,
			frame,
			Vector3.new(hingeX + (if side < 0 then 0.2 else -0.5), baseY, z - 0.4 - leaf),
			Vector3.new(hingeX + (if side < 0 then 0.5 else -0.2), baseY + height - 0.4, z - 0.4),
			color,
			Enum.Material.SmoothPlastic,
			{ Name = "DoorLeaf", Decor = true }
		)
	end
end

-- Hazard stripe band (alternating muted yellow / black blocks) along X.
function Architecture.hazardBand(
	parent: Instance,
	frame: CFrame,
	x0: number,
	x1: number,
	y: number,
	z: number,
	height: number
)
	local n = math.max(2, math.floor((x1 - x0) / 1.6))
	local w = (x1 - x0) / n
	for i = 0, n - 1 do
		Kit.box(
			parent,
			frame,
			Vector3.new(x0 + i * w, y, z),
			Vector3.new(x0 + (i + 1) * w, y + height, z + 0.12),
			if i % 2 == 0 then W.HazardYellow else W.Charcoal,
			Enum.Material.SmoothPlastic,
			{ Name = "Hazard", Decor = true }
		)
	end
end

-- Draws a simple arrow with Frames inside a GUI container, pointing at
-- `angle` degrees (0 = right, 90 = down, -90 = up, 180 = left).
function Architecture.guiArrow(parent: Instance, position: UDim2, size: number, angle: number, color: Color3)
	local holder = Instance.new("Frame")
	holder.Name = "Arrow"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(size, size)
	holder.Rotation = angle
	holder.Parent = parent
	local shaft = Instance.new("Frame")
	shaft.BorderSizePixel = 0
	shaft.BackgroundColor3 = color
	shaft.AnchorPoint = Vector2.new(0, 0.5)
	shaft.Position = UDim2.fromScale(0.05, 0.5)
	shaft.Size = UDim2.fromScale(0.6, 0.2)
	shaft.Parent = holder
	-- GUI rotation pivots on the element centre, so place each barb's centre
	-- half a barb-length back from the tip along its own direction.
	local tip = Vector2.new(0.95, 0.5)
	local length, thickness = 0.46, 0.18
	for _, sign in { -1, 1 } do
		local a = math.rad(180 + sign * 40)
		local centre = tip + Vector2.new(math.cos(a), math.sin(a)) * (length / 2)
		local barb = Instance.new("Frame")
		barb.BorderSizePixel = 0
		barb.BackgroundColor3 = color
		barb.AnchorPoint = Vector2.new(0.5, 0.5)
		barb.Position = UDim2.fromScale(centre.X, centre.Y)
		barb.Size = UDim2.fromScale(length, thickness)
		barb.Rotation = sign * 40
		barb.Parent = holder
	end
	return holder
end

-- A flag design paints onto a canvas in "flag units": x runs 0..Aspect
-- (width / height), y runs 0..1 from the top edge.
export type FlagPainter = {
	Aspect: number,
	rect: (x0: number, y0: number, x1: number, y1: number, color: Color3) -> (),
	bar: (cx: number, cy: number, length: number, thickness: number, degrees: number, color: Color3) -> (),
	ring: (cx: number, cy: number, radius: number, thickness: number, color: Color3) -> (),
	text: (cx: number, cy: number, w: number, h: number, text: string, color: Color3) -> (),
}

export type FlagDesign = {
	Name: string?,
	Field: Color3,
	Draw: ((FlagPainter) -> ())?,
}

Architecture.FlagSegments = 8
Architecture.FlagPixelsPerStud = 20

-- Painter for one segment face: shapes outside the segment's slice of the
-- canvas are skipped, so each segment only carries what it shows.
-- Draws in design space (x from 0 at the hoist to `aspect` at the fly);
-- only the slice x0..x1 is drawn. `mirror` flips positions left-right (the
-- glyphs of text still read normally).
local function painter(
	canvas: Frame,
	aspect: number,
	pixelHeight: number,
	x0: number,
	x1: number,
	mirror: boolean?
): FlagPainter
	local function visible(a: number, b: number): boolean
		return b > x0 - 0.001 and a < x1 + 0.001
	end
	local function mx(x: number): number
		return if mirror then aspect - x else x
	end
	local turn = if mirror then -1 else 1
	local function frame(cx: number, cy: number, w: number, h: number, color: Color3): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(cx / aspect, cy)
		f.Size = UDim2.fromScale(w / aspect, h)
		f.Parent = canvas
		return f
	end
	local p: FlagPainter = {
		Aspect = aspect,
		rect = function(ax, ay, bx, by, color)
			if visible(ax, bx) then
				frame(mx((ax + bx) / 2), (ay + by) / 2, bx - ax, by - ay, color)
			end
		end,
		bar = function(cx, cy, length, thickness, degrees, color)
			local reach = length / 2 + thickness
			if visible(cx - reach, cx + reach) then
				local f = frame(mx(cx), cy, thickness, length, color)
				f.Rotation = degrees * turn
			end
		end,
		ring = function(cx, cy, radius, thickness, color)
			if visible(cx - radius, cx + radius) then
				local f = frame(mx(cx), cy, radius * 2, radius * 2, color)
				f.BackgroundTransparency = 1
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = f
				local stroke = Instance.new("UIStroke")
				stroke.Color = color
				stroke.Thickness = math.max(1, thickness * pixelHeight)
				stroke.Parent = f
			end
		end,
		text = function(cx, cy, w, h, text, color)
			if visible(cx - w / 2, cx + w / 2) then
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.Position = UDim2.fromScale(mx(cx) / aspect, cy)
				label.Size = UDim2.fromScale(w / aspect, h)
				label.Text = text
				label.TextColor3 = color
				label.TextScaled = true
				label.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
				label.Parent = canvas
			end
		end,
	}
	return p
end

-- Flag split into vertical segments (so the client can animate a wave).
-- Each segment face shows its slice of a full-width canvas, so the design
-- runs seamlessly across the segments.
function Architecture.flag(
	parent: Instance,
	poleTop: CFrame,
	width: number,
	height: number,
	design: FlagDesign,
	segments: number?
)
	local model = Kit.model(parent, "Flag")
	local n = segments or Architecture.FlagSegments
	local segW = width / n
	local pixelsPerStud = Architecture.FlagPixelsPerStud
	local aspect = width / height
	for i = 0, n - 1 do
		local cf = poleTop * CFrame.new(segW * (i + 0.5), -height / 2, 0)
		local seg = Kit.part(model, Vector3.new(segW, height, 0.12), cf, design.Field, Enum.Material.Fabric, {
			Name = "FlagSegment" .. (i + 1),
			Decor = true,
		})
		seg:SetAttribute("FlagIndex", i + 1)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Kit.surface(seg, face, pixelsPerStud, 1, 600)
			local canvas = Instance.new("Frame")
			canvas.Name = "Canvas"
			canvas.BorderSizePixel = 0
			canvas.BackgroundColor3 = design.Field
			canvas.Size = UDim2.new(n, 0, 1, 0)
			-- segments run from the pole along +X. On the Back face the GUI's
			-- x runs toward the fly, so segment i shows slice i; on the Front
			-- face it runs toward the pole, so the design is drawn mirrored
			-- and segment i shows slice n-1-i. Both sides then read correctly
			-- with the hoist at the pole, like a double-sided flag.
			local front = face == Enum.NormalId.Front
			local index = if front then (n - 1 - i) else i
			canvas.Position = UDim2.new(-index, 0, 0, 0)
			canvas.Parent = gui
			if design.Draw then
				local x0 = i / n * aspect
				design.Draw(painter(canvas, aspect, height * pixelsPerStud, x0, x0 + aspect / n, front))
			end
		end
	end
	Kit.anchor(model:FindFirstChild("FlagSegment1") :: BasePart, "Flag")
	return model
end

-- Flagpole with a flag. Returns the model.
function Architecture.flagpole(parent: Instance, base: CFrame, height: number, design: FlagDesign, flagWidth: number?)
	local model = Kit.model(parent, "Flagpole")
	Kit.post(model, base, 0.6, 1.6, W.ConcreteLight, Enum.Material.Concrete, { Name = "PoleBase" })
	Kit.post(model, base * CFrame.new(0, 0.6, 0), height, 0.45, W.Steel, Enum.Material.Metal, { Name = "Pole" })
	Kit.ball(
		model,
		0.8,
		base * CFrame.new(0, height + 0.9, 0),
		W.HazardYellow,
		Enum.Material.Metal,
		{ Name = "Finial", Decor = true }
	)
	-- halyard cleat and rope
	Kit.box(
		model,
		base,
		Vector3.new(0.2, 3.2, -0.09),
		Vector3.new(0.36, 3.8, 0.09),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "Cleat", Decor = true }
	)
	Kit.box(
		model,
		base,
		Vector3.new(0.26, 3.5, -0.03),
		Vector3.new(0.3, height + 0.2, 0.03),
		W.OffWhite,
		Enum.Material.Fabric,
		{ Name = "Halyard", Decor = true }
	)
	local w = flagWidth or 7
	Architecture.flag(model, base * CFrame.new(0.32, height + 0.2, 0), w, w * 0.62, design)
	model:SetAttribute("FlagDesign", design.Name)
	return model
end

-- Four-pointed star as stepped halves (light / shade), points on the axes.
local function compassStar(
	p: FlagPainter,
	cx: number,
	cy: number,
	reach: number,
	halfWidth: number,
	light: Color3,
	shade: Color3
)
	local steps = 9
	for _, dir in { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } do
		local dx, dy = dir[1], dir[2]
		-- perpendicular, clockwise from the point direction
		local px, py = -dy, dx
		for k = 0, steps - 1 do
			local r0, r1 = reach * k / steps, reach * (k + 1) / steps
			local hw = halfWidth * (1 - (k + 0.5) / steps)
			for _, half in { 1, -1 } do
				local ax, ay = cx + dx * r0, cy + dy * r0
				local bx, by = cx + dx * r1 + px * hw * half, cy + dy * r1 + py * hw * half
				p.rect(
					math.min(ax, bx),
					math.min(ay, by),
					math.max(ax, bx),
					math.max(ay, by),
					if half == 1 then light else shade
				)
			end
		end
	end
end

-- Sabre as a blade with a guard near the hilt (the bar starts vertical,
-- `degrees` turns it clockwise).
local function sabre(p: FlagPainter, cx: number, cy: number, length: number, degrees: number, color: Color3)
	p.bar(cx, cy, length, 0.035, degrees, color)
	local a = math.rad(degrees)
	local hx, hy = cx - math.sin(a) * length * 0.36, cy + math.cos(a) * length * 0.36
	p.bar(hx, hy, 0.11, 0.03, degrees + 90, color)
end

local WHITE = Color3.fromRGB(232, 230, 222)

Architecture.Flags = {
	-- NATO: white compass rose in a ring, with lines toward the edges
	Nato = {
		Field = Color3.fromRGB(24, 46, 96),
		Draw = function(p: FlagPainter)
			local cx, cy = p.Aspect / 2, 0.5
			p.ring(cx, cy, 0.19, 0.028, WHITE)
			local t = 0.014
			p.rect(cx - t, 0.05, cx + t, cy - 0.37, WHITE)
			p.rect(cx - t, cy + 0.37, cx + t, 0.95, WHITE)
			p.rect(0.07, cy - t, cx - 0.37, cy + t, WHITE)
			p.rect(cx + 0.37, cy - t, p.Aspect - 0.07, cy + t, WHITE)
			compassStar(p, cx, cy, 0.33, 0.075, WHITE, Color3.fromRGB(128, 146, 186))
		end,
	},
	-- West Germany (federal flag, 1949-1990)
	WestGermany = {
		Field = Color3.fromRGB(24, 24, 24),
		Draw = function(p: FlagPainter)
			p.rect(0, 1 / 3, p.Aspect, 2 / 3, Color3.fromRGB(190, 40, 36))
			p.rect(0, 2 / 3, p.Aspect, 1, Color3.fromRGB(230, 186, 40))
		end,
	},
	-- United States: 13 stripes, blue canton with 50 stars (6/5 rows)
	Usa = {
		Field = Color3.fromRGB(168, 40, 44),
		Draw = function(p: FlagPainter)
			local stripe = 1 / 13
			for i = 1, 12, 2 do
				p.rect(0, i * stripe, p.Aspect, (i + 1) * stripe, WHITE)
			end
			local cantonW, cantonH = p.Aspect * 0.4, stripe * 7
			p.rect(0, 0, cantonW, cantonH, Color3.fromRGB(34, 44, 92))
			local star = 0.028
			for row = 0, 8 do
				local count = if row % 2 == 0 then 6 else 5
				for col = 0, count - 1 do
					local fx = if row % 2 == 0 then (col + 0.5) / 6 else (col + 1) / 6
					local x = fx * cantonW
					local y = (row + 1) / 10 * cantonH
					p.rect(x - star / 2, y - star / 2, x + star / 2, y + star / 2, WHITE)
				end
			end
		end,
	},
	-- 11th Armored Cavalry Regiment ("Blackhorse", on the Fulda Gap line
	-- 1972-1994): cavalry colours scarlet over white, crossed sabres, 11
	Cavalry = {
		Field = WHITE,
		Draw = function(p: FlagPainter)
			local red = Color3.fromRGB(170, 34, 38)
			local cx = p.Aspect / 2
			p.rect(0, 0, p.Aspect, 0.5, red)
			sabre(p, cx, 0.3, 0.5, 34, WHITE)
			sabre(p, cx, 0.3, 0.5, -34, WHITE)
			p.text(cx, 0.13, 0.16, 0.14, "11", WHITE)
			p.text(cx, 0.75, p.Aspect * 0.8, 0.2, "BLACKHORSE", red)
		end,
	},
	-- Camp garrison flag (fictional): olive, pale bands and a chevron
	Base = {
		Field = Color3.fromRGB(78, 88, 54),
		Draw = function(p: FlagPainter)
			local pale = Color3.fromRGB(206, 196, 160)
			local cx = p.Aspect / 2
			p.rect(0, 0.1, p.Aspect, 0.17, pale)
			p.rect(0, 0.83, p.Aspect, 0.9, pale)
			p.bar(cx - 0.12, 0.5, 0.36, 0.09, 55, pale)
			p.bar(cx + 0.12, 0.5, 0.36, 0.09, -55, pale)
		end,
	},
} :: { [string]: FlagDesign }

for name, design in Architecture.Flags do
	design.Name = name
end

return Architecture
