--!strict
-- Command HQ: commander dossier (rank, level, credits, allegiance), service
-- record statistics, customisation (allegiance, title, unit insignia) and
-- achievements. Opened from the HQ office, records room, quartermaster
-- lockers and the trophy case (each opens its own tab).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Config = Lobby:WaitForChild("Config")
local Maps = require(Config:WaitForChild("Maps"))
local Progression = require(Config:WaitForChild("Progression"))
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
Panel.title = "COMMAND HQ"
Panel.code = "S1 PERSONNEL // COMMANDER FILE"
Panel.tabs = { "PROFILE", "STATISTICS", "CUSTOMIZE", "ACHIEVEMENTS" }
Panel.size = Vector2.new(900, 580)

local pages: { [string]: Frame } = {}
local status: TextLabel? = nil
local currentTab = "PROFILE"

local function profile(): Data?
	return State.profile
end

local function insigniaFor(id: string): Progression.Insignia?
	for _, insignia in Progression.Insignia do
		if insignia.Id == id then
			return insignia
		end
	end
	return nil
end

local function titleName(id: string): string
	for _, title in Progression.Titles do
		if title.Id == id then
			return title.Name
		end
	end
	return id
end

local function say(text: string, isError: boolean?)
	local label = status
	if label then
		label.Text = text
		label.TextColor3 = if isError then UI.Danger else UI.Success
	end
end

local function request(payload: Data)
	local response = State.request("Profile", payload)
	if response.ok then
		Sound.play("Confirm")
		say("FILE UPDATED")
	else
		Sound.play("Error")
		say(Errors.text(response.error), true)
	end
end

-- PROFILE ---------------------------------------------------------------

