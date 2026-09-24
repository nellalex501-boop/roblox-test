--!strict
-- Garage back office: the Unit Registry (collection of every unit with its
-- unlock state, preview and unlock button) and the Paint Shop (buy paint
-- schemes and apply them to units in service, with a live preview).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Units = require(Lobby:WaitForChild("Config"):WaitForChild("Units"))
local Format = require(Lobby:WaitForChild("Util"):WaitForChild("Format"))
local Errors = require(script.Parent.Parent.Errors)
local Kit = require(script.Parent.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local UnitPreview = require(script.Parent.Parent.UnitPreview)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)

local UI = Kit.Colors

type Shell = WindowManager.Shell
type Data = { [string]: any }

local Panel = {} :: WindowManager.Panel
Panel.title = "GARAGE — MOTOR POOL"
Panel.code = "S4 LOGISTICS // UNIT REGISTRY + PAINT SHOP"
Panel.tabs = { "COLLECTION", "PAINT" }
Panel.size = Vector2.new(960, 590)

local refs: {
	tab: string,
	units: { [string]: Data },
	selected: string,
	paintUnit: string,
	previewCamo: string?,
	pages: { [string]: Frame },
	status: TextLabel?,
} =
	{
		tab = "COLLECTION",
		units = {},
		selected = "M1_ABRAMS",
		paintUnit = "M1_ABRAMS",
		previewCamo = nil,
		pages = {},
		status = nil,
	}

local render: () -> ()

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
	render()
end

local function stateBadge(state: Data?): (string, Color3)
	if not state then
		return "…", UI.TextFaint
	elseif state.owned then
		return "IN SERVICE", UI.Success
	elseif state.event then
		return "EVENT", UI.Accent
	elseif state.canUnlock then
		return "AVAILABLE", UI.Phosphor
	end
	return "LOCKED", UI.TextFaint
end

