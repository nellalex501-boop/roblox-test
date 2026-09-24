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
	Frame: Color3?,
	Sill: Color3?,
	Depth: number?,
	Lit: boolean?,
}

-- A row of windows on a wall face. The wall runs along local X at depth z,
-- with its outer face toward +Z (outward = 1) or -Z (outward = -1).
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
	local glass = s.Glass or W.Glass
	local sill = s.Sill or W.ConcreteLight
	local depth = s.Depth or 0.3
	local span = x1 - x0
	local gap = (span - count * windowWidth) / (count + 1)
	for i = 1, count do
		local cx = x0 + gap * i + windowWidth * (i - 0.5)
		local cz = z + outward * depth / 2
		Kit.part(
			parent,
			Vector3.new(windowWidth, y1 - y0, depth),
			frame * CFrame.new(cx, (y0 + y1) / 2, cz),
			if s.Lit then W.GlassLit else glass,
			Enum.Material.Glass,
			{ Name = "Window", Reflectance = 0.08, Shadow = false, Query = false }
		)
		Kit.part(
			parent,
			Vector3.new(windowWidth + 0.8, 0.35, depth + 0.5),
			frame * CFrame.new(cx, y0 - 0.175, z + outward * (depth + 0.5) / 2),
			sill,
			Enum.Material.Concrete,
			{ Name = "Sill", Shadow = false, Collide = false, Query = false }
		)
		if s.Frame then
			-- mullion splitting the pane
			Kit.part(
				parent,
				Vector3.new(0.3, y1 - y0, depth + 0.1),
				frame * CFrame.new(cx, (y0 + y1) / 2, z + outward * (depth + 0.1) / 2),
				s.Frame,
				Enum.Material.SmoothPlastic,
				{ Name = "Mullion", Decor = true }
			)
		end
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

-- Flat roof slab with a parapet around its edge.
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
	Kit.box(parent, frame, Vector3.new(x0, y, z0), Vector3.new(x1, y + 1, z1), W.ConcreteDark, Enum.Material.Concrete, {
		Name = "RoofSlab",
	})
	local t = 0.8
	local top = y + 1 + parapet
	local cap = capColor or W.ConcreteLight
	local walls = {
		{ Vector3.new(x0, y, z1 - t), Vector3.new(x1, top, z1) },
		{ Vector3.new(x0, y, z0), Vector3.new(x1, top, z0 + t) },
		{ Vector3.new(x0, y, z0), Vector3.new(x0 + t, top, z1) },
		{ Vector3.new(x1 - t, y, z0), Vector3.new(x1, top, z1) },
	}
	for _, w in walls do
		Kit.box(parent, frame, w[1], w[2], color, Enum.Material.Concrete, { Name = "Parapet" })
		Kit.box(
			parent,
			frame,
			Vector3.new(w[1].X - 0.15, top, w[1].Z - 0.15),
			Vector3.new(w[2].X + 0.15, top + 0.3, w[2].Z + 0.15),
			cap,
			Enum.Material.Concrete,
			{ Name = "Coping", Shadow = false }
		)
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

export type FlagDesign = {
	Field: Color3,
	Draw: ((Frame) -> ())?,
}

