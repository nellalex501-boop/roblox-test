--!strict
-- Garage showroom viewer: a full-screen view of the vehicle on the
-- turntable. The camera focuses on the vehicle (drag to turn, wheel to
-- zoom); the UI frames it on both sides:
-- * left: every vehicle on file, filtered by faction; picking one puts it
--   on the turntable (for this player) and counts as inspecting it;
-- * right: INFO (role, ratings, technical data, history, acquisition with
--   the unlock button) and PAINT (schemes previewed live on the vehicle,
--   bought and applied here);
-- * bottom: the vehicle's name plate and the controls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Units = require(Lobby:WaitForChild("Config"):WaitForChild("Units"))
local Format = require(Lobby:WaitForChild("Util"):WaitForChild("Format"))
local Errors = require(script.Parent.Parent.Errors)
local Kit = require(script.Parent.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)
local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local ShowroomController = require(script.Parent.Parent.Parent.Controllers.ShowroomController)

local UI = Kit.Colors

type Shell = WindowManager.Shell
type Data = { [string]: any }

local Panel = {} :: WindowManager.Panel
Panel.title = "VEHICLE SHOWROOM"
Panel.code = "S4 LOGISTICS // MOTOR POOL"
Panel.dock = "fullscreen"

local SIDE_WIDTH = 330
local DETAIL_WIDTH = 370
local TABS = { "INFO", "PAINT" }
local FILTERS = { "ALL", "NATO", "PACT" }
local STAT_LABELS =
	{ { "Armor", "ARMOR" }, { "Firepower", "FIREPOWER" }, { "Mobility", "MOBILITY" }, { "Cost", "COST" } }
local SPEC_LABELS = {
	{ "Weight", "WEIGHT" },
	{ "Engine", "ENGINE" },
	{ "Speed", "TOP SPEED" },
	{ "Range", "RANGE" },
	{ "Crew", "CREW" },
	{ "Service", "IN SERVICE" },
}

local refs: {
	units: { [string]: Data },
	selected: string,
	filter: string,
	tab: string,
	previewCamo: string?,
	list: ScrollingFrame?,
	rows: { [string]: TextButton },
	detail: ScrollingFrame?,
	tabButtons: { [string]: TextButton },
	filterButtons: { [string]: TextButton },
	status: TextLabel?,
	credits: TextLabel?,
	plateName: TextLabel?,
	plateLine: TextLabel?,
	hint: TextLabel?,
} =
	{
		units = {},
		selected = ShowroomController.DefaultUnit,
		filter = "ALL",
		tab = "INFO",
		previewCamo = nil,
		list = nil,
		rows = {},
		detail = nil,
		tabButtons = {},
		filterButtons = {},
		status = nil,
		credits = nil,
		plateName = nil,
		plateLine = nil,
		hint = nil,
	}

local renderDetail: () -> ()
local renderList: () -> ()

local function say(text: string, isError: boolean?)
	local status = refs.status
	if status then
		status.Text = text
		status.TextColor3 = if isError then UI.Danger else UI.Success
	end
end

local function absorb(response: Data)
	if type(response.units) == "table" then
		table.clear(refs.units)
		for _, state in response.units do
			refs.units[state.id] = state
		end
	end
	local credits = refs.credits
	local profile = State.profile
	if credits and profile then
		credits.Text = Format.number(profile.credits or 0) .. " CR"
	end
end

local function factionColor(unit: Units.Unit): Color3
	return if unit.Faction == "PACT" then UI.Pact else UI.Nato
end

local function stateBadge(state: Data?): (string, Color3)
	if not state then
		return "—", UI.TextFaint
	elseif state.owned then
		return "IN SERVICE", UI.Success
	elseif state.event then
		return "EVENT", UI.Danger
	elseif state.canUnlock then
		return Format.number(state.cost) .. " CR", UI.Accent
	end
	return state.requirement, UI.TextDim
end

