--!strict
-- Event Area briefing: the current operation (title, days remaining,
-- briefing, featured map, limited units), its challenges and the reward
-- track with claim buttons. Standby text when no operation runs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Format = require(Lobby:WaitForChild("Util"):WaitForChild("Format"))
local Errors = require(script.Parent.Parent.Errors)
local Kit = require(script.Parent.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)

local UI = Kit.Colors

type Shell = WindowManager.Shell
type Data = { [string]: any }

local Panel = {} :: WindowManager.Panel
Panel.title = "OPERATION BRIEFING"
Panel.code = "G3 PLANS // CURRENT OPERATION"
Panel.size = Vector2.new(960, 600)

local refs: { left: Frame?, right: Frame?, status: TextLabel? } = { left = nil, right = nil, status = nil }

local render: () -> ()

local function claim(index: number)
	local response = State.request("Event", { action = "claim", tier = index })
	local status = refs.status
	if response.ok then
		Sound.play("Reward")
		if status then
			status.Text = "REWARD RECEIVED: " .. tostring(response.reward)
			status.TextColor3 = UI.Success
		end
	else
		Sound.play("Error")
		if status then
			status.Text = Errors.text(response.error)
			status.TextColor3 = UI.Danger
		end
	end
	if response.event then
		State.set("event", { info = response.event, progress = response.progress })
	end
	render()
end

local function renderLeft(frame: Frame, info: Data)
	Kit.clear(frame)
	Kit.list(frame, Enum.FillDirection.Vertical, 8)
	local primary = if typeof(info.palette) == "table" and typeof(info.palette.Primary) == "Color3"
		then info.palette.Primary
		else UI.Accent
	Kit.text(frame, {
		Name = "Label",
		Text = info.label or "CURRENT OPERATION",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = primary,
		LayoutOrder = 1,
	})
	Kit.text(frame, {
		Name = "EventTitle",
		Text = info.title or "",
		FontFace = Kit.Fonts.Header,
		TextSize = 44,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 2,
	})
	Kit.text(frame, {
		Name = "Tagline",
		Text = info.tagline or "",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		LayoutOrder = 3,
	})
	Kit.text(frame, {
		Name = "Days",
		Text = if info.active then "AVAILABLE: " .. Format.days(info.daysRemaining or 0) else "STAND BY FOR ORDERS",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 22,
		TextColor3 = UI.Accent,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 4,
	})
	-- briefing paper
	local paper = Kit.frame(frame, {
		Name = "Briefing",
		BackgroundColor3 = Color3.fromRGB(214, 204, 176),
		Size = UDim2.new(1, 0, 0, 150),
		LayoutOrder = 5,
	})
	Kit.padding(paper, 14, 14, 10, 10)
	Kit.text(paper, {
		Name = "Stamp",
		Text = "SECRET // OPERATIONAL ORDER",
		FontFace = Kit.Fonts.Document,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(138, 60, 50),
		Size = UDim2.new(1, 0, 0, 16),
	})
	Kit.text(paper, {
		Name = "Text",
		Text = info.description or "",
		FontFace = Kit.Fonts.Document,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(46, 42, 34),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 1, -20),
	})
	if info.featuredMapName then
		Kit.field(frame, "FEATURED BATTLEFIELD", info.featuredMapName, 6)
	end
	local limited = {}
	for _, unit in info.limitedUnits or {} do
		table.insert(limited, unit.name)
	end
	if #limited > 0 then
		Kit.field(frame, "LIMITED UNIT", table.concat(limited, ", "), 7)
	end
	Kit.field(frame, "ENDS", if info.active then Format.dateZulu(info.endsAt or 0) else "—", 8)
end

