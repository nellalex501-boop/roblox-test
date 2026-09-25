--!strict
-- Primitive helpers for building the lobby from anchored parts.
--
-- Everything is anchored with CanTouch off. Pass Decor = true for small
-- props: no collision, no raycasts, no touch, no shadow (cheap to render and
-- invisible to physics). Positions are usually given in a zone frame (see
-- Layout.frame); `frame * CFrame.new(localPos)` gives the world CFrame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

export type Opts = {
	Name: string?,
	Collide: boolean?,
	Shadow: boolean?,
	Query: boolean?,
	Transparency: number?,
	Reflectance: number?,
	Decor: boolean?,
}

export type Opening = {
	Center: number, -- distance along the wall from its start point
	Width: number,
	Bottom: number, -- height above the wall base
	Top: number,
}

export type TextProps = {
	Text: string,
	Color: Color3?,
	Font: Font?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Scaled: boolean?,
	TextSize: number?,
	MaxTextSize: number?,
	Wrapped: boolean?,
	Rotation: number?,
	ZIndex: number?,
	Name: string?,
}

local Kit = {}

local UP = Vector3.new(0, 1, 0)

local function apply(part: BasePart, color: Color3, material: Enum.Material?, opts: Opts?)
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if opts then
		if opts.Name then
			part.Name = opts.Name
		end
		if opts.Decor then
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		end
		if opts.Collide ~= nil then
			part.CanCollide = opts.Collide
		end
		if opts.Shadow ~= nil then
			part.CastShadow = opts.Shadow
		end
		if opts.Query ~= nil then
			part.CanQuery = opts.Query
		end
		if opts.Transparency then
			part.Transparency = opts.Transparency
		end
		if opts.Reflectance then
			part.Reflectance = opts.Reflectance
		end
	end
end

function Kit.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Kit.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Kit.part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	opts: Opts?
): Part
	local part = Instance.new("Part")
	part.Name = "Part"
	apply(part, color, material, opts)
	part.Size = size
	part.CFrame = cf
	part.Parent = parent
	return part
end

-- Roblox wedge: full bottom and back (+Z) faces, slope descending toward the
-- front (-Z). Rotate the CFrame to aim the slope.
function Kit.wedge(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	opts: Opts?
): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = "Wedge"
	apply(part, color, material, opts)
	part.Size = size
	part.CFrame = cf
	part.Parent = parent
	return part
end

-- Cylinder whose axis runs along cf.RightVector (Roblox cylinder convention).
function Kit.cylinder(
	parent: Instance,
	length: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	opts: Opts?
): Part
	local part = Instance.new("Part")
	part.Name = "Cylinder"
	part.Shape = Enum.PartType.Cylinder
	apply(part, color, material, opts)
	part.Size = Vector3.new(length, diameter, diameter)
	part.CFrame = cf
	part.Parent = parent
	return part
end

-- Upright cylinder standing on `base` (bottom centre), axis along world/frame Y.
function Kit.post(
	parent: Instance,
	base: CFrame,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	opts: Opts?
): Part
	local cf = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	return Kit.cylinder(parent, height, diameter, cf, color, material, opts)
end

function Kit.ball(
	parent: Instance,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	opts: Opts?
): Part
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Shape = Enum.PartType.Ball
	apply(part, color, material, opts)
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.CFrame = cf
	part.Parent = parent
	return part
end

-- Box between two corners given in `frame` local space.
function Kit.box(
	parent: Instance,
	frame: CFrame,
	a: Vector3,
	b: Vector3,
	color: Color3,
	material: Enum.Material?,
	opts: Opts?
): Part
	local minV = a:Min(b)
	local maxV = a:Max(b)
	local size = maxV - minV
	local center = (minV + maxV) / 2
	return Kit.part(parent, size, frame * CFrame.new(center), color, material, opts)
end

-- Rotates a local CFrame so that its front (-Z / NormalId.Front) faces the
-- zone's outside (+Z of the zone frame).
function Kit.facingOut(frame: CFrame, localPos: Vector3): CFrame
	return frame * CFrame.new(localPos) * CFrame.Angles(0, math.pi, 0)
end

-- Wall along the segment p0 -> p1 (local XZ of `frame`), from height y0 to
-- y1, split around rectangular openings (doors/windows).
function Kit.wall(
	parent: Instance,
	frame: CFrame,
	p0: Vector2,
	p1: Vector2,
	y0: number,
	y1: number,
	thickness: number,
	color: Color3,
	material: Enum.Material?,
	openings: { Opening }?,
	opts: Opts?
): { BasePart }
	local parts = {}
	local delta = p1 - p0
	local length = delta.Magnitude
	if length < 0.05 then
		return parts
	end
	local dir2 = delta / length
	local dir = Vector3.new(dir2.X, 0, dir2.Y)
	local height = y1 - y0

	local function piece(a: number, b: number, bottom: number, top: number)
		if b - a < 0.05 or top - bottom < 0.05 then
			return
		end
		local mid = (a + b) / 2
		local center2 = p0 + dir2 * mid
		local pos = Vector3.new(center2.X, y0 + (bottom + top) / 2, center2.Y)
		local cf = frame * CFrame.fromMatrix(pos, dir, UP)
		table.insert(parts, Kit.part(parent, Vector3.new(b - a, top - bottom, thickness), cf, color, material, opts))
	end

	local sorted: { Opening } = table.clone(openings or {})
	table.sort(sorted, function(l: Opening, r: Opening)
		return l.Center < r.Center
	end)

	local cursor = 0
	for _, opening in sorted do
		local a = math.clamp(opening.Center - opening.Width / 2, 0, length)
		local b = math.clamp(opening.Center + opening.Width / 2, 0, length)
		piece(cursor, a, 0, height)
		piece(a, b, 0, math.min(opening.Bottom, height))
		piece(a, b, math.max(opening.Top, 0), height)
		cursor = b
	end
	piece(cursor, length, 0, height)
	return parts