local function panelBox(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local box = Kit.frame(parent, {
		Name = name,
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.08,
		Position = position,
		Size = size,
	})
	Kit.stroke(box, UI.BorderDim)
	Kit.corner(box, 3)
	return box
end

-- Shows the unit on the turntable and in the UI; counts as inspecting it.
local function choose(unitId: string)
	if not Units.List[unitId] then
		return
	end
	refs.selected = unitId
	refs.previewCamo = nil
	local state = refs.units[unitId]
	local model = ShowroomController.show(unitId, state and state.camo)
	if model then
		CameraController.retarget(model)
	end
	for id, row in refs.rows do
		Kit.setSelected(row, id == unitId)
	end
	local unit = Units.List[unitId]
	local plateName, plateLine = refs.plateName, refs.plateLine
	if plateName then
		plateName.Text = unit.Name
	end
	if plateLine then
		plateLine.Text = ("%s · %s"):format(
			Units.Factions[unit.Faction].Name,
			Units.Categories[unit.Category] or unit.Category
		)
		plateLine.TextColor3 = factionColor(unit)
	end
	say("")
	renderDetail()
	task.spawn(function()
		State.request("Garage", { action = "view", unit = unitId })
	end)
end

local function act(payload: Data, success: string)
	local response = State.request("Garage", payload)
	absorb(response)
	if response.ok then
		Sound.play(if payload.action == "setCamo" then "Confirm" else "Reward")
		say(success)
	else
		Sound.play("Error")
		say(Errors.text(response.error), true)
	end
	local state = refs.units[refs.selected]
	if payload.action ~= "buyCamo" then
		refs.previewCamo = nil
		ShowroomController.paint((state and state.camo) or "FACTORY")
	end
	renderList()
	renderDetail()
end

renderList = function()
	local list = refs.list
	if not list then
		return
	end
	Kit.clear(list)
	table.clear(refs.rows)
	local order = 0
	for _, faction in { "NATO", "PACT" } do
		if refs.filter == "ALL" or refs.filter == faction then
			order += 1
			Kit.heading(list, Units.Factions[faction].Long, order)
			for _, id in Units.Order do
				local unit = Units.List[id]
				if unit.Faction == faction then
					order += 1
					local row = Kit.row(list, 54, order, function()
						choose(id)
					end)
					row.Name = "Unit_" .. id
					Kit.frame(row, {
						Name = "Strip",
						BackgroundColor3 = factionColor(unit),
						Size = UDim2.new(0, 4, 1, 0),
					})
					Kit.text(row, {
						Name = "Name",
						Text = unit.Name,
						FontFace = Kit.Fonts.Header,
						TextSize = 17,
						Position = UDim2.fromOffset(14, 6),
						Size = UDim2.new(1, -120, 0, 22),
						TextTruncate = Enum.TextTruncate.AtEnd,
					})
					Kit.text(row, {
						Name = "Category",
						Text = Units.Categories[unit.Category] or unit.Category,
						FontFace = Kit.Fonts.Mono,
						TextSize = Kit.Text.Tiny,
						TextColor3 = UI.TextDim,
						Position = UDim2.fromOffset(14, 29),
						Size = UDim2.new(1, -120, 0, 16),
						TextTruncate = Enum.TextTruncate.AtEnd,
					})
					local text, color = stateBadge(refs.units[id])
					local badge = Kit.text(row, {
						Name = "State",
						Text = text,
						FontFace = Kit.Fonts.MonoBold,
						TextSize = Kit.Text.Tiny,
						TextColor3 = color,
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(100, 18),
					})
					badge.TextWrapped = true
					refs.rows[id] = row
					Kit.setSelected(row, id == refs.selected)
				end
			end
		end
	end
	for name, button in refs.filterButtons do
		Kit.setSelected(button, name == refs.filter)
	end
end

local function statRow(parent: Instance, label: string, value: number, color: Color3, order: number)
	local row = Kit.box(parent, { Name = "Stat_" .. label, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order })
	Kit.text(row, {
		Name = "Label",
		Text = label,
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(0.34, 0, 1, 0),
	})
	local bar = Kit.segments(row, value, 10, color)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0.34, 0.5)
	bar.Size = UDim2.new(0.66, 0, 0, 10)
end

