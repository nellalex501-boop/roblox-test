--!strict
-- Server notifications on screen:
-- * toasts (mission complete, rewards, challenges) stacked on the right,
--   teletype-style, auto-dismissed
-- * the match overlay (MATCH FOUND / DEPLOYING / SIMULATED / FAILED) with
--   teams, map and countdown, driven by the matchmaking state

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local GameModes = require(Lobby:WaitForChild("Config"):WaitForChild("GameModes"))
local Kit = require(script.Parent.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)

local UI = Kit.Colors

local Notifications = {}

Notifications.ToastSeconds = 5
Notifications.MaxToasts = 4

local KIND_COLORS: { [string]: Color3 } = {
	Mission = UI.Phosphor,
	Reward = UI.Accent,
	Event = Color3.fromRGB(170, 190, 204),
	Match = UI.Accent,
	Error = UI.Danger,
}

local stack: Frame? = nil
local overlay: Frame? = nil
local overlayRefs: { [string]: any } = {}
local lastPhase: string? = nil
-- kept in Lua, not attributes: timestamps need double precision
local overlayEndsAt: number? = nil
local toastCount = 0

local pending: { { [string]: any } } = {}

-- While a full-screen panel is open, toasts wait (the panel shows its own
-- status line) and appear when it closes; docked panels show them live.
local function blockedByPanel(): boolean
	local name = WindowManager.current()
	if not name then
		return false
	end
	local shell = WindowManager.shell(name)
	return not (shell and shell.panel.dock == "right")
end

local show: (payload: { [string]: any }) -> ()

function Notifications.toast(payload: { [string]: any })
	if blockedByPanel() then
		table.insert(pending, payload)
		if #pending > Notifications.MaxToasts then
			table.remove(pending, 1)
		end
		return
	end
	show(payload)
end

function Notifications.flush()
	local queued = pending
	pending = {}
	for i, payload in queued do
		task.delay((i - 1) * 0.35, function()
			show(payload)
		end)
	end
end

show = function(payload: { [string]: any })
	local container = stack
	if not container then
		return
	end
	toastCount += 1
	local color = KIND_COLORS[payload.kind] or UI.Accent
	-- the list layout positions the holder; the card inside slides + fades
	local toast = Kit.box(container, {
		Name = "Toast",
		Size = UDim2.fromOffset(330, 74),
		LayoutOrder = -toastCount,
	})
	local card: CanvasGroup = Kit.new("CanvasGroup", {
		Name = "Card",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(40, 0),
		GroupTransparency = 1,
		Parent = toast,
	})
	Kit.stroke(card, color, 1, 0.2)
	Kit.corner(card, 3)
	Kit.frame(card, { Name = "Accent", BackgroundColor3 = color, Size = UDim2.new(0, 4, 1, 0) })
	Kit.text(card, {
		Name = "Title",
		Text = tostring(payload.title or ""),
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = color,
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -24, 0, 16),
	})
	Kit.text(card, {
		Name = "Text",
		Text = tostring(payload.text or ""),
		FontFace = Kit.Fonts.Header,
		TextSize = 17,
		Position = UDim2.fromOffset(16, 24),
		Size = UDim2.new(1, -24, 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.text(card, {
		Name = "Detail",
		Text = tostring(payload.detail or ""),
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -24, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
		GroupTransparency = 0,
	}):Play()
	-- keep the stack short
	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = Notifications.MaxToasts + 1, #toasts do
		toasts[i]:Destroy()
	end
	Sound.play(if payload.kind == "Reward" then "Reward" elseif payload.kind == "Mission" then "Paper" else "Confirm")
	task.delay(Notifications.ToastSeconds, function()
		if toast.Parent then
			local t = TweenService:Create(card, TweenInfo.new(0.4), {
				GroupTransparency = 1,
				Position = UDim2.fromOffset(24, 0),
			})
			t.Completed:Connect(function()
				toast:Destroy()
			end)
			t:Play()
		end
	end)
end

local function buildOverlay(layer: Frame)
	local frame = Kit.frame(layer, {
		Name = "MatchOverlay",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.04,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(560, 250),
		Visible = false,
	})
	Kit.stroke(frame, UI.Accent, 2)
	Kit.corner(frame, 3)
	Kit.padding(frame, 24, 24, 18, 18)
	overlayRefs.title = Kit.text(frame, {
		Name = "Title",
		Text = "MATCH FOUND",
		FontFace = Kit.Fonts.Header,
		TextSize = 40,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 46),
	})
	overlayRefs.sub = Kit.text(frame, {
		Name = "Subtitle",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Body,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 20),
	})
	local teams = Kit.box(frame, { Name = "Teams", Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 90) })
	overlayRefs.teams = teams
	overlayRefs.countdown = Kit.text(frame, {
		Name = "Countdown",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 22,
		TextColor3 = UI.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 1, -30),
		Size = UDim2.new(1, 0, 0, 28),
	})
	overlay = frame