local function unitRow(list: Instance, unitId: string, order: number, selected: boolean, onClick: () -> ())
	local unit = Units.List[unitId]
	local row = Kit.row(list, 40, order, onClick)
	row.Name = "Unit_" .. unitId
	Kit.setSelected(row, selected)
	Kit.text(row, {
		Name = "Name",
		Text = unit.Name,
		FontFace = Kit.Fonts.HeaderLight,
		TextSize = 15,
		Position = UDim2.fromOffset(10, 2),
		Size = UDim2.new(1, -110, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.text(row, {
		Name = "Category",
		Text = unit.Category .. " · " .. Units.Factions[unit.Faction].Name,
		FontFace = Kit.Fonts.Mono,
		TextSize = 10,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(10, 21),
		Size = UDim2.new(1, -110, 0, 14),
	})
	local text, color = stateBadge(refs.units[unitId])
	local badge = Kit.badge(row, text, color)
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, -8, 0.5, 0)
	return row
end

-- COLLECTION ----------------------------------------------------------------

local function renderCollection(page: Frame)
	Kit.clear(page)
	local left, right = Kit.columns(page, 330, 18)
	local list = Kit.scroll(left, nil, 4)
	local order = 0
	for _, faction in { "NATO", "PACT" } do
		order += 1
		Kit.heading(list, Units.Factions[faction].Long, order)
		for _, id in Units.Order do
			if Units.List[id].Faction == faction then
				order += 1
				unitRow(list, id, order, id == refs.selected, function()
					refs.selected = id
					render()
				end)
			end
		end
	end
	local unit = Units.List[refs.selected]
	local state = refs.units[refs.selected]
	local preview =
		Kit.frame(right, { Name = "Preview", BackgroundColor3 = UI.Backdrop, Size = UDim2.new(1, 0, 0, 230) })
	Kit.stroke(preview, UI.Border)
	UnitPreview.mount(preview, unit.Id, state and state.camo)
	local info = Kit.box(right, { Name = "Info", Position = UDim2.fromOffset(0, 240), Size = UDim2.new(1, 0, 1, -262) })
	Kit.list(info, Enum.FillDirection.Vertical, 6)
	Kit.text(info, {
		Name = "UnitName",
		Text = unit.Name,
		FontFace = Kit.Fonts.Header,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 1,
	})
	Kit.text(info, {
		Name = "Role",
		Text = ("%s · %s · CREW %d"):format(Units.Categories[unit.Category] or unit.Category, unit.Role, unit.Crew),
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.Accent,
		LayoutOrder = 2,
	})
	local stats = Kit.box(info, { Name = "Stats", Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 3 })
	for i, stat in { { "Armor", "ARM" }, { "Firepower", "FIRE" }, { "Mobility", "MOB" }, { "Cost", "COST" } } do
		local cell = Kit.box(stats, {
			Name = "Stat_" .. stat[1],
			Position = UDim2.fromScale(((i - 1) % 2) * 0.5, if i > 2 then 0.5 else 0),
			Size = UDim2.new(0.5, -8, 0.5, 0),
		})
		Kit.text(cell, {
			Name = "Label",
			Text = stat[2],
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			Size = UDim2.new(0, 44, 1, 0),
		})
		local bar = Kit.segments(cell, (unit.Stats :: any)[stat[1]], 10)
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new(0, 44, 0.5, 0)
		bar.Size = UDim2.new(1, -44, 0, 8)
	end
	Kit.text(info, {
		Name = "Description",
		Text = unit.Description,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 4,
	})
	local actionRow = Kit.box(info, { Name = "Action", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 5 })
	Kit.text(actionRow, {
		Name = "Requirement",
		Text = if state then state.requirement else "…",
		FontFace = Kit.Fonts.MonoBold,
		TextColor3 = if state and state.owned then UI.Success else UI.Text,
		Size = UDim2.new(0.5, 0, 1, 0),
	})
	if state and not state.owned and not state.event and state.cost > 0 then
		local button = Kit.button(
			actionRow,
			("UNLOCK — %s CR"):format(Format.number(state.cost)),
			"primary",
			function()
				act({ action = "unlock", unit = unit.Id }, unit.Name .. " ADDED TO YOUR MOTOR POOL")
			end
		)
		button.Name = "Unlock"
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.fromScale(1, 0)
		button.Size = UDim2.new(0.5, 0, 1, 0)
		Kit.setEnabled(button, state.canUnlock == true)
	end
end

-- PAINT -----------------------------------------------------------------------

local function ownedCamos(): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	local profile = State.profile
	for _, id in (profile and profile.camosOwned) or {} do
		owned[id] = true
	end
	return owned
end

local function renderPaint(page: Frame)
	Kit.clear(page)
	local left, right = Kit.columns(page, 300, 18)
	local list = Kit.scroll(left, nil, 4)
	Kit.heading(list, "UNITS IN SERVICE", 0)
	local anyOwned = false
	for i, id in Units.Order do
		local state = refs.units[id]
		if state and state.owned then
			anyOwned = true
			unitRow(list, id, i, id == refs.paintUnit, function()
				refs.paintUnit = id
				refs.previewCamo = nil
				render()
			end)
		end
	end
	if not anyOwned then
		Kit.text(list, { Name = "Empty", Text = "NO UNITS IN SERVICE", TextColor3 = UI.TextDim, LayoutOrder = 1 })
	end
	local unit = Units.List[refs.paintUnit]
	local state = refs.units[refs.paintUnit]
	local current = if state then state.camo else "FACTORY"
	local shown = refs.previewCamo or current
	local preview =
		Kit.frame(right, { Name = "Preview", BackgroundColor3 = UI.Backdrop, Size = UDim2.new(1, 0, 0, 250) })
	Kit.stroke(preview, UI.Border)
	UnitPreview.mount(preview, unit.Id, shown)
	Kit.text(preview, {
		Name = "Caption",
		Text = ("%s · %s"):format(unit.Name, Units.Camos.List[shown].Name),
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 18),
		ZIndex = 2,
	})
	local swatches = Kit.box(right, {
		Name = "Swatches",
		Position = UDim2.fromOffset(0, 262),
		Size = UDim2.new(1, 0, 0, 110),
	})
	Kit.list(swatches, Enum.FillDirection.Horizontal, 10)
	local owned = ownedCamos()
	for i, camoId in Units.Camos.Order do
		local camo = Units.Camos.List[camoId]
		local isDefault = camoId == "FACTORY" or camoId == unit.Camo
		local have = owned[camoId] or isDefault
		local swatch = Kit.row(swatches, 100, i, function()
			refs.previewCamo = camoId
			render()
		end)
		swatch.Name = "Camo_" .. camoId
		swatch.Size = UDim2.new(0.2, -8, 0, 104)
		Kit.setSelected(swatch, camoId == shown)
		Kit.frame(swatch, {
			Name = "ColorA",
			BackgroundColor3 = camo.Colors[1],
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 40),
		})
		Kit.frame(swatch, {
			Name = "ColorB",
			BackgroundColor3 = camo.Colors[2],
			Position = UDim2.new(0.3, 0, 0, 20),
			Size = UDim2.new(0.4, 0, 0, 16),
		})
		Kit.text(swatch, {
			Name = "Name",
			Text = camo.Name,
			FontFace = Kit.Fonts.BodyBold,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 52),
			Size = UDim2.new(1, -8, 0, 28),
		})
		Kit.text(swatch, {
			Name = "Price",
			Text = if camoId == current
				then "APPLIED"
				elseif have then "OWNED"
				elseif camo.Cost < 0 then "EVENT REWARD"
				else Format.number(camo.Cost) .. " CR",
			FontFace = Kit.Fonts.Mono,
			TextSize = 10,
			TextColor3 = if camoId == current then UI.Accent elseif have then UI.Success else UI.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 82),
			Size = UDim2.new(1, -8, 0, 14),
		})
	end
	local camo = Units.Camos.List[shown]
	local have = owned[shown] or shown == "FACTORY" or shown == unit.Camo
	local actionRow = Kit.box(right, {
		Name = "Actions",
		Position = UDim2.fromOffset(0, 384),
		Size = UDim2.new(1, 0, 0, 40),
	})
	Kit.list(actionRow, Enum.FillDirection.Horizontal, 10)
	if not have and camo.Cost >= 0 then
		local buy = Kit.button(
			actionRow,
			("BUY %s — %s CR"):format(camo.Name, Format.number(camo.Cost)),
			"primary",
			function()
				act({ action = "buyCamo", camo = shown }, camo.Name .. " PURCHASED")
			end
		)
		buy.Name = "BuyCamo"
		buy.Size = UDim2.fromOffset(320, 40)
		local credits = State.profile and State.profile.credits or 0
		Kit.setEnabled(buy, credits >= camo.Cost)
	elseif have and shown ~= current and state and state.owned then
		local apply = Kit.button(actionRow, "APPLY TO " .. unit.Name, "primary", function()
			act({ action = "setCamo", unit = unit.Id, camo = shown }, camo.Name .. " APPLIED TO " .. unit.Name)
		end)
		apply.Name = "ApplyCamo"
		apply.Size = UDim2.fromOffset(320, 40)
	elseif camo.Cost < 0 and not have then
		Kit.text(actionRow, {
			Name = "EventOnly",
			Text = "EARNED ON AN OPERATION REWARD TRACK",
			FontFace = Kit.Fonts.MonoBold,
			TextColor3 = UI.TextDim,
			Size = UDim2.new(1, 0, 1, 0),
		})
	end
end

render = function()
	for name, page in refs.pages do
		page.Visible = name == refs.tab
	end
	local page = refs.pages[refs.tab]
	if not page then
		return
	end
	if refs.tab == "PAINT" then
		renderPaint(page)
	else
		renderCollection(page)
	end
end

function Panel.build(shell: Shell)
	local tabs: { string } = Panel.tabs or {}
	for _, tab in tabs do
		refs.pages[tab] =
			Kit.box(shell.body, { Name = "Page_" .. tab, Visible = false, Size = UDim2.new(1, 0, 1, -18) })
	end
	refs.status = Kit.text(shell.body, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
	})
	shell.footer.Text = "UNIT REGISTRY · PAINT SHOP · CREDITS ARE EARNED IN BATTLE, MISSIONS AND OPERATIONS"
end

function Panel.selectTab(_shell: Shell, tab: string)
	refs.tab = tab
	render()
end

function Panel.open(_shell: Shell, context: WindowManager.Context)
	say("")
	if context.kind == "UnitCosmetics" then
		refs.previewCamo = nil
	end
	task.spawn(function()
		local response = State.request("Garage", { action = "collection" })
		absorb(response)
		if WindowManager.current() == "Garage" then
			render()
		end
	end)
end

return Panel
