--!strict
-- Always-on lobby HUD, kept small so the base itself stays the interface:
-- * commander card (rank, name, level bar, credits) under the top bar
-- * matchmaking strip (top centre) while queued / in a private lobby,
--   with elapsed time and a leave button, visible anywhere in the base
-- * zone banner when walking into an area
-- * optional locator: a compact list of destinations with a direction
--   arrow and distance, toggled with L / DPad-down / its button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Config = Lobby:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("GameModes"))
local Layout = require(Config:WaitForChild("Layout"))
local Format = require(Lobby:WaitForChild("Util"):WaitForChild("Format"))
local Kit = require(script.Parent.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)

local UI = Kit.Colors

local Hud = {}

Hud.LocatorKey = Enum.KeyCode.L
-- A 5-stud-tall character is ~1.8 m.
Hud.MetersPerStud = 0.36

local refs: {
	card: Frame?,
	queue: Frame?,
	queueText: TextLabel?,
	queueTimer: TextLabel?,
	banner: Frame?,
	locator: Frame?,
	locatorList: Frame?,
	locatorOpen: boolean,
	currentZone: string?,
} =
	{
		card = nil,
		queue = nil,
		queueText = nil,
		queueTimer = nil,
		banner = nil,
		locator = nil,
		locatorList = nil,
		locatorOpen = false,
		currentZone = nil,
	}

-- Commander card ---------------------------------------------------------------