local function renderInfo(detail: ScrollingFrame, unit: Units.Unit, state: Data?)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	Kit.text(detail, {
		Name = "Role",
		Text = unit.Role,
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Accent,
		LayoutOrder = nextOrder(),
	})
	local badges = Kit.box(detail, { Name = "Badges", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nextOrder() })
	Kit.list(badges, Enum.FillDirection.Horizontal, 6)
	Kit.badge(badges, Units.Factions[unit.Faction].Name, factionColor(unit), 1)
	Kit.badge(badges, unit.Status, UI.Phosphor, 2)
	Kit.heading(detail, "RATINGS", nextOrder())
	for _, stat in STAT_LABELS do
		local value = (unit.Stats :: any)[stat[1]] :: number
		statRow(detail, stat[2], value, if stat[1] == "Cost" then UI.Accent else UI.Phosphor, nextOrder())
	end
	Kit.heading(detail, "TECHNICAL DATA", nextOrder())
	for _, spec in SPEC_LABELS do
		Kit.field(detail, spec[2], (unit.Specs :: any)[spec[1]] :: string, nextOrder())
	end
	Kit.text(detail, {
		Name = "ArmamentLabel",
		Text = "ARMAMENT",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		LayoutOrder = nextOrder(),
	})
	Kit.text(detail, {
		Name = "Armament",
		Text = unit.Specs.Armament,
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = nextOrder(),
	})
	Kit.heading(detail, "SERVICE HISTORY", nextOrder())
	Kit.text(detail, {
		Name = "Description",
		Text = unit.Description,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = nextOrder(),
	})
	Kit.text(detail, {
		Name = "History",
		Text = unit.History,
		TextWrapped = true,
		TextColor3 = UI.TextDim,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = nextOrder(),
	})
	Kit.heading(detail, "ACQUISITION", nextOrder())
	local text, color = stateBadge(state)
	local _, value = Kit.field(detail, "STATUS", text, nextOrder())
	value.TextColor3 = color
	if state and not state.owned and not state.event then
		local unlock = Kit.button(
			detail,
			("UNLOCK · %s CR"):format(Format.number(state.cost or 0)),
			"primary",
			function()
				act({ action = "unlock", unit = unit.Id }, "UNIT ACQUIRED · NOW IN SERVICE")
			end
		)
		unlock.Name = "Unlock"
		unlock.Size = UDim2.new(1, 0, 0, 36)
		unlock.LayoutOrder = nextOrder()
		Kit.setEnabled(unlock, state.canUnlock == true)
	elseif state and state.event and not state.owned then
		Kit.text(detail, {
			Name = "EventNote",
			Text = "EARNED ON THE CURRENT OPERATION'S REWARD TRACK — SEE THE EVENT AREA",
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = nextOrder(),
		})
	end
end

