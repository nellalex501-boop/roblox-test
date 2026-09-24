--!strict
-- Mission board: today's operations (reset daily at 00:00 UTC) and the
-- one-time orientation orders that walk new commanders through the base.
-- Progress bars, rewards and claim buttons; the reset countdown ticks live.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Missions = require(Lobby:WaitForChild("Config"):WaitForChild("Missions"))
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
Panel.title = "MISSION BOARD"
Panel.code = "S3 OPERATIONS // STANDING ORDERS"
Panel.size = Vector2.new(900, 590)

local refs: { list: ScrollingFrame?, reset: TextLabel?, status: TextLabel?, resetAt: number } = {
	list = nil,
	reset = nil,
	status = nil,
	resetAt = 0,
}

local render: () -> ()

local function claim(id: string)
	local response = State.request("Missions", { action = "claim", id = id })
	local status = refs.status
	if response.ok then
		Sound.play("Reward")
		if status then
			status.Text = ("REWARD RECEIVED: +%d CR · +%d XP"):format(
				response.reward and response.reward.credits or 0,
				response.reward and response.reward.xp or 0
			)
			status.TextColor3 = UI.Success
		end
		if response.missions then
			State.set("missions", { ok = true, missions = response.missions, resetIn = response.resetIn })
		end
	else
		Sound.play("Error")
		if status then
			status.Text = Errors.text(response.error)
			status.TextColor3 = UI.Danger
		end
	end
	render()
end

local function missionRow(list: Instance, m: Data, order: number)
	local row = Kit.frame(list, {
		Name = "Mission_" .. tostring(m.id),
		BackgroundColor3 = if m.complete and not m.claimed then UI.PanelRaised else UI.Panel,
		Size = UDim2.new(1, 0, 0, 58),
		LayoutOrder = order,
	})
	Kit.stroke(row, if m.complete and not m.claimed then UI.Accent else UI.BorderDim)
	-- checkbox
	local box = Kit.frame(row, {
		Name = "Check",
		BackgroundColor3 = UI.Background,
		Position = UDim2.fromOffset(14, 17),
		Size = UDim2.fromOffset(24, 24),
	})
	Kit.stroke(box, if m.complete then UI.Accent else UI.Border, 2)
	Kit.text(box, {
		Name = "Mark",
		Text = if m.claimed then "✓" elseif m.complete then "!" else "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = 18,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	Kit.text(row, {
		Name = "Text",
		Text = m.text,
		FontFace = Kit.Fonts.BodyBold,
		TextSize = 16,
		TextColor3 = if m.claimed then UI.TextDim else UI.Text,
		Position = UDim2.fromOffset(52, 7),
		Size = UDim2.new(0.55, -52, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local bar = Kit.progress(
		row,
		(m.progress or 0) / math.max(m.target or 1, 1),
		if m.complete then UI.Accent else UI.Phosphor,
		6
	)
	bar.Position = UDim2.fromOffset(52, 36)
	bar.Size = UDim2.new(0.42, -52, 0, 6)
	Kit.text(row, {
		Name = "Progress",
		Text = ("%d / %d"):format(m.progress or 0, m.target or 1),
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.TextDim,
		Position = UDim2.new(0.42, 6, 0, 30),
		Size = UDim2.new(0.13, 0, 0, 18),
	})
	Kit.text(row, {
		Name = "Reward",
		Text = ("+%d CR  +%d XP"):format(m.credits or 0, m.xp or 0),
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.55, 0),
		Size = UDim2.new(0.22, 0, 1, 0),
	})
	if m.claimed then
		Kit.text(row, {
			Name = "Claimed",
			Text = "COLLECTED",
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Small,
			TextColor3 = UI.TextFaint,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0.79, 0, 0, 0),
			Size = UDim2.new(0.21, -12, 1, 0),
		})
	else
		local button = Kit.button(row, "CLAIM", "primary", function()
			claim(m.id)
		end)
		button.Name = "Claim"
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -12, 0.5, 0)
		button.Size = UDim2.fromOffset(150, 36)
		Kit.setEnabled(button, m.complete == true)
	end
end

render = function()
	local list = refs.list
	if not list then
		return
	end
	Kit.clear(list)
	local data = State.missions
	if not data or not data.missions then
		Kit.text(list, { Name = "Loading", Text = "RETRIEVING ORDERS…", TextColor3 = UI.TextDim })
		return
	end
	if type(data.resetIn) == "number" then
		refs.resetAt = os.clock() + data.resetIn
	end
	local order = 0
	for _, group in { "DAILY", "ORIENTATION" } do
		order += 1
		local info = Missions.Groups[group]
		local head = Kit.heading(list, info.Title, order)
		local sub = Kit.text(head, {
			Name = "Subtitle",
			Text = info.Subtitle,
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 1, -3),
		})
		if group == "DAILY" then
			refs.reset = sub
		end
		for _, m in data.missions do
			if m.group == group then
				order += 1
				missionRow(list, m, order)
			end
		end
	end
end

function Panel.build(shell: Shell)
	refs.list = Kit.scroll(shell.body, { Size = UDim2.new(1, 0, 1, -20) }, 6)
	refs.status = Kit.text(shell.body, {
		Name = "Status",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Tiny,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
	})
	shell.footer.Text = "COMPLETE ORDERS ANYWHERE — COLLECT REWARDS HERE · WALK AWAY TO CLOSE"
	State.changed:Connect(function(key)
		if key == "missions" and WindowManager.current() == "Missions" then
			render()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local label = refs.reset
			if label and label.Parent and WindowManager.current() == "Missions" and refs.resetAt > 0 then
				label.Text = "NEW ORDERS IN " .. Format.clock(refs.resetAt - os.clock())
			end
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
		State.refreshMissions()
	end)
end

return Panel