local function renderProfile(page: Frame, p: Data)
	Kit.clear(page)
	-- dossier card
	local card = Kit.frame(page, {
		Name = "Dossier",
		BackgroundColor3 = Color3.fromRGB(196, 184, 150),
		Size = UDim2.fromOffset(330, 420),
	})
	Kit.corner(card, 2)
	Kit.padding(card, 16, 16, 14, 14)
	Kit.list(card, Enum.FillDirection.Vertical, 6)
	local ink = Color3.fromRGB(46, 42, 34)
	Kit.text(card, {
		Name = "Classification",
		Text = "PERSONNEL FILE · RESTRICTED",
		FontFace = Kit.Fonts.Document,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(138, 60, 50),
		LayoutOrder = 1,
	})
	local insignia = insigniaFor(p.insignia)
	local patch = Kit.frame(card, {
		Name = "Insignia",
		BackgroundColor3 = if insignia then insignia.Color else UI.Border,
		Size = UDim2.fromOffset(72, 72),
		LayoutOrder = 2,
	})
	Kit.corner(patch, 36)
	Kit.stroke(patch, ink, 2)
	Kit.text(patch, {
		Name = "Short",
		Text = if insignia then insignia.Short else "?",
		FontFace = Kit.Fonts.Header,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(236, 230, 210),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	Kit.text(card, {
		Name = "Name",
		Text = tostring(p.name or "COMMANDER"):upper(),
		FontFace = Kit.Fonts.Header,
		TextSize = 26,
		TextColor3 = ink,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 3,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.text(card, {
		Name = "Rank",
		Text = ("%s · %s"):format(p.rankShort or "", p.rankName or ""),
		FontFace = Kit.Fonts.Document,
		TextSize = 15,
		TextColor3 = ink,
		LayoutOrder = 4,
	})
	Kit.text(card, {
		Name = "Title",
		Text = "“" .. tostring(p.titleName or titleName(p.title or "")) .. "”",
		FontFace = Kit.Fonts.Document,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(90, 70, 50),
		LayoutOrder = 5,
	})
	local allegiance = if p.faction == "PACT" then "WARSAW PACT" else "NATO"
	for i, line in
		{
			{ "ALLEGIANCE", allegiance },
			{ "UNIT", if insignia then insignia.Name else "UNASSIGNED" },
			{ "PREFERRED MAP", if Maps.List[p.preferredMap or ""] then Maps.List[p.preferredMap].Name else "NONE" },
			{ "SERVICE NO.", ("%09d"):format(math.abs(tonumber(p.userId) or 0) % 1000000000) },
		}
	do
		local row, value = Kit.field(card, line[1], line[2], 5 + i)
		local labelText = row:FindFirstChild("Label")
		if labelText and labelText:IsA("TextLabel") then
			labelText.TextColor3 = Color3.fromRGB(96, 86, 66)
		end
		value.TextColor3 = ink
	end
	if p.temporary then
		Kit.text(card, {
			Name = "Temporary",
			Text = "TEMPORARY FILE — PROGRESS IS NOT SAVED ON THIS SERVER",
			FontFace = Kit.Fonts.MonoBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(138, 60, 50),
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 20,
		})
	end
	-- right column: level + credits
	local right = Kit.box(page, {
		Name = "Summary",
		Position = UDim2.fromOffset(350, 0),
		Size = UDim2.new(1, -350, 1, 0),
	})
	Kit.list(right, Enum.FillDirection.Vertical, 8)
	Kit.heading(right, "COMMANDER LEVEL", 1)
	Kit.text(right, {
		Name = "Level",
		Text = ("LEVEL %d"):format(p.level or 1),
		FontFace = Kit.Fonts.Header,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 2,
	})
	local need = math.max(p.levelNeed or 1, 1)
	local bar = Kit.progress(right, (p.levelXp or 0) / need, UI.Accent, 10)
	bar.LayoutOrder = 3
	Kit.text(right, {
		Name = "Xp",
		Text = ("%s / %s XP TO LEVEL %d"):format(
			Format.number(p.levelXp or 0),
			Format.number(need),
			(p.level or 1) + 1
		),
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		LayoutOrder = 4,
	})
	Kit.heading(right, "SUPPLY", 5)
	Kit.field(right, "CREDITS", Format.number(p.credits or 0) .. " CR", 6)
	Kit.field(right, "UNITS IN SERVICE", tostring(#(p.unitsUnlocked or {})), 7)
	Kit.field(right, "PAINT SCHEMES", tostring(#(p.camosOwned or {})), 8)
	Kit.heading(right, "SERVICE SUMMARY", 9)
	local stats = p.stats or {}
	Kit.field(right, "MATCHES", Format.number(stats.matches or 0), 10)
	Kit.field(right, "VICTORIES", Format.number(stats.victories or 0), 11)
	Kit.field(right, "RATING", Format.number(stats.rating or 1000), 12)
end

-- STATISTICS ------------------------------------------------------------

local function statTile(parent: Instance, label: string, value: string, order: number)
	local tile = Kit.frame(parent, { Name = "Stat_" .. label, BackgroundColor3 = UI.Panel, LayoutOrder = order })
	Kit.stroke(tile, UI.BorderDim)
	Kit.padding(tile, 12, 12, 8, 8)
	Kit.text(tile, {
		Name = "Label",
		Text = label,
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(1, 0, 0, 14),
	})
	Kit.text(tile, {
		Name = "Value",
		Text = value,
		FontFace = Kit.Fonts.Header,
		TextSize = 28,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 34),
	})
end

local function renderStatistics(page: Frame, p: Data)
	Kit.clear(page)
	local s = p.stats or {}
	local grid = Kit.box(page, { Name = "Grid", Size = UDim2.new(1, 0, 0, 200) })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -9, 0, 62),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local matches = s.matches or 0
	local winRate = if matches > 0 then (s.victories or 0) / matches else 0
	local tiles = {
		{ "MATCHES", Format.number(matches) },
		{ "VICTORIES", Format.number(s.victories or 0) },
		{ "DEFEATS", Format.number(s.defeats or 0) },
		{ "WIN RATE", Format.percent(winRate) },
		{ "SECTORS CAPTURED", Format.number(s.sectorsCaptured or 0) },
		{ "UNITS DESTROYED", Format.number(s.unitsDestroyed or 0) },
		{ "TEAM BATTLES", Format.number(s.teamBattles or 0) },
		{ "TIME IN COMMAND", ("%dh %02dm"):format((s.playMinutes or 0) // 60, (s.playMinutes or 0) % 60) },
	}
	for i, tile in tiles do
		statTile(grid, tile[1], tile[2], i)
	end
	local maps = Kit.box(page, {
		Name = "MapsPlayed",
		Position = UDim2.fromOffset(0, 160),
		Size = UDim2.new(1, 0, 1, -160),
	})
	Kit.list(maps, Enum.FillDirection.Vertical, 4)
	Kit.heading(maps, "BATTLEFIELDS", 0)
	local played = s.mapsPlayed or {}
	local won = s.victoriesByMap or {}
	for i, id in Maps.Order do
		local count = played[id] or 0
		local row = Kit.box(maps, { Name = "Map_" .. id, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i })
		Kit.text(row, {
			Name = "Name",
			Text = Maps.List[id].Name,
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Small,
			TextColor3 = if count > 0 then UI.Text else UI.TextFaint,
			Size = UDim2.new(0.4, 0, 1, 0),
		})
		local bar = Kit.progress(row, math.min(count / 20, 1), UI.Phosphor, 6)
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.fromScale(0.4, 0.5)
		bar.Size = UDim2.new(0.35, 0, 0, 6)
		Kit.text(row, {
			Name = "Count",
			Text = ("%d PLAYED · %d WON"):format(count, won[id] or 0),
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.75, 0),
			Size = UDim2.new(0.25, 0, 1, 0),
		})
	end
end

-- CUSTOMIZE -------------------------------------------------------------

local function choiceButton(
	parent: Instance,
	text: string,
	selected: boolean,
	enabled: boolean,
	onClick: () -> ()
): TextButton
	local button = Kit.button(parent, text, if selected then "primary" else "secondary", onClick)
	button.Size = UDim2.fromOffset(200, 32)
	button.TextSize = 14
	if not enabled then
		Kit.setEnabled(button, false)
	end
	return button
end

-- Height of a choice grid (200 x 50 cells, 4 per row, 8 px row gap).
local function gridHeight(count: number): number
	local rows = math.ceil(count / 4)
	return rows * 50 + (rows - 1) * 8
end

local function renderCustomize(page: Frame, p: Data)
	Kit.clear(page)
	local scroll = Kit.scroll(page, nil, 8)
	Kit.heading(scroll, "ALLEGIANCE", 1)
	local factions = Kit.box(scroll, { Name = "Factions", Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2 })
	Kit.list(factions, Enum.FillDirection.Horizontal, 10)
	for i, faction in { "NATO", "PACT" } do
		local b = choiceButton(
			factions,
			if faction == "NATO" then "NATO" else "WARSAW PACT",
			p.faction == faction,
			true,
			function()
				request({ action = "setFaction", faction = faction })
			end
		)
		b.Name = "Faction_" .. faction
		b.LayoutOrder = i
	end
	Kit.text(scroll, {
		Name = "FactionNote",
		Text = "Allegiance changes your rank names and the flag on your file. It does not limit matchmaking.",
		TextColor3 = UI.TextDim,
		TextSize = Kit.Text.Small,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 3,
	})
	Kit.heading(scroll, "TITLE", 4)
	local unlocked: { [string]: boolean } = {}
	for _, id in p.titlesUnlocked or {} do
		unlocked[id] = true
	end
	local titles = Kit.box(scroll, {
		Name = "Titles",
		Size = UDim2.new(1, 0, 0, gridHeight(#Progression.Titles)),
		LayoutOrder = 5,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 50),
		CellPadding = UDim2.fromOffset(10, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = titles,
	})
	for i, title in Progression.Titles do
		local cell = Kit.box(titles, { Name = "Title_" .. title.Id, LayoutOrder = i })
		local b = choiceButton(cell, title.Name, p.title == title.Id, unlocked[title.Id] == true, function()
			request({ action = "setTitle", title = title.Id })
		end)
		b.Name = "Choose"
		Kit.text(cell, {
			Name = "Requirement",
			Text = if unlocked[title.Id] then "EARNED" else title.Requirement,
			FontFace = Kit.Fonts.Mono,
			TextSize = 10,
			TextColor3 = if unlocked[title.Id] then UI.Success else UI.TextFaint,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 14),
		})
	end
	Kit.heading(scroll, "UNIT INSIGNIA", 6)
	local level = p.level or 1
	local insignias = Kit.box(scroll, {
		Name = "Insignia",
		Size = UDim2.new(1, 0, 0, gridHeight(#Progression.Insignia)),
		LayoutOrder = 7,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 50),
		CellPadding = UDim2.fromOffset(10, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = insignias,
	})
	for i, insignia in Progression.Insignia do
		local cell = Kit.box(insignias, { Name = "Insignia_" .. insignia.Id, LayoutOrder = i })
		local b = choiceButton(
			cell,
			insignia.Short .. " · " .. insignia.Name,
			p.insignia == insignia.Id,
			level >= insignia.Level,
			function()
				request({ action = "setInsignia", insignia = insignia.Id })
			end
		)
		b.Name = "Choose"
		b.TextSize = 12
		Kit.frame(b, {
			Name = "Swatch",
			BackgroundColor3 = insignia.Color,
			Size = UDim2.new(0, 4, 1, 0),
		})
		Kit.text(cell, {
			Name = "Requirement",
			Text = if level >= insignia.Level then "AVAILABLE" else ("REQUIRES LEVEL %d"):format(insignia.Level),
			FontFace = Kit.Fonts.Mono,
			TextSize = 10,
			TextColor3 = if level >= insignia.Level then UI.Success else UI.TextFaint,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 14),
		})
	end
end

-- ACHIEVEMENTS ------------------------------------------------------------

local function renderAchievements(page: Frame, p: Data)
	Kit.clear(page)
	local scroll = Kit.scroll(page, nil, 6)
	local done = 0
	for _, a in p.achievements or {} do
		if a.done then
			done += 1
		end
	end
	Kit.text(scroll, {
		Name = "Summary",
		Text = ("%d / %d COMMENDATIONS EARNED"):format(done, #(p.achievements or {})),
		FontFace = Kit.Fonts.MonoBold,
		TextColor3 = UI.Accent,
		TextSize = Kit.Text.Small,
		LayoutOrder = 0,
	})
	for i, a in p.achievements or {} do
		local row = Kit.frame(scroll, {
			Name = "Achievement_" .. tostring(a.id),
			BackgroundColor3 = UI.Panel,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = i,
		})
		Kit.stroke(row, if a.done then UI.AccentDim else UI.BorderDim)
		local medal = Kit.frame(row, {
			Name = "Medal",
			BackgroundColor3 = if a.done then UI.Accent else UI.PanelRaised,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(32, 32),
		})
		Kit.corner(medal, 16)
		Kit.text(medal, {
			Name = "Mark",
			Text = if a.done then "★" else "",
			TextColor3 = UI.Backdrop,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		Kit.text(row, {
			Name = "Name",
			Text = a.name,
			FontFace = Kit.Fonts.Header,
			TextSize = 17,
			TextColor3 = if a.done then UI.Text else UI.TextDim,
			Position = UDim2.fromOffset(56, 6),
			Size = UDim2.new(0.6, -56, 0, 22),
		})
		Kit.text(row, {
			Name = "Description",
			Text = a.description,
			TextSize = Kit.Text.Small,
			TextColor3 = UI.TextDim,
			Position = UDim2.fromOffset(56, 28),
			Size = UDim2.new(0.6, -56, 0, 20),
		})
		local bar = Kit.progress(
			row,
			(a.progress or 0) / math.max(a.target or 1, 1),
			if a.done then UI.Accent else UI.Phosphor,
			8
		)
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new(0.6, 0, 0.5, 0)
		bar.Size = UDim2.new(0.28, 0, 0, 8)
		Kit.text(row, {
			Name = "Progress",
			Text = ("%d / %d"):format(a.progress or 0, a.target or 1),
			FontFace = Kit.Fonts.MonoBold,
			TextSize = Kit.Text.Small,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.88, 0, 0, 0),
			Size = UDim2.new(0.12, -12, 1, 0),
		})
	end
end

local RENDER: { [string]: (Frame, Data) -> () } = {
	PROFILE = renderProfile,
	STATISTICS = renderStatistics,
	CUSTOMIZE = renderCustomize,
	ACHIEVEMENTS = renderAchievements,
}

local function render(tab: string)
	currentTab = tab
	for name, page in pages do
		page.Visible = name == tab
	end
	local p = profile()
	local page = pages[tab]
	if not page then
		return
	end
	if not p then
		Kit.clear(page)
		Kit.text(page, { Name = "Loading", Text = "RETRIEVING COMMANDER FILE…", TextColor3 = UI.TextDim })
		return
	end
	RENDER[tab](page, p)
end

function Panel.build(shell: Shell)
	local tabs: { string } = Panel.tabs or {}
	for _, tab in tabs do
		pages[tab] = Kit.box(shell.body, { Name = "Page_" .. tab, Visible = false, Size = UDim2.new(1, 0, 1, -18) })
	end
	status = Kit.text(shell.body, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
	})
	shell.footer.Text = "COMMAND HQ · PROFILE, RECORDS, QUARTERMASTER, HALL OF HONOUR · WALK AWAY TO CLOSE"
	State.changed:Connect(function(key)
		if key == "profile" and WindowManager.current() == "Profile" then
			render(currentTab)
		end
	end)
end

function Panel.selectTab(_shell: Shell, tab: string)
	render(tab)
end

function Panel.open(_shell: Shell, _context: WindowManager.Context)
	say("")
end

return Panel
