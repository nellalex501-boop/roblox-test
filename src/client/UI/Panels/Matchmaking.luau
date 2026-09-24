--!strict
-- Operations Center terminal: queue for the terminal's mode (Quick, 1v1,
-- 2v2, 4v4) or run a private lobby (create / join by code / host options
-- / start). The queue persists while the player walks around the base;
-- the HUD shows it everywhere else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Config = Lobby:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("GameModes"))
local Maps = require(Config:WaitForChild("Maps"))
local Theme = require(Config:WaitForChild("Theme"))
local Format = require(Lobby:WaitForChild("Util"):WaitForChild("Format"))
local Errors = require(script.Parent.Parent.Errors)
local Kit = require(script.Parent.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)

local UI = Kit.Colors

type Shell = WindowManager.Shell

local Panel = {} :: WindowManager.Panel
Panel.title = "OPERATIONS CENTER"
Panel.code = "C3-NET // MATCHMAKING TERMINAL"
Panel.size = Vector2.new(900, 560)

local refs: {
	mode: string,
	left: Frame?,
	card: Frame?,
	status: TextLabel?,
	timer: TextLabel?,
	timerSince: number?,
	timerEndsAt: number?,
	privateSize: string,
	codeText: string,
	busy: boolean,
} =
	{
		mode = "QUICK",
		left = nil,
		card = nil,
		status = nil,
		timer = nil,
		timerSince = nil,
		timerEndsAt = nil,
		privateSize = "2V2",
		codeText = "",
		busy = false,
	}

local function modeColor(modeId: string): Color3
	local mode = GameModes.Modes[modeId]
	return Theme.ModeColors[mode and mode.ColorKey or "QUICK"] or UI.Accent
end

local function setStatus(text: string, isError: boolean?)
	local label = refs.status
	if label then
		label.Text = text
		label.TextColor3 = if isError then UI.Danger else UI.TextDim
	end
end

local render: () -> ()

local function act(payload: { [string]: any })
	if refs.busy then
		return
	end
	refs.busy = true
	setStatus("TRANSMITTING…")
	local response = State.request("Matchmaking", payload)
	refs.busy = false
	if response.ok then
		if response.state then
			State.set("matchmaking", response.state)
		end
		Sound.play("Confirm")
		setStatus("")
	else
		Sound.play("Error")
		setStatus(Errors.text(response.error), true)
	end
	render()
end

local function queueCount(modeId: string): number
	local status = State.status
	local counts = status and status.counts
	return if counts and counts[modeId] then counts[modeId] else 0
end

local function buildLeft(shell: Shell)
	local left = refs.left
	if not left then
		return
	end
	Kit.clear(left)
	local mode = GameModes.Modes[refs.mode]
	local color = modeColor(refs.mode)
	Kit.list(left, Enum.FillDirection.Vertical, 8)
	local tag =
		Kit.frame(left, { Name = "ModeTag", BackgroundColor3 = color, Size = UDim2.new(0, 64, 0, 4), LayoutOrder = 1 })
	tag.BorderSizePixel = 0
	Kit.text(left, {
		Name = "ModeTitle",
		Text = mode.Title,
		FontFace = Kit.Fonts.Header,
		TextSize = 30,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 2,
	})
	Kit.text(left, {
		Name = "ModeSubtitle",
		Text = mode.Subtitle .. "  ·  " .. mode.PlayersLabel,
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = color,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 3,
	})
	Kit.text(left, {
		Name = "Description",
		Text = mode.Description,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(1, 0, 0, 62),
		LayoutOrder = 4,
	})
	Kit.heading(left, "OPERATIONS NETWORK", 5)
	local online = State.status and State.status.online or 0
	Kit.field(left, "COMMANDERS ONLINE", tostring(online), 6)
	for i, id in { "QUICK", "1V1", "2V2", "4V4", "PRIVATE" } do
		local count = queueCount(id)
		local text = if id == "QUICK"
			then ("%d SEARCHING"):format(count)
			elseif id == "PRIVATE" then ("%d IN LOBBIES"):format(count)
			else ("%d / %d"):format(count, GameModes.playersNeeded(id) or 2)
		local row, value = Kit.field(left, GameModes.Modes[id].Title, text, 6 + i)
		if id == refs.mode then
			local labelText = row:FindFirstChild("Label")
			if labelText and labelText:IsA("TextLabel") then
				labelText.TextColor3 = color
			end
			value.TextColor3 = color
		end
	end
	local profile = State.profile
	local preferred = profile and profile.preferredMap
	local hasPreferred = preferred and preferred ~= "" and Maps.List[preferred] ~= nil
	Kit.field(left, "PREFERRED MAP", if hasPreferred then Maps.List[preferred].Name else "NOT SET", 12)
	if not hasPreferred then
		Kit.text(left, {
			Name = "PreferredHint",
			Text = "Pick one at the Map Room displays.",
			TextSize = Kit.Text.Small,
			TextColor3 = UI.TextFaint,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 13,
		})
	end