local function buildCard(layer: Frame)
	local card = Kit.frame(layer, {
		Name = "CommanderCard",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.15,
		Position = UDim2.fromOffset(16, WindowManager.topInset() + 8),
		Size = UDim2.fromOffset(250, 64),
	})
	Kit.stroke(card, UI.BorderDim)
	Kit.corner(card, 3)
	Kit.frame(card, { Name = "Faction", BackgroundColor3 = UI.Nato, Size = UDim2.new(0, 4, 1, 0) })
	Kit.text(card, {
		Name = "Rank",
		Text = "PVT",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Accent,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(46, 18),
	})
	Kit.text(card, {
		Name = "Name",
		Text = Players.LocalPlayer and Players.LocalPlayer.DisplayName or "",
		FontFace = Kit.Fonts.Header,
		TextSize = 17,
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.new(1, -66, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.text(card, {
		Name = "Level",
		Text = "LV 1",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.fromOffset(60, 14),
	})
	local bar = Kit.progress(card, 0, UI.Accent, 4)
	bar.Position = UDim2.fromOffset(70, 33)
	bar.Size = UDim2.new(1, -84, 0, 4)
	Kit.text(card, {
		Name = "Credits",
		Text = "0 CR",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Text,
		Position = UDim2.fromOffset(14, 42),
		Size = UDim2.new(1, -28, 0, 18),
	})
	refs.card = card
end

local function child(parent: Instance, name: string): any
	return parent:FindFirstChild(name)
end

local function updateCard()
	local card = refs.card
	local p = State.profile
	if not card or not p then
		return
	end
	child(card, "Rank").Text = p.rankShort or ""
	child(card, "Name").Text = p.name or ""
	child(card, "Level").Text = ("LV %d"):format(p.level or 1)
	child(card, "Credits").Text = Format.number(p.credits or 0)
		.. " CR"
		.. (if p.temporary then "  · TEMP FILE" else "")
	child(card, "Faction").BackgroundColor3 = if p.faction == "PACT" then UI.Pact else UI.Nato
	Kit.setProgress(child(card, "Progress"), (p.levelXp or 0) / math.max(p.levelNeed or 1, 1))
end

-- Matchmaking strip -----------------------------------------------------------

local function buildQueue(layer: Frame)
	local strip = Kit.frame(layer, {
		Name = "QueueStrip",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, WindowManager.topInset() + 8),
		Size = UDim2.fromOffset(460, 40),
		Visible = false,
	})
	Kit.stroke(strip, UI.Phosphor, 1, 0.3)
	Kit.corner(strip, 3)
	local pulse = Kit.frame(strip, {
		Name = "Pulse",
		BackgroundColor3 = UI.Phosphor,
		Position = UDim2.fromOffset(12, 15),
		Size = UDim2.fromOffset(10, 10),
	})
	Kit.corner(pulse, 5)
	refs.queueText = Kit.text(strip, {
		Name = "Text",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -190, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	refs.queueTimer = Kit.text(strip, {
		Name = "Timer",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 16,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -160, 0, 0),
		Size = UDim2.fromOffset(60, 40),
	})
	local leave = Kit.button(strip, "LEAVE", "ghost", function()
		local response = State.request("Matchmaking", { action = "leave" })
		if response.ok and response.state then
			State.set("matchmaking", response.state)
		end
	end)
	leave.Name = "Leave"
	leave.AnchorPoint = Vector2.new(1, 0.5)
	leave.Position = UDim2.new(1, -6, 0.5, 0)
	leave.Size = UDim2.fromOffset(84, 28)
	leave.TextSize = 13
	refs.queue = strip
	-- gentle pulse on the status light
	task.spawn(function()
		local on = true
		while true do
			task.wait(0.8)
			on = not on
			if strip.Visible then
				TweenService:Create(pulse, TweenInfo.new(0.6), { BackgroundTransparency = if on then 0 else 0.7 })
					:Play()
			end
		end
	end)
end

local function updateQueue()
	local strip, text = refs.queue, refs.queueText
	if not strip or not text then
		return
	end
	local mm: { [string]: any } = State.matchmaking or {}
	if mm.state == "queued" then
		local mode = GameModes.Modes[mm.mode]
		local count = if mm.mode == "QUICK" then "SEARCHING" else ("%d/%d READY"):format(mm.count or 1, mm.needed or 2)
		text.Text = ("MATCHMAKING · %s · %s"):format(mode and mode.Title or tostring(mm.mode), count)
		strip.Visible = true
	elseif mm.state == "private" and mm.lobby then
		text.Text = ("PRIVATE LOBBY %s · %d/%d"):format(
			mm.lobby.code,
			#(mm.lobby.members or {}),
			mm.lobby.capacity or 0
		)
		strip.Visible = true
	else
		strip.Visible = false
	end
end

-- Zone banner -------------------------------------------------------------------

local function buildBanner(layer: Frame)
	local banner = Kit.box(layer, {
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, WindowManager.topInset() + 60),
		Size = UDim2.fromOffset(520, 60),
		Visible = false,
	})
	Kit.text(banner, {
		Name = "Title",
		Text = "",
		FontFace = Kit.Fonts.Header,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.6,
		Size = UDim2.new(1, 0, 0, 34),
	})
	Kit.text(banner, {
		Name = "Subtitle",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.7,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 18),
	})
	refs.banner = banner
end

local bannerToken = 0

function Hud.showBanner(title: string, subtitle: string)
	local banner = refs.banner
	if not banner then
		return
	end
	bannerToken += 1
	local token = bannerToken
	local titleLabel = child(banner, "Title") :: TextLabel
	local subLabel = child(banner, "Subtitle") :: TextLabel
	titleLabel.Text = title
	subLabel.Text = subtitle
	titleLabel.TextTransparency = 1
	subLabel.TextTransparency = 1
	banner.Visible = true
	local info = TweenInfo.new(0.35)
	TweenService:Create(titleLabel, info, { TextTransparency = 0 }):Play()
	TweenService:Create(subLabel, info, { TextTransparency = 0 }):Play()
	task.delay(2.6, function()
		if token ~= bannerToken then
			return
		end
		TweenService:Create(titleLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		local t = TweenService:Create(subLabel, TweenInfo.new(0.6), { TextTransparency = 1 })
		t.Completed:Connect(function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
		t:Play()
	end)
end

-- Which zone (if any) contains a world position (footprint + 3 studs).
function Hud.zoneAt(position: Vector3): string?
	for _, id in Layout.ZoneOrder do
		local rect = Layout.footprint(Layout.Zones[id])
		if
			position.X >= rect.MinX - 3
			and position.X <= rect.MaxX + 3
			and position.Z >= rect.MinZ - 3
			and position.Z <= rect.MaxZ + 3
		then
			return id
		end
	end
	return nil
end

-- Locator -----------------------------------------------------------------------

local ARROWS = { "↑", "↗", "→", "↘", "↓", "↙", "←", "↖" }

local function arrowFor(from: Vector3, to: Vector3, look: Vector3): string
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 1 then
		return "•"
	end
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(0, 0, -1)
	end
	forward = forward.Unit
	local dir = flat.Unit
	local angle = math.atan2(forward:Cross(dir).Y, forward:Dot(dir))
	-- positive Y cross = target to the left
	local index = math.floor((-angle / (math.pi * 2)) * 8 + 0.5) % 8 + 1
	return ARROWS[index]
end
Hud.arrowFor = arrowFor

local function buildLocator(layer: Frame)
	local locator = Kit.frame(layer, {
		Name = "Locator",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.2,
		Position = UDim2.fromOffset(16, WindowManager.topInset() + 80),
		Size = UDim2.fromOffset(250, 28),
		ClipsDescendants = true,
	})
	Kit.stroke(locator, UI.BorderDim)
	Kit.corner(locator, 3)
	local toggle: TextButton = Kit.new("TextButton", {
		Name = "Toggle",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		Parent = locator,
	})
	Kit.text(toggle, {
		Name = "Label",
		Text = "▸ LOCATOR  [L]",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -12, 1, 0),
	})
	local list = Kit.box(locator, { Name = "List", Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 0) })
	Kit.list(list, Enum.FillDirection.Vertical, 0)
	for i, id in Layout.ZoneOrder do
		local zone = Layout.Zones[id]
		local row = Kit.box(list, { Name = "Dest_" .. id, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i })
		Kit.text(row, {
			Name = "Arrow",
			Text = "↑",
			FontFace = Kit.Fonts.MonoBold,
			TextColor3 = UI.Accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.fromOffset(20, 22),
		})
		Kit.text(row, {
			Name = "Name",
			Text = zone.DisplayName,
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -96, 1, 0),
		})
		Kit.text(row, {
			Name = "Distance",
			Text = "",
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -64, 0, 0),
			Size = UDim2.fromOffset(56, 22),
		})
	end
	toggle.Activated:Connect(function()
		Hud.toggleLocator()
	end)
	refs.locator = locator
	refs.locatorList = list