local function renderPaint(detail: ScrollingFrame, unit: Units.Unit, state: Data?)
	local owned: { [string]: boolean } = {}
	local profile = State.profile
	for _, id in (profile and profile.camosOwned) or {} do
		owned[id] = true
	end
	owned.FACTORY = true
	local applied = (state and state.camo) or "FACTORY"
	local chosen = refs.previewCamo or applied
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local _, current = Kit.field(detail, "APPLIED SCHEME", Units.Camos.List[applied].Name, nextOrder())
	current.TextColor3 = UI.Accent
	local grid = Kit.box(detail, { Name = "Schemes", Size = UDim2.new(1, 0, 0, 250), LayoutOrder = nextOrder() })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -5, 0, 76)
	layout.CellPadding = UDim2.fromOffset(10, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, camoId in Units.Camos.Order do
		local camo = Units.Camos.List[camoId]
		local cell = Kit.row(grid, 76, i, function()
			refs.previewCamo = camoId
			ShowroomController.paint(camoId)
			renderDetail()
		end)
		cell.Name = "Camo_" .. camoId
		Kit.frame(cell, {
			Name = "Base",
			BackgroundColor3 = camo.Colors[1],
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 30),
		})
		Kit.frame(cell, {
			Name = "Accent",
			BackgroundColor3 = camo.Colors[2],
			Position = UDim2.new(0.3, 0, 0, 14),
			Size = UDim2.new(0.25, 0, 0, 14),
		})
		local label = if owned[camoId]
			then "OWNED"
			elseif camo.Cost < 0 then "EVENT REWARD"
			else Format.number(camo.Cost) .. " CR"
		Kit.text(cell, {
			Name = "Name",
			Text = camo.Name,
			FontFace = Kit.Fonts.Header,
			TextSize = 13,
			Position = UDim2.fromOffset(8, 42),
			Size = UDim2.new(1, -16, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Kit.text(cell, {
			Name = "Price",
			Text = label,
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = if owned[camoId] then UI.Success else UI.TextDim,
			Position = UDim2.fromOffset(8, 57),
			Size = UDim2.new(1, -16, 0, 14),
		})
		Kit.setSelected(cell, camoId == chosen)
	end
	local camo = Units.Camos.List[chosen]
	if not owned[chosen] and camo.Cost >= 0 then
		local credits = profile and profile.credits or 0
		local buy = Kit.button(
			detail,
			("BUY %s · %s CR"):format(camo.Name, Format.number(camo.Cost)),
			"primary",
			function()
				act({ action = "buyCamo", camo = chosen }, "PAINT SCHEME PURCHASED")
			end
		)
		buy.Name = "BuyCamo"
		buy.Size = UDim2.new(1, 0, 0, 36)
		buy.LayoutOrder = nextOrder()
		Kit.setEnabled(buy, credits >= camo.Cost)
	elseif owned[chosen] then
		local apply = Kit.button(detail, "APPLY TO " .. unit.Name, "primary", function()
			act({ action = "setCamo", unit = unit.Id, camo = chosen }, "PAINT SCHEME APPLIED")
		end)
		apply.Name = "ApplyCamo"
		apply.Size = UDim2.new(1, 0, 0, 36)
		apply.LayoutOrder = nextOrder()
		Kit.setEnabled(apply, (state and state.owned) == true and chosen ~= applied)
		if not (state and state.owned) then
			Kit.text(detail, {
				Name = "PaintNote",
				Text = "UNLOCK THE VEHICLE TO REPAINT IT",
				FontFace = Kit.Fonts.Mono,
				TextSize = Kit.Text.Tiny,
				TextColor3 = UI.TextDim,
				LayoutOrder = nextOrder(),
			})
		end
	end
	Kit.text(detail, {
		Name = "PreviewNote",
		Text = "SCHEMES PREVIEW ON THE VEHICLE — ONLY APPLIED ONES ARE SAVED",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextFaint,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = nextOrder(),
	})
end

renderDetail = function()
	local detail = refs.detail
	local unit = Units.List[refs.selected]
	if not detail or not unit then
		return
	end
	Kit.clear(detail)
	local state = refs.units[unit.Id]
	if refs.tab == "PAINT" then
		renderPaint(detail, unit, state)
	else
		renderInfo(detail, unit, state)
	end
	for name, button in refs.tabButtons do
		Kit.setSelected(button, name == refs.tab)
	end
end

local function tabBar(parent: Instance, names: { string }, buttons: { [string]: TextButton }, onPick: (string) -> ())
	local bar = Kit.box(parent, { Name = "TabBar", Size = UDim2.new(1, 0, 0, 34) })
	Kit.list(bar, Enum.FillDirection.Horizontal, 6)
	for i, name in names do
		local button = Kit.row(bar, 34, i, function()
			onPick(name)
		end)
		button.Name = "Tab_" .. name
		button.Size = UDim2.new(1 / #names, -6, 1, 0)
		Kit.text(button, {
			Name = "Label",
			Text = name,
			FontFace = Kit.Fonts.Header,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		buttons[name] = button
	end
	return bar
end

function Panel.build(shell: Shell)
	local body = shell.body
	-- top bar
	local top = Kit.frame(body, {
		Name = "TopBar",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, 0, 0, 58),
	})
	Kit.frame(top, { Name = "Accent", BackgroundColor3 = UI.Accent, Size = UDim2.new(0, 5, 1, 0) })
	Kit.text(top, {
		Name = "Code",
		Text = Panel.code .. " · 11TH ARMORED CAVALRY",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(22, 7),
		Size = UDim2.new(0.6, 0, 0, 14),
	})
	Kit.text(top, {
		Name = "Title",
		Text = "MOTOR POOL — VEHICLE SHOWROOM",
		FontFace = Kit.Fonts.Header,
		TextSize = Kit.Text.Title,
		Position = UDim2.fromOffset(22, 21),
		Size = UDim2.new(0.6, 0, 0, 32),
	})
	refs.credits = Kit.text(top, {
		Name = "Credits",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 16,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.5, 0),
		Size = UDim2.fromOffset(200, 24),
	})
	local close = WindowManager.closeButton(top)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -14, 0.5, 0)

	-- left: vehicles on file
	local side = panelBox(body, "VehicleList", UDim2.fromOffset(18, 72), UDim2.new(0, SIDE_WIDTH, 1, -170))
	Kit.padding(side, 12, 12, 10, 10)
	Kit.text(side, {
		Name = "Heading",
		Text = "VEHICLES ON FILE",
		FontFace = Kit.Fonts.Header,
		TextSize = Kit.Text.Section,
		TextColor3 = UI.Accent,
		Size = UDim2.new(1, 0, 0, 22),
	})
	local filters = tabBar(side, FILTERS, refs.filterButtons, function(name)
		refs.filter = name
		renderList()
	end)
	filters.Position = UDim2.fromOffset(0, 28)
	refs.list = Kit.scroll(side, {
		Name = "Units",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
	}, 6)

	-- right: details
	local right =
		panelBox(body, "Details", UDim2.new(1, -(DETAIL_WIDTH + 18), 0, 72), UDim2.new(0, DETAIL_WIDTH, 1, -170))
	Kit.padding(right, 14, 14, 10, 10)
	tabBar(right, TABS, refs.tabButtons, function(name)
		refs.tab = name
		Sound.play("Click")
		renderDetail()
	end)
	refs.detail = Kit.scroll(right, {
		Name = "Detail",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -72),
	}, 6)
	refs.status = Kit.text(right, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- bottom: name plate and controls
	local plate = Kit.frame(body, {
		Name = "NamePlate",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(520, 76),
	})
	Kit.stroke(plate, UI.BorderDim)
	Kit.corner(plate, 3)
	refs.plateName = Kit.text(plate, {
		Name = "VehicleName",
		Text = "",
		FontFace = Kit.Fonts.Header,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 34),
	})
	refs.plateLine = Kit.text(plate, {
		Name = "VehicleLine",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 16),
	})
	refs.hint = Kit.text(plate, {
		Name = "Controls",
		Text = "",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 14),
	})