end

-- Card helpers ------------------------------------------------------------

local function cardTitle(card: Frame, text: string, color: Color3?, order: number)
	Kit.text(card, {
		Name = "CardTitle",
		Text = text,
		FontFace = Kit.Fonts.Header,
		TextSize = 22,
		TextColor3 = color or UI.Text,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = order,
	})
end

local function cardText(card: Frame, text: string, order: number, height: number?, color: Color3?)
	return Kit.text(card, {
		Name = "CardText",
		Text = text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = color or UI.TextDim,
		Size = UDim2.new(1, 0, 0, height or 20),
		LayoutOrder = order,
	})
end

local function buttonRow(card: Frame, order: number): Frame
	local row = Kit.box(card, { Name = "Buttons", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order })
	Kit.list(row, Enum.FillDirection.Horizontal, 10)
	return row
end

local function teamsBlock(card: Frame, match: { [string]: any }, order: number)
	local teams = match.teams or {}
	local holder = Kit.box(card, { Name = "Teams", Size = UDim2.new(1, 0, 0, 120), LayoutOrder = order })
	for i, team in teams do
		local column = Kit.box(holder, {
			Name = "Team" .. i,
			Position = UDim2.fromScale((i - 1) * 0.5, 0),
			Size = UDim2.new(0.5, -6, 1, 0),
		})
		Kit.list(column, Enum.FillDirection.Vertical, 2)
		Kit.text(column, {
			Name = "Header",
			Text = if i == 1 then "BLUE FORCE" else "RED FORCE",
			FontFace = Kit.Fonts.MonoBold,
			TextSize = Kit.Text.Small,
			TextColor3 = if i == 1 then UI.Nato else UI.Pact,
			LayoutOrder = 0,
		})
		for j, name in team do
			Kit.text(column, {
				Name = "Member" .. j,
				Text = "· " .. tostring(name),
				FontFace = Kit.Fonts.Mono,
				TextSize = Kit.Text.Small,
				LayoutOrder = j,
			})
		end
	end
end

-- States -------------------------------------------------------------------

local function renderQueueIdle(card: Frame)
	local mode = GameModes.Modes[refs.mode]
	cardTitle(card, "READY TO DEPLOY", nil, 1)
	cardText(
		card,
		"Join the "
			.. mode.Title
			.. " queue. You can keep exploring the base while the network finds commanders — the queue follows you.",
		2,
		44
	)
	local row = buttonRow(card, 3)
	local join = Kit.button(row, "JOIN QUEUE", "primary", function()
		act({ action = "join", mode = refs.mode })
	end)
	join.Name = "JoinQueue"
	join.Size = UDim2.fromOffset(220, 40)
end

local function renderQueued(card: Frame, state: { [string]: any })
	local queuedMode = GameModes.Modes[state.mode]
	local here = state.mode == refs.mode
	cardTitle(card, if here then "SEARCHING FOR COMMANDERS" else "QUEUED ELSEWHERE", UI.Phosphor, 1)
	cardText(
		card,
		if here
			then ("%s · POSITION %d"):format(queuedMode.Title, state.position or 1)
			else ("You are in the %s queue."):format(queuedMode.Title),
		2
	)
	local timer = Kit.text(card, {
		Name = "Elapsed",
		Text = "00:00",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 40,
		TextColor3 = UI.Accent,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 3,
	})
	refs.timerSince = state.since or os.time()
	refs.timer = timer
	local needed = state.needed or 2
	local count = state.count or 1
	if state.mode ~= "QUICK" then
		Kit.text(card, {
			Name = "Count",
			Text = ("%d / %d COMMANDERS READY"):format(count, needed),
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Small,
			TextColor3 = UI.TextDim,
			LayoutOrder = 4,
		})
		local bar = Kit.progress(card, count / needed, UI.Phosphor, 8)
		bar.LayoutOrder = 5
	end
	local row = buttonRow(card, 6)
	if not here then
		local switch = Kit.button(row, "SWITCH TO " .. GameModes.Modes[refs.mode].Title, "primary", function()
			act({ action = "join", mode = refs.mode })
		end)
		switch.Name = "Switch"
		switch.Size = UDim2.fromOffset(260, 40)
	end
	local leave = Kit.button(row, "LEAVE QUEUE", "danger", function()
		act({ action = "leave" })
	end)
	leave.Name = "LeaveQueue"
	leave.Size = UDim2.fromOffset(180, 40)