end

function Hud.toggleLocator(open: boolean?)
	local locator = refs.locator
	if not locator then
		return
	end
	refs.locatorOpen = if open == nil then not refs.locatorOpen else open
	Sound.play("Click")
	local height = if refs.locatorOpen then 28 + #Layout.ZoneOrder * 22 + 6 else 28
	TweenService:Create(locator, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		Size = UDim2.fromOffset(250, height),
	}):Play()
	local label = locator:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = (if refs.locatorOpen then "▾" else "▸") .. " LOCATOR  [L]"
	end
end

local function updateLocator(position: Vector3, look: Vector3)
	local list = refs.locatorList
	if not list or not refs.locatorOpen then
		return
	end
	for _, id in Layout.ZoneOrder do
		local row = list:FindFirstChild("Dest_" .. id)
		if row then
			local target = Layout.entrancePoint(Layout.Zones[id])
			local distance = (Vector3.new(target.X, 0, target.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
			local here = refs.currentZone == id
			child(row, "Arrow").Text = if here then "●" else arrowFor(position, target, look)
			child(row, "Distance").Text = if here then "HERE" else Format.meters(distance, Hud.MetersPerStud)
			child(row, "Name").TextColor3 = if here then UI.Accent else UI.Text
		end
	end
end

-- Lifecycle -----------------------------------------------------------------------

function Hud.start()
	local layer = WindowManager.layer("Hud")
	buildCard(layer)
	buildQueue(layer)
	buildBanner(layer)
	buildLocator(layer)
	updateCard()
	updateQueue()
	State.changed:Connect(function(key)
		if key == "profile" then
			updateCard()
		elseif key == "matchmaking" then
			updateQueue()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Hud.LocatorKey or input.KeyCode == Enum.KeyCode.DPadDown then
			Hud.toggleLocator()
		end
	end)
	-- the HUD stays visible behind docked panels but hides behind full ones
	WindowManager.opened:Connect(function(name)
		local shell = WindowManager.shell(name)
		local docked = shell and shell.panel.dock == "right"
		layer.Visible = docked == true
	end)
	WindowManager.closed:Connect(function()
		layer.Visible = true
	end)
	local player = Players.LocalPlayer
	task.spawn(function()
		while true do
			task.wait(0.2)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local camera = workspace.CurrentCamera
			if root and root:IsA("BasePart") and camera then
				local position = root.CFrame.Position
				local zone = Hud.zoneAt(position)
				if zone ~= refs.currentZone then
					refs.currentZone = zone
					if zone then
						local info = Layout.Zones[zone]
						Hud.showBanner(info.DisplayName, info.Subtitle)
					end
				end
				updateLocator(position, camera.CFrame.LookVector)
			end
			local mm = State.matchmaking
			local timer = refs.queueTimer
			if timer and mm and mm.state == "queued" and type(mm.since) == "number" then
				timer.Text = Format.clock(State.serverNow() - mm.since)
			elseif timer then
				timer.Text = ""
			end
		end
	end)
end

return Hud
