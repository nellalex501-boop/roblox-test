--!strict
-- UI building blocks for every lobby panel and the HUD: one visual
-- language (dark command-terminal panels, muted amber accents, stencil
-- headers, mono read-outs) matching the RTS HUD. All sizes are design
-- pixels at 1x; the root ScreenGui applies a UIScale for the device.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Theme = require(Lobby:WaitForChild("Config"):WaitForChild("Theme"))

local UI = Theme.UI

local Kit = {}

Kit.Colors = UI
Kit.Text = {
	Title = 26,
	Section = 18,
	Body = 15,
	Small = 13,
	Tiny = 11,
}

Kit.Fonts = {
	Header = Theme.font("Header", Enum.FontWeight.Bold),
	HeaderLight = Theme.font("Header", Enum.FontWeight.Medium),
	Body = Theme.font("Body"),
	BodyBold = Theme.font("Body", Enum.FontWeight.Bold),
	Mono = Theme.font("Mono"),
	MonoBold = Theme.font("Mono", Enum.FontWeight.Bold),
	Document = Theme.font("Document"),
	Marker = Theme.font("Marker"),
}

type Props = { [string]: any }

-- Creates an instance, applies properties (Parent last) and children.
function Kit.new(className: string, props: Props?, children: { Instance }?): any
	local inst = Instance.new(className) :: any
	local parent = nil
	local given: Props = props or {}
	for key, value in given do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	local kids: { Instance } = children or {}
	for _, child in kids do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(parent: Instance, radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 3), Parent = parent })
end

function Kit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or UI.BorderDim,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.padding(parent: Instance, left: number, right: number?, top: number?, bottom: number?): UIPadding
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right or left),
		PaddingTop = UDim.new(0, top or left),
		PaddingBottom = UDim.new(0, bottom or top or left),
		Parent = parent,
	})
end

function Kit.list(
	parent: Instance,
	direction: Enum.FillDirection?,
	gap: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Kit.frame(parent: Instance?, props: Props?): Frame
	local p: Props = {
		BackgroundColor3 = UI.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}
	local given: Props = props or {}
	for key, value in given do
		p[key] = value
	end
	p.Parent = parent
	return Kit.new("Frame", p)
end

-- Transparent layout container.
function Kit.box(parent: Instance?, props: Props?): Frame
	local p: Props = { BackgroundTransparency = 1 }
	local given: Props = props or {}
	for key, value in given do
		p[key] = value
	end
	return Kit.frame(parent, p)
end

function Kit.text(parent: Instance?, props: Props?): TextLabel
	local p: Props = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = Kit.Fonts.Body,
		TextSize = Kit.Text.Body,
		TextColor3 = UI.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
	}
	local given: Props = props or {}
	for key, value in given do
		p[key] = value
	end
	p.Parent = parent
	return Kit.new("TextLabel", p)
end

-- Section heading: stencil caps with a thin rule.
function Kit.heading(parent: Instance, text: string, order: number?): Frame
	local holder = Kit.box(parent, { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order or 0, Name = "Heading" })
	Kit.text(holder, {
		Name = "Label",
		Text = text,
		FontFace = Kit.Fonts.Header,
		TextSize = Kit.Text.Section,
		TextColor3 = UI.Accent,
		Size = UDim2.new(1, 0, 1, -3),
	})
	Kit.frame(holder, {
		Name = "Rule",
		BackgroundColor3 = UI.BorderDim,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
	})
	return holder
end

-- Label/value line (e.g. "SIZE ........ 2.4 x 2.4 KM").
function Kit.field(parent: Instance, label: string, value: string, order: number?): (Frame, TextLabel)
	local row = Kit.box(parent, { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order or 0, Name = "Field_" .. label })
	Kit.text(row, {
		Name = "Label",
		Text = label,
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(0.45, 0, 1, 0),
	})
	local valueLabel = Kit.text(row, {
		Name = "Value",
		Text = value,
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.45, 0),
		Size = UDim2.new(0.55, 0, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	return row, valueLabel
end

export type ButtonStyle = "primary" | "secondary" | "ghost" | "danger"

local BUTTON_COLORS: { [string]: { bg: Color3, hover: Color3, text: Color3, stroke: Color3? } } = {
	primary = { bg = UI.Accent, hover = Color3.fromRGB(230, 184, 102), text = UI.Backdrop },
	secondary = { bg = UI.PanelRaised, hover = UI.PanelHover, text = UI.Text, stroke = UI.Border },
	ghost = { bg = UI.Panel, hover = UI.PanelRaised, text = UI.TextDim, stroke = UI.BorderDim },
	danger = {
		bg = Color3.fromRGB(96, 44, 36),
		hover = Color3.fromRGB(122, 56, 46),
		text = UI.Text,
		stroke = UI.Danger,
	},
}

Kit.onClick = nil :: (() -> ())?

function Kit.button(parent: Instance?, text: string, style: ButtonStyle?, onClick: (() -> ())?): TextButton
	local colors = BUTTON_COLORS[style or "secondary"]
	local button: TextButton = Kit.new("TextButton", {
		Name = "Button",
		AutoButtonColor = false,
		BackgroundColor3 = colors.bg,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 160, 0, 34),
		Text = text,
		FontFace = Kit.Fonts.Header,
		TextSize = 16,
		TextColor3 = colors.text,
		Selectable = true,
		Parent = parent,
	})
	button:SetAttribute("Style", style or "secondary")
	Kit.corner(button, 2)
	if colors.stroke then
		Kit.stroke(button, colors.stroke)
	end
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") ~= true then
			button.BackgroundColor3 = colors.hover
		end
	end)
	button.MouseLeave:Connect(function()
		if button:GetAttribute("Disabled") ~= true then
			button.BackgroundColor3 = colors.bg
		end
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") == true then
			return
		end
		local click = Kit.onClick
		if click then
			click()
		end
		if onClick then
			onClick()
		end
	end)
	return button
