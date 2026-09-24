--!strict
-- Shared building blocks for interactive stations: CRT monitors with
-- phosphor screens, console desks, placards and hanging signs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)

local W = Theme.World
local Common = {}

Common.CasingColor = Color3.fromRGB(184, 178, 160)
Common.Phosphor = Color3.fromRGB(150, 206, 132)
Common.Amber = Color3.fromRGB(232, 170, 80)

-- A screen surface with the CRT look. Returns the SurfaceGui and a content
-- frame inset from the bezel. `role` becomes the SurfaceGui name so
-- services/clients can find and update it.
function Common.screen(part: BasePart, role: string, pixelsPerStud: number?): (SurfaceGui, Frame)
	local gui = Kit.surface(part, Enum.NormalId.Front, pixelsPerStud or 60, 0, 120)
	gui.Name = role
	gui.Brightness = 1.4
	local bg = Kit.frame(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), W.Screen)
	bg.Name = "Glass"
	local vignette = Instance.new("UIGradient")
	vignette.Color = ColorSequence.new(Color3.fromRGB(34, 48, 38), Color3.fromRGB(12, 16, 14))
	vignette.Rotation = 90
	vignette.Parent = bg
	local content = Kit.frame(bg, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.88), W.Screen, 1)
	content.Name = "Content"
	return gui, content
end

-- 1980s CRT monitor standing at `cf` (bottom centre, front facing the
-- viewer = +Z of cf after facing-out). Returns the screen part.
function Common.crt(parent: Instance, cf: CFrame, width: number, role: string, color: Color3?): Part
	local model = Kit.model(parent, "CRT_" .. role)
	local h = width * 0.82
	local d = width * 0.85
	Kit.part(
		model,
		Vector3.new(width, h, d),
		cf * CFrame.new(0, h / 2, 0),
		color or Common.CasingColor,
		Enum.Material.SmoothPlastic,
		{
			Name = "Casing",
		}
	)
	Kit.part(
		model,
		Vector3.new(width * 0.7, h * 0.7, d * 0.4),
		cf * CFrame.new(0, h / 2, -d * 0.6),
		color or Common.CasingColor,
		Enum.Material.SmoothPlastic,
		{
			Name = "Tube",
			Decor = true,
		}
	)
	local screen = Kit.part(
		model,
		Vector3.new(width * 0.82, h * 0.72, 0.08),
		cf * CFrame.new(0, h * 0.54, d / 2 + 0.04) * CFrame.Angles(0, math.pi, 0),
		W.Screen,
		Enum.Material.SmoothPlastic,
		{ Name = "Screen", Decor = true }
	)
	Kit.anchor(screen, "CrtFlicker")
	return screen
end

-- Console desk with a slanted control top, front toward +Z of `cf`.
function Common.console(parent: Instance, cf: CFrame, width: number, color: Color3?): Part
	local c = color or Color3.fromRGB(70, 78, 66)
	local desk = Kit.part(
		parent,
		Vector3.new(width, 3.2, 3),
		cf * CFrame.new(0, 1.6, -1.5),
		c,
		Enum.Material.Metal,
		{ Name = "Console" }
	)
	-- slanted top: high edge at the back (wedge back is +Z, so turn it round)
	Kit.wedge(
		parent,
		Vector3.new(width, 0.9, 2.6),
		cf * CFrame.new(0, 3.65, -1.6) * CFrame.Angles(0, math.pi, 0),
		c,
		Enum.Material.Metal,
		{
			Name = "ConsoleTop",
		}
	)
	Kit.part(
		parent,
		Vector3.new(width - 0.6, 0.12, 1.1),
		cf * CFrame.new(0, 3.62, -0.7) * CFrame.Angles(math.rad(19), 0, 0),
		W.Charcoal,
		nil,
		{
			Name = "Keyboard",
			Decor = true,
		}
	)
	-- indicator lamps
	for i = 1, math.floor(width / 1.6) do
		local lamp = Kit.part(
			parent,
			Vector3.new(0.3, 0.12, 0.3),
			cf * CFrame.new(-width / 2 + i * 1.5, 3.95, -2.3) * CFrame.Angles(math.rad(19), 0, 0),
			if i % 3 == 0 then W.LampRed elseif i % 3 == 1 then Common.Amber else Common.Phosphor,
			Enum.Material.Neon,
			{ Name = "Lamp", Decor = true }
		)
		if i % 2 == 0 then
			Kit.anchor(lamp, "BlinkSlow")
		end
	end
	return desk
end

-- Hanging sign suspended from the ceiling on two rods, facing +Z of `cf`
-- (cf is the sign centre).
function Common.hangingSign(
	parent: Instance,
	cf: CFrame,
	size: Vector2,
	ceilingY: number,
	title: string,
	style: Kit.SignStyle?
): Part
	local board = Kit.sign(parent, cf * CFrame.Angles(0, math.pi, 0), size, title, style)
	local top = cf.Position.Y + size.Y / 2
	local rodLength = ceilingY - top
	if rodLength > 0.2 then
		for _, x in { -size.X * 0.38, size.X * 0.38 } do
			Kit.part(
				parent,
				Vector3.new(0.15, rodLength, 0.15),
				cf * CFrame.new(x, size.Y / 2 + rodLength / 2, 0),
				W.SteelDark,
				Enum.Material.Metal,
				{
					Name = "Rod",
					Decor = true,
				}
			)
		end
	end
	return board
end

-- Small lectern with a slanted placard facing +Z of `cf`.
function Common.placard(parent: Instance, cf: CFrame, title: string, subtitle: string?, stripe: Color3?): Part
	local model = Kit.model(parent, "Placard")
	Kit.part(
		model,
		Vector3.new(0.5, 3.2, 0.5),
		cf * CFrame.new(0, 1.6, 0),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "Stand" }
	)
	Kit.part(
		model,
		Vector3.new(1.6, 0.2, 1.6),
		cf * CFrame.new(0, 0.1, 0),
		W.SteelDark,
		Enum.Material.Metal,
		{ Name = "Base" }
	)
	local plate = Kit.sign(
		model,
		cf * CFrame.new(0, 3.5, 0.2) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.Angles(0, math.pi, 0),
		Vector2.new(3.2, 1.8),
		title,
		{
			Background = W.Charcoal,
			Subtitle = subtitle,
			Stripe = stripe,
			PixelsPerStud = 60,
			Depth = 0.15,
			MaxDistance = 60,
		}
	)
	plate.Name = "PlacardPlate"
	return plate
end

-- Text line helper inside screens/boards.
function Common.line(
	parent: Instance,
	name: string,
	text: string,
	y: number,
	h: number,
	color: Color3,
	font: Font?,
	align: Enum.TextXAlignment?
): TextLabel
	return Kit.text(parent, {
		Name = name,
		Text = text,
		Color = color,
		Font = font or Theme.font("Mono", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(0, y),
		Size = UDim2.fromScale(1, h),
		XAlign = align or Enum.TextXAlignment.Left,
	})
end

return Common
