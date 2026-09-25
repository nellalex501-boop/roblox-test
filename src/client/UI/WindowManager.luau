--!strict
-- Owns the lobby ScreenGui and the single open panel.
--
-- * One panel at a time, opened by the interaction controller with the
--   station context (kind, id, tab, part).
-- * Closes with the ✕ button, the X key or gamepad B, when the Roblox menu
--   opens (Esc belongs to Roblox), or when the player walks away from the
--   station it was opened at.
-- * While a panel is open the lobby's proximity prompts are hidden (so E /
--   ButtonX cannot re-trigger a station behind the panel).
-- * Short transitions (fade + slide), device scaling via UIScale, gamepad
--   selection and LB/RB tab switching.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Signal = require(Lobby:WaitForChild("Util"):WaitForChild("Signal"))
local Kit = require(script.Parent.Kit)
local Sound = require(script.Parent.Sound)

local UI = Kit.Colors

export type Context = {
	kind: string?,
	id: string?,
	tab: string?,
	part: BasePart?,
	range: number?,
}

export type Shell = {
	name: string,
	root: CanvasGroup,
	body: Frame,
	title: TextLabel,
	code: TextLabel,
	footer: TextLabel,
	tabBar: Frame?,
	tabButtons: { [string]: TextButton },
	tab: string?,
	context: Context,
	panel: Panel,
}

export type Panel = {
	title: string,
	code: string,
	tabs: { string }?,
	size: Vector2?,
	-- "center" (default), "right" (docked, leaves the view free, e.g. the
	-- vehicle inspection sheet) or "fullscreen" (the panel lays out the
	-- whole screen itself over the live view, e.g. the showroom)
	dock: string?,
	build: (shell: Shell) -> (),
	open: (shell: Shell, context: Context) -> (),
	selectTab: ((shell: Shell, tab: string) -> ())?,
	close: ((shell: Shell) -> ())?,
}

local WindowManager = {}

WindowManager.DesignSize = Vector2.new(1280, 720)
WindowManager.WalkAwaySlack = 8
WindowManager.opened = Signal.new() :: Signal.Signal<string, Context>
WindowManager.closed = Signal.new() :: Signal.Signal<string>

local panels: { [string]: Panel } = {}
local shells: { [string]: Shell } = {}
local current: Shell? = nil
local gui: ScreenGui? = nil
local layers: { [string]: Frame } = {}
local backdrop: Frame? = nil
local scale: UIScale? = nil

local FADE_IN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function WindowManager.register(name: string, panel: Panel)
	panels[name] = panel
end

function WindowManager.gui(): ScreenGui
	assert(gui, "WindowManager.start() first")
	return gui
end

-- "Hud" (bottom), "Panels", "Overlay", "Toasts" (top).
function WindowManager.layer(name: string): Frame
	local layer = layers[name]
	assert(layer, "unknown layer " .. name)
	return layer
end

function WindowManager.current(): string?
	return if current then current.name else nil
end

function WindowManager.isOpen(): boolean
	return current ~= nil
end

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) == "Gamepad"
end

WindowManager.CloseKey = Enum.KeyCode.X

-- Key hint next to the ✕ button (touch has no key).
local function closeHint(): string
	if usingGamepad() then
		return "[B]"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return ""
	end
	return "[" .. WindowManager.CloseKey.Name .. "]"
end

-- Square ✕ close button (drawn with two bars, no font glyph needed) with
-- the key hint to its left. Named "Close".
function WindowManager.closeButton(parent: Instance): TextButton
	local button = Kit.button(parent, "", "ghost", function()
		WindowManager.close()
	end)
	button.Name = "Close"
	button.Size = UDim2.fromOffset(36, 36)
	for _, angle in { 45, -45 } do
		Kit.frame(button, {
			Name = "Bar",
			BackgroundColor3 = UI.Text,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(20, 2),
			Rotation = angle,
		})
	end
	Kit.text(button, {
		Name = "KeyHint",
		Text = closeHint(),
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -8, 0.5, 0),
		Size = UDim2.fromOffset(60, 20),
	})
	return button