end

local function renderDeploy(card: Frame, state: { [string]: any })
	local match = state.match or {}
	local mode = GameModes.Modes[match.mode or "QUICK"]
	local titles = {
		found = "MATCH FOUND",
		deploying = "DEPLOYING…",
		simulated = "DEPLOYMENT SIMULATED",
		failed = "DEPLOYMENT FAILED",
	}
	cardTitle(card, titles[state.state] or "DEPLOYING", if state.state == "failed" then UI.Danger else UI.Accent, 1)
	cardText(card, ("%s · %s"):format(mode and mode.Title or "", match.mapName or ""), 2)
	if state.state == "found" then
		local timer = Kit.text(card, {
			Name = "Countdown",
			Text = "",
			FontFace = Kit.Fonts.MonoBold,
			TextSize = 40,
			TextColor3 = UI.Accent,
			Size = UDim2.new(1, 0, 0, 46),
			LayoutOrder = 3,
		})
		refs.timerEndsAt = match.endsAt or os.time()
		refs.timer = timer
	end
	teamsBlock(card, match, 4)
	if state.message then
		cardText(card, state.message, 5, 36, UI.TextDim)
	end
end

local function sizeSelector(card: Frame, order: number, selected: string, onSelect: (string) -> ())
	local row = Kit.box(card, { Name = "Sizes", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = order })
	Kit.list(row, Enum.FillDirection.Horizontal, 8)
	for i, size in GameModes.PrivateSizes do
		local button = Kit.button(
			row,
			GameModes.Modes[size].SignText,
			if size == selected then "primary" else "secondary",
			function()
				onSelect(size)
			end
		)
		button.Name = "Size_" .. size
		button.LayoutOrder = i
		button.Size = UDim2.fromOffset(90, 34)
	end
end

local function renderPrivateIdle(card: Frame)
	cardTitle(card, "CREATE A PRIVATE OPERATION", nil, 1)
	cardText(card, "Choose the battle size, then share the access code with your group.", 2)
	sizeSelector(card, 3, refs.privateSize, function(size)
		refs.privateSize = size
		render()
	end)
	local row = buttonRow(card, 4)
	local create = Kit.button(row, "CREATE LOBBY", "primary", function()
		act({ action = "createPrivate", size = refs.privateSize })
	end)
	create.Name = "CreateLobby"
	create.Size = UDim2.fromOffset(200, 40)
	Kit.divider(card, 5)
	cardTitle(card, "JOIN WITH ACCESS CODE", nil, 6)
	local joinRow = buttonRow(card, 7)
	local box: TextBox = Kit.new("TextBox", {
		Name = "CodeBox",
		BackgroundColor3 = UI.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(200, 40),
		PlaceholderText = "CODE",
		PlaceholderColor3 = UI.TextFaint,
		Text = refs.codeText,
		ClearTextOnFocus = false,
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 22,
		TextColor3 = UI.Accent,
		Parent = joinRow,
	})
	Kit.stroke(box, UI.Border)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local cleaned = box.Text:upper():gsub("[^%w]", ""):sub(1, 8)
		if cleaned ~= box.Text then
			box.Text = cleaned
		end
		refs.codeText = cleaned
	end)
	local join = Kit.button(joinRow, "JOIN", "secondary", function()
		act({ action = "joinPrivate", code = box.Text })
	end)
	join.Name = "JoinLobby"
	join.Size = UDim2.fromOffset(120, 40)
end

