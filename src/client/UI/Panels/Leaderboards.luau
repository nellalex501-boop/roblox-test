--!strict
-- Hall of Commanders: the five leaderboards (top commanders, victories,
-- matches, territory, current season) with your own standing. Opening a
-- physical board selects its tab.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Config = require(Lobby:WaitForChild("Config"):WaitForChild("Leaderboards"))
local Format = require(Lobby:WaitForChild("Util"):WaitForChild("Format"))
local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.State)
local WindowManager = require(script.Parent.Parent.WindowManager)

local UI = Kit.Colors

type Shell = WindowManager.Shell
type Data = { [string]: any }

local TAB_FOR: { [string]: string } = {
	TOP_COMMANDERS = "COMMANDERS",
	MOST_VICTORIES = "VICTORIES",
	MOST_MATCHES = "MATCHES",
	MOST_TERRITORY = "TERRITORY",
	CURRENT_SEASON = "SEASON",
}
local BOARD_FOR: { [string]: string } = {}
for id, tab in TAB_FOR do
	BOARD_FOR[tab] = id
end

local Panel = {} :: WindowManager.Panel
Panel.title = "HALL OF COMMANDERS"
Panel.code = "S3 OPERATIONS // STANDINGS"
Panel.tabs = { "COMMANDERS", "VICTORIES", "MATCHES", "TERRITORY", "SEASON" }
Panel.size = Vector2.new(880, 580)

local refs: { tab: string, table: Frame?, header: TextLabel?, sub: TextLabel?, mine: TextLabel?, footer: TextLabel? } =
	{
		tab = "COMMANDERS",
		table = nil,
		header = nil,
		sub = nil,
		mine = nil,
		footer = nil,
	}

local function boardData(id: string): Data?
	local boards: { Data } = State.leaderboards or {}
	for _, board in boards do
		if board.id == id then
			return board
		end
	end
	return nil
end

local function boardConfig(id: string): Config.Board?
	for _, board in Config.Boards do
		if board.Id == id then
			return board
		end
	end
	return nil
end

local function render()
	local tableFrame = refs.table
	if not tableFrame then
		return
	end
	local id = BOARD_FOR[refs.tab] or "TOP_COMMANDERS"
	local cfg = boardConfig(id)
	local data = boardData(id)
	if refs.header and cfg then
		refs.header.Text = cfg.Title
	end
	if refs.sub and cfg then
		refs.sub.Text = cfg.Subtitle
	end
	Kit.clear(tableFrame)
	local head = Kit.box(tableFrame, { Name = "Head", Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0 })
	local columns: { { name: string, x: number, w: number } } = {
		{ name = "RANK", x = 0, w = 0.1 },
		{ name = "COMMANDER", x = 0.14, w = 0.58 },
		{ name = if cfg then cfg.Unit else "VALUE", x = 0.72, w = 0.28 },
	}
	for _, col in columns do
		Kit.text(head, {
			Name = "Col_" .. col.name,
			Text = col.name,
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Tiny,
			TextColor3 = UI.TextDim,
			Position = UDim2.fromScale(col.x, 0),
			Size = if col.name == "RANK" or col.name == "COMMANDER"
				then UDim2.fromScale(col.w, 1)
				else UDim2.new(col.w, -10, 1, 0),
			TextXAlignment = if col.name == "COMMANDER" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		})
	end
	local me = Players.LocalPlayer
	local entries = data and data.entries or {}
	for i = 1, Config.Rows do
		local entry = entries[i]
		local you = entry ~= nil and me ~= nil and entry.userId == me.UserId
		local row = Kit.frame(tableFrame, {
			Name = "Row" .. i,
			BackgroundColor3 = if you then UI.PanelHover elseif i % 2 == 0 then UI.Panel else UI.Background,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = i,
		})
		if you then
			Kit.stroke(row, UI.Accent)
		end
		local medal = if i == 1 then UI.Accent elseif i <= 3 then UI.Text else UI.TextDim
		Kit.text(row, {
			Name = "Rank",
			Text = ("%02d"):format(i),
			FontFace = Kit.Fonts.MonoBold,
			TextColor3 = medal,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(0.1, 1),
		})
		Kit.text(row, {
			Name = "Name",
			Text = if entry then tostring(entry.name) .. (if you then "  (YOU)" else "") else "—",
			FontFace = if i <= 3 then Kit.Fonts.Header else Kit.Fonts.Body,
			TextSize = if i <= 3 then 17 else 15,
			TextColor3 = if entry then UI.Text else UI.TextFaint,
			Position = UDim2.fromScale(0.14, 0),
			Size = UDim2.fromScale(0.58, 1),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Kit.text(row, {
			Name = "Value",
			Text = if entry then Format.number(entry.value) else "",
			FontFace = Kit.Fonts.MonoBold,
			TextColor3 = medal,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.72, 0),
			Size = UDim2.new(0.28, -10, 1, 0),
		})
	end
	local mine = State.leaderboardsMine
	if refs.mine then
		local value = if type(mine) == "table" then mine[id] else nil
		refs.mine.Text = if value ~= nil
			then ("YOUR STANDING: %s %s"):format(Format.number(value), cfg and cfg.Unit or "")
			else "YOUR STANDING: —"
	end
	if refs.footer then
		refs.footer.Text = if data
			then ("SOURCE: %s · UPDATED %s"):format(data.source, Format.zulu(data.updatedAt))
			else "RETRIEVING STANDINGS…"
	end
end

function Panel.build(shell: Shell)
	local top = Kit.box(shell.body, { Name = "Top", Size = UDim2.new(1, 0, 0, 44) })
	refs.header = Kit.text(top, {
		Name = "BoardTitle",
		Text = "",
		FontFace = Kit.Fonts.Header,
		TextSize = 24,
		Size = UDim2.new(0.6, 0, 0, 28),
	})
	refs.sub = Kit.text(top, {
		Name = "BoardSubtitle",
		Text = "",
		FontFace = Kit.Fonts.Mono,
		TextSize = Kit.Text.Tiny,
		TextColor3 = UI.Accent,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(0.6, 0, 0, 14),
	})
	refs.mine = Kit.text(top, {
		Name = "Mine",
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = Kit.Text.Small,
		TextColor3 = UI.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, 0, 0, 28),
	})
	local tableFrame = Kit.box(shell.body, {
		Name = "Table",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
	})
	Kit.list(tableFrame, Enum.FillDirection.Vertical, 2)
	refs.table = tableFrame
	refs.footer = shell.footer
	State.changed:Connect(function(key)
		if (key == "leaderboards" or key == "leaderboardsMine") and WindowManager.current() == "Leaderboards" then
			render()
		end
	end)
end

function Panel.selectTab(_shell: Shell, tab: string)
	refs.tab = tab
	render()
end

function Panel.open(_shell: Shell, context: WindowManager.Context)
	local id = context.id
	if id and TAB_FOR[id] then
		context.tab = TAB_FOR[id]
	end
	task.spawn(function()
		State.refreshLeaderboards()
	end)
end

return Panel