end

local function firstSelectable(root: Instance): GuiObject?
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible and d:GetAttribute("Disabled") ~= true then
			return d
		end
	end
	return nil
end

local function styleTab(button: TextButton, active: boolean)
	button.TextColor3 = if active then UI.Accent else UI.TextDim
	button.BackgroundColor3 = if active then UI.PanelRaised else UI.Panel
	local line = button:FindFirstChild("Underline")
	if line and line:IsA("Frame") then
		line.Visible = active
	end
end

function WindowManager.setTab(shell: Shell, tab: string)
	shell.tab = tab
	for name, button in shell.tabButtons do
		styleTab(button, name == tab)
	end
	local select = shell.panel.selectTab
	if select then
		select(shell, tab)
	end
end

-- Full-screen shell: a transparent layer the panel lays out itself.
local function buildFullscreenShell(name: string, panel: Panel): Shell
	local root: CanvasGroup = Kit.new("CanvasGroup", {
		Name = "Panel_" .. name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = WindowManager.layer("Panels"),
	})
	local hidden = { Visible = false, Size = UDim2.fromOffset(0, 0) }
	local shell: Shell = {
		name = name,
		root = root,
		body = Kit.box(root, { Name = "Body" }),
		title = Kit.text(root, hidden),
		code = Kit.text(root, hidden),
		footer = Kit.text(root, hidden),
		tabBar = nil,
		tabButtons = {},
		tab = nil,
		context = {},
		panel = panel,
	}
	panel.build(shell)
	return shell
end

local function buildShell(name: string, panel: Panel): Shell
	if panel.dock == "fullscreen" then
		return buildFullscreenShell(name, panel)
	end
	local size = panel.size or Vector2.new(900, 560)
	local root: CanvasGroup = Kit.new("CanvasGroup", {
		Name = "Panel_" .. name,
		AnchorPoint = if panel.dock == "right" then Vector2.new(1, 0.5) else Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = UI.Background,
		BorderSizePixel = 0,
		Visible = false,
		Parent = WindowManager.layer("Panels"),
	})
	Kit.stroke(root, UI.Border, 1)
	Kit.corner(root, 3)
	-- header
	local header = Kit.frame(root, {
		Name = "Header",
		BackgroundColor3 = UI.Panel,
		Size = UDim2.new(1, 0, 0, 62),
	})
	Kit.frame(header, { Name = "Accent", BackgroundColor3 = UI.Accent, Size = UDim2.new(0, 5, 1, 0) })
	local code = Kit.text(header, {
		Name = "Code",
		Text = panel.code,
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -220, 0, 14),
	})
	local title = Kit.text(header, {
		Name = "Title",
		Text = panel.title,
		FontFace = Kit.Fonts.Header,
		TextSize = Kit.Text.Title,
		TextColor3 = UI.Text,
		Position = UDim2.fromOffset(20, 22),
		Size = UDim2.new(1, -220, 0, 32),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local close = WindowManager.closeButton(header)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -14, 0.5, 0)
	Kit.frame(header, {
		Name = "Rule",
		BackgroundColor3 = UI.BorderDim,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
	})
	local top = 62
	local shell: Shell = {
		name = name,
		root = root,
		body = nil :: any,
		title = title,
		code = code,
		footer = nil :: any,
		tabBar = nil,
		tabButtons = {},
		tab = nil,
		context = {},
		panel = panel,
	}
	local tabs = panel.tabs
	if tabs and #tabs > 1 then
		local bar = Kit.frame(root, {
			Name = "Tabs",
			BackgroundColor3 = UI.Panel,
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 0, 36),
		})
		Kit.list(bar, Enum.FillDirection.Horizontal, 2)
		Kit.padding(bar, 14, 14, 0, 0)
		for i, tab in tabs do
			local button: TextButton = Kit.new("TextButton", {
				Name = "Tab_" .. tab,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				BackgroundColor3 = UI.Panel,
				Size = UDim2.new(0, 150, 1, 0),
				Text = tab,
				FontFace = Kit.Fonts.Header,
				TextSize = 15,
				TextColor3 = UI.TextDim,
				LayoutOrder = i,
				Selectable = true,
				Parent = bar,
			})
			Kit.frame(button, {
				Name = "Underline",
				BackgroundColor3 = UI.Accent,
				Position = UDim2.new(0, 0, 1, -2),
				Size = UDim2.new(1, 0, 0, 2),
				Visible = false,
			})
			button.Activated:Connect(function()
				Sound.play("Click")
				WindowManager.setTab(shell, tab)
			end)
			shell.tabButtons[tab] = button
		end
		Kit.frame(bar, {
			Name = "Rule",
			BackgroundColor3 = UI.BorderDim,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 99,
		})
		shell.tabBar = bar
		top += 36
	end
	local body = Kit.box(root, {
		Name = "Body",
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -(top + 26)),
	})
	Kit.padding(body, 18, 18, 14, 10)
	local footerBar = Kit.frame(root, {
		Name = "FooterBar",
		BackgroundColor3 = UI.Panel,
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 26),
	})
	local footer = Kit.text(footerBar, {
		Name = "Footer",
		Text = "",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextFaint,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -36, 1, 0),
	})
	shell.body = body
	shell.footer = footer
	panel.build(shell)
	return shell