local function renderPrivateLobby(card: Frame, state: { [string]: any })
	local lobby = state.lobby or {}
	local mode = GameModes.Modes[lobby.size or "2V2"]
	cardTitle(card, "PRIVATE OPERATION", nil, 1)
	local codeRow = Kit.box(card, { Name = "CodeRow", Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 2 })
	Kit.text(codeRow, {
		Name = "CodeLabel",
		Text = "ACCESS CODE",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(0, 120, 1, 0),
	})
	Kit.text(codeRow, {
		Name = "AccessCode",
		Text = lobby.code or "-----",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 38,
		TextColor3 = UI.Accent,
		Position = UDim2.fromOffset(120, 0),
		Size = UDim2.new(1, -120, 1, 0),
	})
	Kit.field(card, "SIZE", mode and mode.Title or "", 3)
	Kit.field(card, "MAP", lobby.mapName or "", 4)
	Kit.field(card, "COMMANDERS", ("%d / %d"):format(#(lobby.members or {}), lobby.capacity or 0), 5)
	local members = Kit.box(card, { Name = "Members", Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 6 })
	Kit.list(members, Enum.FillDirection.Vertical, 0)
	for i, member in lobby.members or {} do
		Kit.text(members, {
			Name = "Member" .. i,
			Text = ("· %s%s%s"):format(
				member.name,
				if member.host then "  [HOST]" else "",
				if member.you then "  (YOU)" else ""
			),
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Small,
			TextColor3 = if member.you then UI.Text else UI.TextDim,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = i,
		})
	end
	if lobby.isHost then
		sizeSelector(card, 7, lobby.size or "2V2", function(size)
			act({ action = "privateOptions", size = size })
		end)
	end
	local row = buttonRow(card, 8)
	if lobby.isHost then
		local prev = Kit.button(row, "◀ MAP", "secondary", function()
			local index = table.find(Maps.Order, lobby.map) or 1
			act({ action = "privateOptions", map = Maps.Order[(index - 2) % #Maps.Order + 1] })
		end)
		prev.Name = "PrevMap"
		prev.Size = UDim2.fromOffset(90, 40)
		local nextMap = Kit.button(row, "MAP ▶", "secondary", function()
			local index = table.find(Maps.Order, lobby.map) or 1
			act({ action = "privateOptions", map = Maps.Order[index % #Maps.Order + 1] })
		end)
		nextMap.Name = "NextMap"
		nextMap.Size = UDim2.fromOffset(90, 40)
		local start = Kit.button(row, "START", "primary", function()
			act({ action = "startPrivate" })
		end)
		start.Name = "StartMatch"
		start.Size = UDim2.fromOffset(130, 40)
		Kit.setEnabled(start, #(lobby.members or {}) >= 2)
	end
	local leave = Kit.button(row, "LEAVE", "danger", function()
		act({ action = "leave" })
	end)
	leave.Name = "LeaveLobby"
	leave.Size = UDim2.fromOffset(110, 40)
end

render = function()
	local card = refs.card
	if not card then
		return
	end
	refs.timer = nil
	refs.timerSince = nil
	refs.timerEndsAt = nil
	Kit.clear(card)
	local state = State.matchmaking or { state = "idle" }
	local kind = state.state
	if kind == "found" or kind == "deploying" or kind == "simulated" or kind == "failed" then
		renderDeploy(card, state)
	elseif kind == "private" then
		renderPrivateLobby(card, state)
	elseif refs.mode == "PRIVATE" then
		if kind == "queued" then
			renderQueued(card, state)
		else
			renderPrivateIdle(card)
		end
	elseif kind == "queued" then
		renderQueued(card, state)
	else
		renderQueueIdle(card)
	end
	local shell = WindowManager.shell("Matchmaking")
	if shell then
		buildLeft(shell)
	end
end

function Panel.build(shell: Shell)
	local left, right = Kit.columns(shell.body, 320, 22)
	refs.left = left
	local cardFrame = Kit.frame(right, {
		Name = "Card",
		BackgroundColor3 = UI.Panel,
		Size = UDim2.new(1, 0, 1, -26),
	})
	Kit.stroke(cardFrame, UI.BorderDim)
	Kit.padding(cardFrame, 18, 18, 16, 16)
	Kit.list(cardFrame, Enum.FillDirection.Vertical, 10)
	refs.card = cardFrame
	refs.status = Kit.text(right, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 20),
	})
	shell.footer.Text = "C3 NETWORK · THE QUEUE FOLLOWS YOU AROUND THE BASE · WALK AWAY TO CLOSE"
	State.changed:Connect(function(key)
		if
			WindowManager.current() == "Matchmaking" and (key == "matchmaking" or key == "status" or key == "profile")
		then
			render()
		end
	end)
	-- live timers
	task.spawn(function()
		while true do
			task.wait(0.25)
			local timer = refs.timer
			if timer and timer.Parent and WindowManager.current() == "Matchmaking" then
				local now = State.serverNow()
				local since = refs.timerSince
				local endsAt = refs.timerEndsAt
				if type(since) == "number" then
					timer.Text = Format.clock(now - since)
				elseif type(endsAt) == "number" then
					timer.Text = ("DEPLOYING IN %d"):format(math.max(0, math.ceil(endsAt - now)))
				end
			end
		end
	end)
end

function Panel.open(shell: Shell, context: WindowManager.Context)
	local modeId = context.id
	if modeId and GameModes.Modes[modeId] then
		refs.mode = modeId
	end
	local mode = GameModes.Modes[refs.mode]
	shell.title.Text = "OPERATIONS CENTER — " .. mode.Title
	local index = table.find(GameModes.Order, refs.mode) or 1
	shell.code.Text = ("C3-NET // OPS TERMINAL %02d // %s"):format(index, mode.Subtitle)
	setStatus("")
	render()
end

return Panel