-- Flag split into vertical segments (so the client can animate a wave).
-- The design is drawn once per segment inside a full-width canvas offset
-- by the segment position, so the segments line up seamlessly.
function Architecture.flag(
	parent: Instance,
	poleTop: CFrame,
	width: number,
	height: number,
	design: FlagDesign,
	segments: number?
)
	local model = Kit.model(parent, "Flag")
	local n = segments or 3
	local segW = width / n
	local pixelsPerStud = 16
	for i = 0, n - 1 do
		local cf = poleTop * CFrame.new(segW * (i + 0.5), -height / 2, 0)
		local seg = Kit.part(model, Vector3.new(segW, height, 0.12), cf, design.Field, Enum.Material.Fabric, {
			Name = "FlagSegment" .. (i + 1),
			Decor = true,
		})
		seg:SetAttribute("FlagIndex", i + 1)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Kit.surface(seg, face, pixelsPerStud, 1, 420)
			local canvas = Instance.new("Frame")
			canvas.Name = "Canvas"
			canvas.BorderSizePixel = 0
			canvas.BackgroundColor3 = design.Field
			canvas.Size = UDim2.new(n, 0, 1, 0)
			-- the back face is mirrored, so walk the canvas the other way
			local index = if face == Enum.NormalId.Front then i else (n - 1 - i)
			canvas.Position = UDim2.new(-index, 0, 0, 0)
			canvas.Parent = gui
			if design.Draw then
				design.Draw(canvas)
			end
		end
	end
	Kit.anchor(model.PrimaryPart or (model:FindFirstChild("FlagSegment1") :: BasePart), "Flag")
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
	local w = flagWidth or 7
	Architecture.flag(model, base * CFrame.new(0.25, height + 0.2, 0), w, w * 0.62, design)
	return model
end

-- Flag designs drawn with GUI frames (no image assets needed).
local function band(canvas: Frame, y: number, h: number, color: Color3)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = UDim2.fromScale(0, y)
	f.Size = UDim2.fromScale(1, h)
	f.Parent = canvas
end

local function square(parent: Instance, scale: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(scale, scale)
	f.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = f
	return f
end

local function diamond(canvas: Frame, color: Color3, scale: number)
	local d = square(canvas, scale)
	d.Rotation = 45
	d.BackgroundTransparency = 0
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
end

-- NATO-style compass: ring with four points.
local function compass(canvas: Frame, color: Color3)
	local ring = square(canvas, 0.42)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 5
	stroke.Parent = ring
	for _, angle in { 0, 90 } do
		local holder = square(canvas, 0.95)
		holder.Rotation = angle
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = color
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(0.07, 0.9)
		bar.Parent = holder
	end
end

-- Military chevron (two bars meeting in a point).
local function chevron(canvas: Frame, color: Color3)
	for _, sign in { -1, 1 } do
		local holder = square(canvas, 0.7)
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = color
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5 + sign * 0.2, 0.5)
		bar.Size = UDim2.fromScale(0.5, 0.16)
		bar.Rotation = sign * 35
		bar.Parent = holder
	end
end

Architecture.Flags = {
	Nato = {
		Field = Color3.fromRGB(34, 52, 94),
		Draw = function(canvas: Frame)
			compass(canvas, Color3.fromRGB(230, 230, 222))
		end,
	},
	Pact = {
		Field = Color3.fromRGB(138, 42, 36),
		Draw = function(canvas: Frame)
			band(canvas, 0.08, 0.07, Color3.fromRGB(214, 170, 72))
			band(canvas, 0.85, 0.07, Color3.fromRGB(214, 170, 72))
			diamond(canvas, Color3.fromRGB(214, 170, 72), 0.3)
		end,
	},
	WestGermany = {
		Field = Color3.fromRGB(24, 24, 24),
		Draw = function(canvas: Frame)
			band(canvas, 1 / 3, 1 / 3, Color3.fromRGB(190, 40, 36))
			band(canvas, 2 / 3, 1 / 3, Color3.fromRGB(230, 186, 40))
		end,
	},
	Base = {
		Field = Color3.fromRGB(78, 88, 54),
		Draw = function(canvas: Frame)
			band(canvas, 0.1, 0.07, Color3.fromRGB(206, 196, 160))
			band(canvas, 0.83, 0.07, Color3.fromRGB(206, 196, 160))
			chevron(canvas, Color3.fromRGB(206, 196, 160))
		end,
	},
	Regiment = {
		Field = Color3.fromRGB(122, 44, 40),
		Draw = function(canvas: Frame)
			band(canvas, 0.4, 0.2, Color3.fromRGB(206, 196, 160))
		end,
	},
	Signals = {
		Field = Color3.fromRGB(58, 84, 110),
		Draw = function(canvas: Frame)
			band(canvas, 0, 0.5, Color3.fromRGB(196, 184, 150))
		end,
	},
}

return Architecture