end

local function tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

function WindowManager.open(name: string, context: Context?)
	local panel = panels[name]
	if not panel then
		warn("[Lobby] no panel registered for", name)
		return
	end
	local ctx: Context = context or {}
	local previous = current
	if previous and previous.name ~= name then
		WindowManager.close(true)
	end
	local shell = shells[name]
	if not shell then
		shell = buildShell(name, panel)
		shells[name] = shell
	end
	shell.context = ctx
	local close = shell.root:FindFirstChild("Close", true)
	local keyHint = close and close:FindFirstChild("KeyHint")
	if keyHint and keyHint:IsA("TextLabel") then
		keyHint.Text = closeHint()
	end
	local wasOpen = current == shell
	current = shell
	panel.open(shell, ctx)
	local tabs = panel.tabs
	if tabs and #tabs > 1 then
		local tab = ctx.tab
		if not tab or not table.find(tabs, tab) then
			tab = shell.tab or tabs[1]
		end
		WindowManager.setTab(shell, tab :: string)
	end
	if not wasOpen then
		ProximityPromptService.Enabled = false
		Sound.play("Open")
		local docked = panel.dock == "right"
		local fullscreen = panel.dock == "fullscreen"
		local target = if docked then UDim2.new(1, -24, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
		shell.root.Visible = true
		shell.root.GroupTransparency = 1
		shell.root.Position = if docked
			then target + UDim2.fromOffset(24, 0)
			elseif fullscreen then target
			else target + UDim2.fromOffset(0, 14)
		tween(shell.root, FADE_IN, { GroupTransparency = 0, Position = target })
		local bd = backdrop
		if bd and not docked and not fullscreen then
			bd.Visible = true
			tween(bd, FADE_IN, { BackgroundTransparency = 0.55 })
		end
		WindowManager.opened:Fire(name, ctx)
	end
	if usingGamepad() then
		GuiService.SelectedObject = firstSelectable(shell.root)
	end
end

function WindowManager.close(instant: boolean?)
	local shell = current
	if not shell then
		return
	end
	current = nil
	ProximityPromptService.Enabled = true
	local closeFn = shell.panel.close
	if closeFn then
		closeFn(shell)
	end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(shell.root) then
		GuiService.SelectedObject = nil
	end
	local root = shell.root
	if instant then
		root.Visible = false
	else
		Sound.play("Close")
		local t = tween(root, FADE_OUT, { GroupTransparency = 1, Position = root.Position + UDim2.fromOffset(0, 10) })
		t.Completed:Connect(function()
			if current ~= shell then
				root.Visible = false
			end
		end)
	end
	local bd = backdrop
	if bd and not instant then
		local t = tween(bd, FADE_OUT, { BackgroundTransparency = 1 })
		t.Completed:Connect(function()
			if not current then
				bd.Visible = false
			end
		end)
	end
	WindowManager.closed:Fire(shell.name)
end

-- Re-runs the open panel's open() (e.g. after the state it shows changed).
function WindowManager.refresh(name: string?)
	local shell = current
	if shell and (name == nil or shell.name == name) then
		shell.panel.open(shell, shell.context)
		if shell.tab then
			local select = shell.panel.selectTab
			if select then
				select(shell, shell.tab)
			end
		end
	end
end

function WindowManager.shell(name: string): Shell?
	return shells[name]
end

local root: Frame? = nil
local currentScale = 1

-- Design units -> screen: the root is sized to viewport / scale so that,
-- after the UIScale, it covers the screen exactly (corner-anchored HUD
-- stays in the corners on every device).
local function updateScale()
	local s = scale
	local r = root
	local camera = workspace.CurrentCamera
	if not s or not r or not camera then
		return
	end
	local viewport = camera.ViewportSize
	local inset = GuiService:GetGuiInset().Y
	-- panels (up to ~960 x 600 design units) must fit below the top bar
	local factor = math.clamp(math.min(viewport.X / 1000, (viewport.Y - inset) / 620), 0.5, 1.3)
	currentScale = factor
	s.Scale = factor
	r.Size = UDim2.fromOffset(viewport.X / factor, viewport.Y / factor)
	local panels = layers.Panels
	if panels then
		panels.Position = UDim2.fromOffset(0, inset / factor)
		panels.Size = UDim2.new(1, 0, 1, -inset / factor)
	end
end

function WindowManager.scale(): number
	return currentScale
end

-- Height of the Roblox top bar in design units (HUD sits below it).
function WindowManager.topInset(): number
	local inset = GuiService:GetGuiInset()
	return math.max(inset.Y, 36) / currentScale
end

local function cycleTab(direction: number)
	local shell = current
	local tabs = shell and shell.panel.tabs
	if not shell or not tabs or #tabs < 2 then
		return
	end
	local index = table.find(tabs, shell.tab or tabs[1]) or 1
	local nextIndex = (index - 1 + direction) % #tabs + 1
	Sound.play("Click")
	WindowManager.setTab(shell, tabs[nextIndex])
end

function WindowManager.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screen: ScreenGui = Kit.new("ScreenGui", {
		Name = "LobbyUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
	})
	local rootFrame = Kit.box(screen, { Name = "Root" })
	scale = Kit.new("UIScale", { Parent = rootFrame })
	root = rootFrame
	for i, name in { "Hud", "Panels", "Overlay", "Toasts" } do
		local layer = Kit.box(rootFrame, { Name = name, ZIndex = i })
		layers[name] = layer
		if name == "Panels" then
			backdrop = Kit.frame(layer, {
				Name = "Backdrop",
				BackgroundColor3 = UI.Backdrop,
				BackgroundTransparency = 1,
				Visible = false,
				-- oversized so the dim covers the screen at any UIScale
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(3, 3),
			})
		end
	end
	gui = screen
	screen.Parent = playerGui
	updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	Kit.onClick = function()
		Sound.play("Click")
	end
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not current then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.ButtonB or key == WindowManager.CloseKey then
			WindowManager.close()
		elseif key == Enum.KeyCode.ButtonR1 then
			cycleTab(1)
		elseif key == Enum.KeyCode.ButtonL1 then
			cycleTab(-1)
		end
	end)
	GuiService.MenuOpened:Connect(function()
		WindowManager.close(true)
	end)
	-- walking away from the station closes its panel
	task.spawn(function()
		while true do
			task.wait(0.3)
			local shell = current
			local part = shell and shell.context.part
			if shell and part then
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart and rootPart:IsA("BasePart") then
					local range = (shell.context.range or 10) + WindowManager.WalkAwaySlack
					if (rootPart.CFrame.Position - part.CFrame.Position).Magnitude > range then
						WindowManager.close()
					end
				elseif not part:IsDescendantOf(workspace) then
					WindowManager.close()
				end
			end
		end
	end)
end

return WindowManager