end

-- SurfaceGui on a part face, sized in pixels per stud.
function Kit.surface(
	part: BasePart,
	face: Enum.NormalId,
	pixelsPerStud: number?,
	lightInfluence: number?,
	maxDistance: number?
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Surface" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	-- painted surfaces take the scene lighting (1); screens pass 0
	gui.LightInfluence = lightInfluence or 1
	gui.ClipsDescendants = true
	-- stop rendering small labels when far away (0 = always render)
	gui.MaxDistance = maxDistance or 0
	gui.Parent = part
	return gui
end

function Kit.text(parent: Instance, props: TextProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Position = props.Position or UDim2.fromScale(0, 0)
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.Text = props.Text
	label.TextColor3 = props.Color or Theme.World.OffWhite
	label.FontFace = props.Font or Theme.font("Header", Enum.FontWeight.Bold)
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	label.TextWrapped = if props.Wrapped == nil then true else props.Wrapped
	label.Rotation = props.Rotation or 0
	label.ZIndex = props.ZIndex or 1
	if props.Scaled == false then
		label.TextScaled = false
		label.TextSize = props.TextSize or 24
	else
		label.TextScaled = true
		if props.MaxTextSize then
			local constraint = Instance.new("UITextSizeConstraint")
			constraint.MaxTextSize = props.MaxTextSize
			constraint.Parent = label
		end
	end
	label.Parent = parent
	return label
end

function Kit.frame(parent: Instance, position: UDim2, size: UDim2, color: Color3, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.Parent = parent
	return frame
end

export type SignStyle = {
	Background: Color3?,
	TextColor: Color3?,
	Stripe: Color3?,
	Font: Font?,
	Subtitle: string?,
	Depth: number?,
	PixelsPerStud: number?,
	Border: Color3?,
	MaxDistance: number?,
}

-- Military facility sign: a flat board with a title, optional subtitle and a
-- coloured stripe. `cf` places the board centre; its front faces the reader.
function Kit.sign(parent: Instance, cf: CFrame, size: Vector2, title: string, style: SignStyle?): Part
	local s: SignStyle = style or {}
	local background = s.Background or Theme.World.SignGreen
	local board = Kit.part(
		parent,
		Vector3.new(size.X, size.Y, s.Depth or 0.4),
		cf,
		background,
		Enum.Material.SmoothPlastic,
		{ Name = "Sign" }
	)
	-- landmark signs (3+ studs tall) always render; entrance and bay signs
	-- reach 250+ studs (well past the spawn); small plates are culled only
	-- where they are too small to read anyway
	local maxDistance = s.MaxDistance
		or (if size.Y >= 3 then 0 elseif size.Y >= 1.2 then math.max(250, size.Y * 120) else math.max(80, size.Y * 90))
	-- painted: lit by the scene like the board it is painted on
	local gui = Kit.surface(board, Enum.NormalId.Front, s.PixelsPerStud or 40, 1, maxDistance)
	local border = s.Border
	if border then
		local stroke = Kit.frame(gui, UDim2.new(0, 6, 0, 6), UDim2.new(1, -12, 1, -12), background, 1)
		local uiStroke = Instance.new("UIStroke")
		uiStroke.Color = border
		uiStroke.Thickness = 4
		uiStroke.Parent = stroke
	end
	local titleHeight = if s.Subtitle then 0.62 else 0.8
	local stripe = s.Stripe
	if stripe then
		Kit.frame(gui, UDim2.fromScale(0, 0.9), UDim2.fromScale(1, 0.1), stripe)
		titleHeight -= 0.06
	end
	Kit.text(gui, {
		Name = "Title",
		Text = title,
		Color = s.TextColor,
		Font = s.Font,
		Position = UDim2.fromScale(0.05, 0.08),
		Size = UDim2.fromScale(0.9, titleHeight),
	})
	if s.Subtitle then
		Kit.text(gui, {
			Name = "Subtitle",
			Text = s.Subtitle,
			Color = s.TextColor or Theme.World.OffWhite,
			Font = Theme.font("Body", Enum.FontWeight.Medium),
			Position = UDim2.fromScale(0.05, 0.08 + titleHeight),
			Size = UDim2.fromScale(0.9, 0.22),
		})
	end
	return board
end

-- Mark a part as a world anchor the client can find (ambient sound/animation).
function Kit.anchor(part: BasePart, role: string, value: string?)
	part:SetAttribute("AmbientRole", role)
	if value then
		part:SetAttribute("AmbientValue", value)
	end
	part:AddTag("LobbyAmbient")
end

return Kit