end

local function controlsHint(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "DRAG TO TURN · PINCH TO ZOOM"
	end
	local last = UserInputService:GetLastInputType()
	if last.Name:sub(1, 7) == "Gamepad" then
		return "RIGHT STICK TO TURN · [B] CLOSE"
	end
	return "DRAG TO TURN · WHEEL TO ZOOM · [X] CLOSE"
end

function Panel.open(_shell: Shell, context: WindowManager.Context)
	absorb(State.request("Garage", { action = "collection" }))
	local hint = refs.hint
	if hint then
		hint.Text = controlsHint()
	end
	local wanted = context.id
	local unitId = if wanted and Units.List[wanted] then wanted else ShowroomController.current()
	renderList()
	choose(unitId)
	local model = ShowroomController.model()
	if model and not CameraController.isOrbiting() then
		-- the zoom cap keeps the camera inside the hall (the nearest wall is
		-- 29 studs from the turntable) and out of the open doors
		CameraController.startOrbit(model, { pitch = math.rad(14), maxDistance = 26, maxPitch = math.rad(50) })
	end
end

function Panel.close(_shell: Shell)
	-- drop an unsaved paint preview: the vehicle keeps its applied scheme
	local state = refs.units[refs.selected]
	refs.previewCamo = nil
	ShowroomController.paint((state and state.camo) or "FACTORY")
end

State.changed:Connect(function(key: string)
	if key == "profile" and WindowManager.current() == "Showroom" then
		absorb({})
	end
end)

return Panel
