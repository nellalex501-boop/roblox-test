--!strict
-- Vehicle inspection: a technical data sheet docked on the right while the
-- camera orbits the physical vehicle on display (Garage showcase and the
-- event's limited units). Shows role, crew, ratings, description and how
-- to get the unit, with an unlock button when it can be bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Units = require(Lobby:WaitForChild("Config"):WaitForChild("Units"))
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
Panel.title = "VEHICLE INSPECTION"
Panel.code = "MOTOR POOL // TECHNICAL DATA SHEET"
Panel.size = Vector2.new(420, 600)
Panel.dock = "right"

local refs: { unitId: string, sheet: Frame?, status: TextLabel?, units: { [string]: Data } } = {
	unitId = "M1_ABRAMS",
	sheet = nil,
	status = nil,
	units = {},
}

local STAT_LABELS =
	{ { "Armor", "ARMOR" }, { "Firepower", "FIREPOWER" }, { "Mobility", "MOBILITY" }, { "Cost", "COST" } }

local render: () -> ()

local function loadStates()
	local response = State.request("Garage", { action = "collection" })
	if response.ok and type(response.units) == "table" then
		table.clear(refs.units)
		for _, state in response.units do
			refs.units[state.id] = state
		end
	end
end

local function unlock(unitId: string)
	local response = State.request("Garage", { action = "unlock", unit = unitId })
	local status = refs.status
	if response.ok then
		Sound.play("Reward")
	else
		Sound.play("Error")
		if status then
			status.Text = Errors.text(response.error)
			status.TextColor3 = UI.Danger
		end
	end
	if type(response.units) == "table" then
		for _, state in response.units do
			refs.units[state.id] = state
		end
	end
	render()
end

render = function()
	local sheet = refs.sheet
	local unit = Units.List[refs.unitId]
	if not sheet or not unit then
		return
	end
	Kit.clear(sheet)
	local factionColor = if unit.Faction == "PACT" then UI.Pact else UI.Nato
	Kit.text(sheet, {
		Name = "Category",
		Text = Units.Categories[unit.Category] or unit.Category,
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Accent,
		LayoutOrder = 1,
	})
	local badges = Kit.box(sheet, { Name = "Badges", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2 })
	Kit.list(badges, Enum.FillDirection.Horizontal, 6)
	Kit.badge(badges, Units.Factions[unit.Faction].Name, factionColor, 1)
	Kit.badge(badges, unit.Status, UI.Phosphor, 2)
	Kit.field(sheet, "ROLE", unit.Role, 3)
	Kit.field(sheet, "CREW", tostring(unit.Crew), 4)
	for i, stat in STAT_LABELS do
		local row = Kit.box(sheet, { Name = "Stat_" .. stat[1], Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 4 + i })
		Kit.text(row, {
			Name = "Label",
			Text = stat[2],
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Small,
			TextColor3 = UI.TextDim,
			Size = UDim2.new(0.34, 0, 1, 0),
		})
		local value = (unit.Stats :: any)[stat[1]] :: number
		local bar = Kit.segments(row, value, 10, if stat[1] == "Cost" then UI.Accent else UI.Phosphor)
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.fromScale(0.34, 0.5)
		bar.Size = UDim2.new(0.66, 0, 0, 10)
	end
	Kit.text(sheet, {
		Name = "Description",
		Text = unit.Description,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.TextDim,
		Size = UDim2.new(1, 0, 0, 78),
		LayoutOrder = 10,
	})
	Kit.heading(sheet, "ACQUISITION", 11)
	local state = refs.units[unit.Id]
	local owned = state and state.owned
	Kit.text(sheet, {
		Name = "Requirement",
		Text = if state then state.requirement else "CHECKING RECORDS…",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 16,
		TextColor3 = if owned then UI.Success else UI.Text,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 12,
	})
	if state and state.event then
		Kit.text(sheet, {
			Name = "EventNote",
			Text = "LIMITED UNIT — EARN IT ON THE CURRENT OPERATION'S REWARD TRACK AT THE EVENT AREA.",
			TextWrapped = true,
			TextSize = Kit.Text.Small,
			TextColor3 = UI.TextDim,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 13,
		})
	elseif state and not owned and state.cost > 0 then
		local credits = State.profile and State.profile.credits or 0
		local button = Kit.button(sheet, ("UNLOCK — %s CR"):format(Format.number(state.cost)), "primary", function()
			unlock(unit.Id)
		end)
		button.Name = "Unlock"
		button.Size = UDim2.new(1, 0, 0, 40)
		button.LayoutOrder = 14
		Kit.setEnabled(button, state.canUnlock == true)
		Kit.text(sheet, {
			Name = "Balance",
			Text = ("YOUR CREDITS: %s CR"):format(Format.number(credits)),
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			LayoutOrder = 15,
		})
	end
end

function Panel.build(shell: Shell)
	local sheet = Kit.box(shell.body, { Name = "Sheet", Size = UDim2.new(1, 0, 1, -18) })
	Kit.list(sheet, Enum.FillDirection.Vertical, 8)
	refs.sheet = sheet
	refs.status = Kit.text(shell.body, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
	})
	shell.footer.Text = "UNIT REGISTRY + PAINT SHOP AT THE BACK OF THE GARAGE"
	State.changed:Connect(function(key)
		if key == "profile" and WindowManager.current() == "Inspect" then
			render()
		end
	end)
end

function Panel.open(shell: Shell, context: WindowManager.Context)
	local unitId = context.id
	if unitId and Units.List[unitId] then
		refs.unitId = unitId
	end
	local unit = Units.List[refs.unitId]
	shell.title.Text = unit.Name
	local status = refs.status
	if status then
		status.Text = ""
	end
	render()
	task.spawn(function()
		loadStates()
		if WindowManager.current() == "Inspect" then
			render()
		end
	end)
end

return Panel