end

function Kit.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	local colors = BUTTON_COLORS[(button:GetAttribute("Style") :: string?) or "secondary"] or BUTTON_COLORS.secondary
	button.BackgroundColor3 = if enabled then colors.bg else UI.Panel
	button.TextColor3 = if enabled then colors.text else UI.TextFaint
	button.AutoButtonColor = false
	button.Selectable = enabled
end

-- Horizontal progress bar. Returns the bar; update with Kit.setProgress.
function Kit.progress(parent: Instance, fraction: number, color: Color3?, height: number?): Frame
	local bar = Kit.frame(parent, {
		Name = "Progress",
		BackgroundColor3 = UI.Background,
		Size = UDim2.new(1, 0, 0, height or 6),
	})
	Kit.stroke(bar, UI.BorderDim)
	Kit.frame(bar, {
		Name = "Fill",
		BackgroundColor3 = color or UI.Accent,
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
	})
	return bar
end

function Kit.setProgress(bar: Instance, fraction: number)
	local fill = bar:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
end

-- 10-segment rating bar used for unit stats.
function Kit.segments(parent: Instance, value: number, max: number?, color: Color3?): Frame
	local total = max or 10
	local bar = Kit.box(parent, { Name = "Segments", Size = UDim2.new(1, 0, 0, 10) })
	Kit.list(bar, Enum.FillDirection.Horizontal, 3)
	for i = 1, total do
		Kit.frame(bar, {
			Name = "Seg" .. i,
			LayoutOrder = i,
			BackgroundColor3 = if i <= value then (color or UI.Phosphor) else UI.PanelRaised,
			Size = UDim2.new(1 / total, -3, 1, 0),
		})
	end
	return bar
end

function Kit.badge(parent: Instance, text: string, color: Color3?, order: number?): TextLabel
	local label = Kit.text(parent, {
		Name = "Badge",
		Text = " " .. text .. " ",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		TextColor3 = color or UI.Accent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = order or 0,
	})
	Kit.stroke(label, color or UI.Accent, 1, 0.3)
	Kit.corner(label, 2)
	Kit.padding(label, 4, 4, 0, 0)
	return label
end

function Kit.divider(parent: Instance, order: number?): Frame
	return Kit.frame(parent, {
		Name = "Divider",
		BackgroundColor3 = UI.BorderDim,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = order or 0,
	})
end

-- Vertical scrolling list with a list layout.
function Kit.scroll(parent: Instance, props: Props?, gap: number?): ScrollingFrame
	local p: Props = {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = UI.Border,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Selectable = false,
	}
	local given: Props = props or {}
	for key, value in given do
		p[key] = value
	end
	p.Parent = parent
	local scroll: ScrollingFrame = Kit.new("ScrollingFrame", p)
	Kit.list(scroll, Enum.FillDirection.Vertical, gap or 6)
	Kit.padding(scroll, 0, 8, 0, 4)
	return scroll
end

-- Removes generated children, keeping layout helpers.
function Kit.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
end

-- Selectable list row (maps, units, boards...).
function Kit.row(parent: Instance, height: number, order: number?, onClick: (() -> ())?): TextButton
	local row: TextButton = Kit.new("TextButton", {
		Name = "Row",
		AutoButtonColor = false,
		BackgroundColor3 = UI.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Text = "",
		LayoutOrder = order or 0,
		Selectable = true,
		Parent = parent,
	})
	Kit.stroke(row, UI.BorderDim)
	row.MouseEnter:Connect(function()
		if row:GetAttribute("Selected") ~= true then
			row.BackgroundColor3 = UI.PanelRaised
		end
	end)
	row.MouseLeave:Connect(function()
		if row:GetAttribute("Selected") ~= true then
			row.BackgroundColor3 = UI.Panel
		end
	end)
	if onClick then
		row.Activated:Connect(function()
			local click = Kit.onClick
			if click then
				click()
			end
			onClick()
		end)
	end
	return row
end

function Kit.setSelected(row: GuiObject, selected: boolean)
	row:SetAttribute("Selected", selected)
	row.BackgroundColor3 = if selected then UI.PanelHover else UI.Panel
	local stroke = row:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then UI.Accent else UI.BorderDim
	end
end

-- Two-column body: left list, right detail (fractions of the width).
function Kit.columns(parent: Instance, leftWidth: number, gap: number?): (Frame, Frame)
	local g = gap or 14
	local left = Kit.box(parent, { Name = "Left", Size = UDim2.new(0, leftWidth, 1, 0) })
	local right = Kit.box(parent, {
		Name = "Right",
		Position = UDim2.new(0, leftWidth + g, 0, 0),
		Size = UDim2.new(1, -(leftWidth + g), 1, 0),
	})
	return left, right
end

return Kit
