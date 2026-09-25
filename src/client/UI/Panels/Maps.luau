--!strict
-- Map Room: battle map dossiers (top-down preview, size, terrain,
-- recommended players, landmark) with "set as preferred map" for
-- matchmaking, and the Fulda Gap theater overview with every map marked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Config = Lobby:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("GameModes"))
local Maps = require(Config:WaitForChild("Maps"))
local MapDraw = require(Lobby:WaitForChild("Util"):WaitForChild("MapDraw"))
local Errors = require(script.Parent.Parent.Errors)
local Kit = require(script.Parent.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)

local UI = Kit.Colors

type Shell = WindowManager.Shell

local Panel = {} :: WindowManager.Panel
Panel.title = "MAP ROOM"
Panel.code = "G2 INTELLIGENCE // BATTLE MAP DOSSIERS"
Panel.tabs = { "MAPS", "THEATER" }
Panel.size = Vector2.new(940, 580)

local refs: {
	selected: string,
	mapsPage: Frame?,
	theaterPage: Frame?,
	rows: { [string]: TextButton },
	preview: Frame?,
	details: Frame?,
	theaterCanvas: Frame?,
	theaterRows: { [string]: TextButton },
	status: TextLabel?,
} =
	{
		selected = Maps.Featured,
		mapsPage = nil,
		theaterPage = nil,
		rows = {},
		preview = nil,
		details = nil,
		theaterCanvas = nil,
		theaterRows = {},
		status = nil,
	}

local function preferred(): string
	local profile = State.profile
	return if profile and type(profile.preferredMap) == "string" then profile.preferredMap else ""
end

local function recommendedText(info: Maps.MapInfo): string
	local names = {}
	for _, modeId in info.Recommended do
		local mode = GameModes.Modes[modeId]
		table.insert(names, if mode then mode.SignText:upper() else modeId)
	end
	return table.concat(names, " · ")
end

local renderDetails: () -> ()

local function setPreferred(id: string)
	local response = State.request("Profile", { action = "setPreferredMap", map = id })
	local status = refs.status
	if response.ok then
		Sound.play("Confirm")
		if status then
			status.Text = if id == ""
				then "PREFERRED MAP CLEARED"
				else "PREFERRED MAP SET — MATCHMAKING WILL FAVOR IT WHEN POSSIBLE"
			status.TextColor3 = UI.Success
		end
	else
		Sound.play("Error")
		if status then
			status.Text = Errors.text(response.error)
			status.TextColor3 = UI.Danger
		end
	end
	renderDetails()
end

renderDetails = function()
	local info = Maps.List[refs.selected]
	local preview, details = refs.preview, refs.details
	if not info or not preview or not details then
		return
	end
	for id, row in refs.rows do
		Kit.setSelected(row, id == refs.selected)
		local star = row:FindFirstChild("Preferred")
		if star and star:IsA("TextLabel") then
			star.Visible = id == preferred()
		end
	end
	Kit.clear(preview)
	MapDraw.preview(preview, info, 320, 320)
	Kit.clear(details)
	Kit.text(details, {
		Name = "MapName",
		Text = info.Name,
		FontFace = Kit.Fonts.Header,
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
	})
	Kit.text(details, {
		Name = "Tagline",
		Text = info.Tagline,
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Accent,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 2,
	})
	Kit.field(details, "SIZE", ("%s · %s"):format(info.Size, info.Dimensions), 3)
	Kit.field(details, "TERRAIN", info.Terrain, 4)
	Kit.field(details, "PLAYERS", info.Players, 5)
	Kit.field(details, "RECOMMENDED", recommendedText(info), 6)
	Kit.field(details, "LANDMARK", info.Landmark, 7)
	Kit.text(details, {
		Name = "Description",
		Text = info.Description,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(1, 0, 0, 80),
		LayoutOrder = 8,
	})
	local isPreferred = preferred() == info.Id
	local button = Kit.button(
		details,
		if isPreferred then "PREFERRED MAP ✓" else "SET AS PREFERRED MAP",
		if isPreferred then "secondary" else "primary",
		function()
			setPreferred(if isPreferred then "" else info.Id)
		end
	)
	button.Name = "SetPreferred"
	button.Size = UDim2.fromOffset(240, 38)
	button.LayoutOrder = 9
end

local function renderTheater()
	local canvasHolder = refs.theaterCanvas
	if not canvasHolder then
		return
	end
	Kit.clear(canvasHolder)
	MapDraw.theater(canvasHolder, 540, 400, { highlight = refs.selected })
	for id, row in refs.theaterRows do
		Kit.setSelected(row, id == refs.selected)
	end
end

local function select(id: string)
	refs.selected = id
	renderDetails()
	renderTheater()
end