end

local function renderTeams(match: { [string]: any })
	local teams = overlayRefs.teams :: Frame
	Kit.clear(teams)
	for i, team in match.teams or {} do
		local column = Kit.box(teams, {
			Name = "Team" .. i,
			Position = UDim2.fromScale((i - 1) * 0.5, 0),
			Size = UDim2.new(0.5, -8, 1, 0),
		})
		Kit.list(column, Enum.FillDirection.Vertical, 1, Enum.HorizontalAlignment.Center)
		Kit.text(column, {
			Name = "Header",
			Text = if i == 1 then "BLUE FORCE" else "RED FORCE",
			FontFace = Kit.Fonts.MonoBold,
			TextSize = Kit.Text.Small,
			TextColor3 = if i == 1 then UI.Nato else UI.Pact,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 0,
		})
		for j, name in team do
			Kit.text(column, {
				Name = "Member" .. j,
				Text = tostring(name),
				FontFace = Kit.Fonts.Body,
				TextSize = Kit.Text.Small,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = j,
			})
		end
	end
end

local function updateOverlay()
	local frame = overlay
	if not frame then
		return
	end
	local mm: { [string]: any } = State.matchmaking or {}
	local phase = mm.state
	local active = phase == "found" or phase == "deploying" or phase == "simulated" or phase == "failed"
	if not active then
		frame.Visible = false
		lastPhase = phase
		return
	end
	local match = mm.match or {}
	local mode = GameModes.Modes[match.mode or ""]
	local titles = {
		found = "MATCH FOUND",
		deploying = "DEPLOYING…",
		simulated = "DEPLOYMENT SIMULATED",
		failed = "DEPLOYMENT FAILED",
	}
	overlayRefs.title.Text = titles[phase]
	overlayRefs.title.TextColor3 = if phase == "failed" then UI.Danger else UI.Accent
	overlayRefs.sub.Text = ("%s · %s%s"):format(
		mode and mode.Title or "",
		match.mapName or "",
		if match.private then " · PRIVATE" else ""
	)
	renderTeams(match)
	overlayRefs.countdown.Text = mm.message or ""
	overlayEndsAt = if phase == "found" then match.endsAt else nil
	if not frame.Visible then
		frame.Visible = true
		frame.Size = UDim2.fromOffset(520, 230)
		TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(560, 250) })
			:Play()
	end
	if phase == "found" and lastPhase ~= "found" then
		Sound.play("MatchFound")
		-- a match found closes whatever panel is open
		WindowManager.close()
	end
	lastPhase = phase
end

function Notifications.start()
	local toastLayer = WindowManager.layer("Toasts")
	local container = Kit.box(toastLayer, {
		Name = "ToastStack",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, WindowManager.topInset() + 120),
		Size = UDim2.fromOffset(330, 400),
	})
	Kit.list(container, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)
	stack = container
	buildOverlay(WindowManager.layer("Overlay"))
	-- toasts already on screen step aside while a full panel is open
	WindowManager.opened:Connect(function()
		container.Visible = not blockedByPanel()
	end)
	WindowManager.closed:Connect(function()
		container.Visible = true
		task.delay(0.3, function()
			if not blockedByPanel() then
				Notifications.flush()
			end
		end)
	end)
	State.notified:Connect(function(payload)
		-- the match overlay already covers match notifications
		if payload.kind ~= "Match" then
			Notifications.toast(payload)
		end
	end)
	State.changed:Connect(function(key)
		if key == "matchmaking" then
			updateOverlay()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local label = overlayRefs.countdown :: TextLabel?
			if label and overlay and overlay.Visible then
				local endsAt = overlayEndsAt
				if type(endsAt) == "number" then
					label.Text = ("DEPLOYING IN %d"):format(math.max(0, math.ceil(endsAt - State.serverNow())))
				end
			end
		end
	end)
end

return Notifications