local function renderRight(frame: Frame, progress: Data, info: Data)
	Kit.clear(frame)
	if not info.active then
		Kit.text(frame, {
			Name = "Standby",
			Text = "No operation is running. New orders will be posted here.",
			TextWrapped = true,
			TextColor3 = UI.TextDim,
			Size = UDim2.new(1, 0, 0, 40),
		})
		return
	end
	local points = progress.points or 0
	local top = Kit.box(frame, { Name = "Points", Size = UDim2.new(1, 0, 0, 40) })
	Kit.text(top, {
		Name = "Label",
		Text = "OPERATION POINTS",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(0.5, 0, 1, 0),
	})
	Kit.text(top, {
		Name = "Value",
		Text = Format.number(points),
		FontFace = Kit.Fonts.Header,
		TextSize = 34,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
	})
	-- reward track
	local rewards = progress.rewards or {}
	local maxPoints = 1
	for _, tier in rewards do
		maxPoints = math.max(maxPoints, tier.points or 0)
	end
	local track = Kit.box(frame, {
		Name = "Track",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 150),
	})
	local bar = Kit.progress(track, points / maxPoints, UI.Accent, 6)
	bar.Position = UDim2.fromOffset(0, 4)
	for i, tier in rewards do
		local x = (tier.points or 0) / maxPoints
		local node = Kit.box(track, {
			Name = "Tier" .. i,
			AnchorPoint = Vector2.new(if i == #rewards then 1 else 0.5, 0),
			Position = UDim2.new(x, 0, 0, 0),
			Size = UDim2.fromOffset(118, 146),
		})
		Kit.frame(node, {
			Name = "Tick",
			BackgroundColor3 = if points >= (tier.points or 0) then UI.Accent else UI.Border,
			AnchorPoint = Vector2.new(if i == #rewards then 1 else 0.5, 0),
			Position = UDim2.new(if i == #rewards then 1 else 0.5, 0, 0, 0),
			Size = UDim2.fromOffset(4, 14),
		})
		local card = Kit.frame(node, {
			Name = "Card",
			BackgroundColor3 = if tier.claimed
				then UI.Panel
				elseif tier.claimable then UI.PanelRaised
				else UI.Background,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 124),
		})
		Kit.stroke(card, if tier.claimable then UI.Accent else UI.BorderDim)
		Kit.padding(card, 8, 8, 6, 6)
		Kit.text(card, {
			Name = "Points",
			Text = ("%d PTS"):format(tier.points or 0),
			FontFace = Kit.Fonts.MonoBold,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.Accent,
			Size = UDim2.new(1, 0, 0, 14),
		})
		Kit.text(card, {
			Name = "Reward",
			Text = tier.name or "",
			FontFace = Kit.Fonts.BodyBold,
			TextSize = 14,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, 0, 0, 52),
		})
		if tier.claimed then
			Kit.text(card, {
				Name = "Claimed",
				Text = "COLLECTED",
				FontFace = Kit.Fonts.Mono,
				TextSize = Kit.Text.Tiny,
				TextColor3 = UI.TextFaint,
				Position = UDim2.new(0, 0, 1, -30),
				Size = UDim2.new(1, 0, 0, 28),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		else
			local button = Kit.button(card, "CLAIM", "primary", function()
				claim(tier.index or i)
			end)
			button.Name = "Claim"
			button.Position = UDim2.new(0, 0, 1, -30)
			button.Size = UDim2.new(1, 0, 0, 28)
			button.TextSize = 14
			Kit.setEnabled(button, tier.claimable == true)
		end
	end
	-- challenges
	local list = Kit.box(frame, {
		Name = "Challenges",
		Position = UDim2.fromOffset(0, 210),
		Size = UDim2.new(1, 0, 1, -210),
	})
	Kit.list(list, Enum.FillDirection.Vertical, 5)
	Kit.heading(list, "CHALLENGES", 0)
	for i, c in progress.challenges or {} do
		local row = Kit.frame(list, {
			Name = "Challenge_" .. tostring(c.id),
			BackgroundColor3 = UI.Panel,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = i,
		})
		Kit.stroke(row, if c.complete then UI.AccentDim else UI.BorderDim)
		Kit.text(row, {
			Name = "Text",
			Text = (if c.complete then "✓ " else "") .. tostring(c.text),
			FontFace = Kit.Fonts.BodyBold,
			TextSize = 14,
			TextColor3 = if c.complete then UI.Accent else UI.Text,
			Position = UDim2.fromOffset(10, 3),
			Size = UDim2.new(0.62, -10, 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local pbar = Kit.progress(
			row,
			(c.progress or 0) / math.max(c.target or 1, 1),
			if c.complete then UI.Accent else UI.Phosphor,
			5
		)
		pbar.Position = UDim2.fromOffset(10, 27)
		pbar.Size = UDim2.new(0.62, -10, 0, 5)
		Kit.text(row, {
			Name = "Progress",
			Text = ("%d / %d"):format(c.progress or 0, c.target or 1),
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.62, 0),
			Size = UDim2.new(0.18, 0, 1, 0),
		})
		Kit.text(row, {
			Name = "Points",
			Text = ("+%d PTS"):format(c.points or 0),
			FontFace = Kit.Fonts.MonoBold,
			TextSize = Kit.Text.Small,
			TextColor3 = UI.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.8, 0),
			Size = UDim2.new(0.2, -10, 1, 0),
		})
	end
end

render = function()
	local left, right = refs.left, refs.right
	local data = State.event
	if not left or not right then
		return
	end
	if not data or not data.info then
		Kit.clear(left)
		Kit.text(left, { Name = "Loading", Text = "DECRYPTING ORDERS…", TextColor3 = UI.TextDim })
		return
	end
	renderLeft(left, data.info)
	renderRight(right, data.progress or {}, data.info)
	local shell = WindowManager.shell("Event")
	if shell then
		shell.title.Text = if data.info.active then tostring(data.info.codename) else "OPERATIONS BRIEFING"
	end
end

function Panel.build(shell: Shell)
	local left, right = Kit.columns(shell.body, 360, 24)
	right.Size = UDim2.new(1, -384, 1, -18)
	refs.left = left
	refs.right = right
	refs.status = Kit.text(shell.body, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		Position = UDim2.new(0, 384, 1, -16),
		Size = UDim2.new(1, -384, 0, 16),
	})
	shell.footer.Text = "OPERATION POINTS COME FROM CHALLENGES · REWARDS STAY YOURS AFTER THE OPERATION ENDS"
	State.changed:Connect(function(key)
		if key == "event" and WindowManager.current() == "Event" then
			render()
		end
	end)
end

function Panel.open(_shell: Shell, _context: WindowManager.Context)
	local status = refs.status
	if status then
		status.Text = ""
	end
	render()
	task.spawn(function()
		State.refreshEvent()
	end)
end

return Panel