local function buildMapsPage(page: Frame)
	local left, right = Kit.columns(page, 240, 16)
	local list = Kit.scroll(left, nil, 4)
	for i, id in Maps.Order do
		local info = Maps.List[id]
		local row = Kit.row(list, 44, i, function()
			Sound.play("Map")
			select(id)
		end)
		row.Name = "Map_" .. id
		Kit.text(row, {
			Name = "Index",
			Text = ("%02d"):format(i),
			FontFace = Kit.Fonts.MonoBold,
			TextColor3 = UI.Accent,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(0, 28, 1, 0),
		})
		Kit.text(row, {
			Name = "Name",
			Text = info.Name,
			FontFace = Kit.Fonts.HeaderLight,
			TextSize = 16,
			Position = UDim2.fromOffset(42, 4),
			Size = UDim2.new(1, -70, 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Kit.text(row, {
			Name = "Size",
			Text = info.Size .. " · " .. info.Players .. " PLAYERS",
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			Position = UDim2.fromOffset(42, 23),
			Size = UDim2.new(1, -70, 0, 14),
		})
		Kit.text(row, {
			Name = "Preferred",
			Text = "★",
			TextColor3 = UI.Accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(1, -28, 0, 0),
			Size = UDim2.new(0, 24, 1, 0),
			Visible = false,
		})
		refs.rows[id] = row
	end
	local preview = Kit.frame(right, {
		Name = "Preview",
		BackgroundColor3 = UI.Backdrop,
		Size = UDim2.fromOffset(320, 320),
	})
	Kit.stroke(preview, UI.Border)
	refs.preview = preview
	local legend = Kit.text(right, {
		Name = "Legend",
		Text = "■ BLUE SPAWN   ■ RED SPAWN   ◆ LANDMARK   A–F CAPTURE SECTORS",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(0, 328),
		Size = UDim2.fromOffset(320, 16),
	})
	legend.TextWrapped = true
	local details = Kit.box(right, {
		Name = "Details",
		Position = UDim2.fromOffset(340, 0),
		Size = UDim2.new(1, -340, 1, -22),
	})
	Kit.list(details, Enum.FillDirection.Vertical, 6)
	refs.details = details
	refs.status = Kit.text(right, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		Position = UDim2.new(0, 340, 1, -18),
		Size = UDim2.new(1, -340, 0, 18),
		TextWrapped = true,
	})
end

local function buildTheaterPage(page: Frame)
	local canvasHolder = Kit.frame(page, {
		Name = "Theater",
		BackgroundColor3 = UI.Backdrop,
		Size = UDim2.fromOffset(540, 400),
	})
	Kit.stroke(canvasHolder, UI.Border)
	refs.theaterCanvas = canvasHolder
	local side = Kit.box(page, {
		Name = "Side",
		Position = UDim2.fromOffset(560, 0),
		Size = UDim2.new(1, -560, 1, 0),
	})
	Kit.list(side, Enum.FillDirection.Vertical, 6)
	Kit.heading(side, "FULDA GAP SECTOR", 0)
	local legend: { { text: string, color: Color3 } } = {
		{ text = "━ BORDER (IGB)", color = UI.TextDim },
		{ text = "━ NATO FORWARD LINE", color = UI.Nato },
		{ text = "➜ WARSAW PACT AXES", color = UI.Pact },
		{ text = "━ RIVERS · AUTOBAHN", color = UI.Phosphor },
	}
	for i, item in legend do
		Kit.text(side, {
			Name = "Legend" .. i,
			Text = item.text,
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = item.color,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = i,
		})
	end
	Kit.heading(side, "BATTLE MAPS", 10)
	for i, id in Maps.Order do
		local info = Maps.List[id]
		local row = Kit.row(side, 26, 10 + i, function()
			Sound.play("Map")
			select(id)
		end)
		row.Name = "TheaterMap_" .. id
		Kit.text(row, {
			Name = "Label",
			Text = ("%d  %s"):format(i, info.Name),
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Small,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -8, 1, 0),
		})
		refs.theaterRows[id] = row
	end
	local open = Kit.button(side, "OPEN DOSSIER", "primary", function()
		local shell = WindowManager.shell("Maps")
		if shell then
			WindowManager.setTab(shell, "MAPS")
		end
	end)
	open.Name = "OpenDossier"
	open.LayoutOrder = 30
	open.Size = UDim2.fromOffset(180, 34)
end

function Panel.build(shell: Shell)
	local mapsPage = Kit.box(shell.body, { Name = "MapsPage" })
	local theaterPage = Kit.box(shell.body, { Name = "TheaterPage", Visible = false })
	refs.mapsPage = mapsPage
	refs.theaterPage = theaterPage
	buildMapsPage(mapsPage)
	buildTheaterPage(theaterPage)
	shell.footer.Text = "PREFERRED MAP IS USED WHEN MATCHMAKING PICKS A BATTLEFIELD · WALK AWAY TO CLOSE"
	State.changed:Connect(function(key)
		if key == "profile" and WindowManager.current() == "Maps" then
			renderDetails()
		end
	end)
end

function Panel.selectTab(_shell: Shell, tab: string)
	local mapsPage, theaterPage = refs.mapsPage, refs.theaterPage
	if mapsPage and theaterPage then
		mapsPage.Visible = tab == "MAPS"
		theaterPage.Visible = tab == "THEATER"
	end
	if tab == "THEATER" then
		renderTheater()
	else
		renderDetails()
	end
end

function Panel.open(shell: Shell, context: WindowManager.Context)
	local id = context.id
	if id and Maps.List[id] then
		refs.selected = id
	end
	shell.title.Text = if context.kind == "TheaterMap" then "THEATER MAP — FULDA GAP" else "MAP ROOM"
	local status = refs.status
	if status then
		status.Text = ""
	end
end

return Panel
