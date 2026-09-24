--!strict
-- Leaderboards: OrderedDataStore per board (global), refreshed on an
-- interval, with a per-server fallback when DataStores are unavailable.
-- Fills the physical boards in the Hall of Commanders and serves the UI.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lobby = ReplicatedStorage.Lobby
local Config = require(Lobby.Config.Leaderboards)
local Net = require(Lobby.Net)
local Format = require(Lobby.Util.Format)
local ProfileSchema = require(script.Parent.Parent.Core.ProfileSchema)
local CommanderService = require(script.Parent.CommanderService)
local DataService = require(script.Parent.DataService)

export type Entry = { rank: number, name: string, value: number, userId: number }
export type BoardData = {
	id: string,
	title: string,
	subtitle: string,
	unit: string,
	entries: { Entry },
	source: string,
	updatedAt: number,
}

local LeaderboardService = {}

-- Fictional commanders used only in Studio when no real data exists, so
-- the boards can be reviewed. Never used in a live server.
LeaderboardService.DemoNames = {
	"Cpt. Weber",
	"Lt. Kowalski",
	"Maj. Dubois",
	"Sgt. Novak",
	"Col. Harrington",
	"Lt. Petrov",
	"Cpt. Lindqvist",
	"Sgt. Moreau",
	"Maj. Brandt",
	"Lt. Okafor",
}

local data: { [string]: BoardData } = {}
local screens: { [string]: Instance } = {}
local nameCache: { [number]: string } = {}
local lastWritten: { [string]: { [number]: number } } = {}

local function statOf(profile: ProfileSchema.Profile, stat: string): number
	if stat == "xp" then
		return profile.xp
	end
	return ProfileSchema.statValue(profile, stat)
end

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else ("Commander %d"):format(userId)
	nameCache[userId] = result
	return result
end

local function localEntries(board: Config.Board): { Entry }
	local rows = {}
	for _, player in Players:GetPlayers() do
		local profile = CommanderService.get(player)
		if profile then
			table.insert(
				rows,
				{ rank = 0, name = player.DisplayName, value = statOf(profile, board.Stat), userId = player.UserId }
			)
		end
	end
	return rows
end

local function demoEntries(board: Config.Board, index: number): { Entry }
	local rows = {}
	local scale = ({ 12000, 60, 110, 420, 1400 })[index] or 100
	for i, name in LeaderboardService.DemoNames do
		local value = math.floor(scale * (1 - (i - 1) * 0.07) + (index * 13 + i * 7) % 17)
		if board.Stat == "rating" then
			value = math.floor(1000 + (scale - 1000) * (1 - (i - 1) * 0.06))
		end
		table.insert(rows, { rank = 0, name = name, value = value, userId = -i })
	end
	return rows
end

local function rank(rows: { Entry }): { Entry }
	table.sort(rows, function(a, b)
		if a.value == b.value then
			return a.name < b.name
		end
		return a.value > b.value
	end)
	local out = {}
	for i = 1, math.min(#rows, Config.Rows) do
		local row = rows[i]
		row.rank = i
		table.insert(out, row)
	end
	return out
end

local function fetchGlobal(board: Config.Board): { Entry }?
	if not DataService.isAvailable() then
		return nil
	end
	local ok, result = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(Config.StorePrefix .. board.Id)
		-- write current players' values when they changed
		local written = lastWritten[board.Id] or {}
		lastWritten[board.Id] = written
		for _, player in Players:GetPlayers() do
			local profile = CommanderService.get(player)
			if profile and not CommanderService.isTemporary(player) then
				local value = math.floor(statOf(profile, board.Stat))
				if written[player.UserId] ~= value then
					store:SetAsync(tostring(player.UserId), value)
					written[player.UserId] = value
				end
			end
		end
		local pages = store:GetSortedAsync(false, Config.Rows)
		local rows = {}
		for _, item in pages:GetCurrentPage() do
			local userId = tonumber(item.key) or 0
			table.insert(rows, { rank = 0, name = nameFor(userId), value = item.value, userId = userId })
		end
		return rows
	end)
	if ok then
		return result
	end
	if not DataService.reportError(result) then
		warn("[Lobby] Leaderboard fetch failed:", result)
	end
	return nil
end

local function updateScreen(board: BoardData)
	local gui = screens[board.id]
	local content = gui and gui:FindFirstChild("Content", true)
	if not content then
		return
	end
	for i = 1, Config.Rows do
		local row = content:FindFirstChild("Row" .. i)
		if row then
			local entry = board.entries[i]
			local nameLabel = row:FindFirstChild("Name")
			local valueLabel = row:FindFirstChild("Value")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = if entry then entry.name else "—"
			end
			if valueLabel and valueLabel:IsA("TextLabel") then
				valueLabel.Text = if entry then Format.number(entry.value) else ""
			end
		end
	end
	local footer = content:FindFirstChild("Footer")
	if footer and footer:IsA("TextLabel") then
		footer.Text = ("%s · UPDATED %s"):format(board.source, Format.zulu(board.updatedAt))
	end
end

function LeaderboardService.refresh()
	local studioDemo = RunService:IsStudio() and DataService.DemoDataInStudio
	for index, board in Config.Boards do
		local fetched = fetchGlobal(board)
		local rows: { Entry }
		local source = "GLOBAL"
		if fetched then
			rows = fetched
		else
			rows = localEntries(board)
			source = "THIS SERVER"
			if studioDemo then
				for _, row in demoEntries(board, index) do
					table.insert(rows, row)
				end
				source = "STUDIO DEMO DATA"
			end
		end
		local boardData: BoardData = {
			id = board.Id,
			title = board.Title,
			subtitle = board.Subtitle,
			unit = board.Unit,
			entries = rank(rows),
			source = source,
			updatedAt = os.time(),
		}
		data[board.Id] = boardData
		updateScreen(boardData)
	end
	Net.event("LeaderboardsChanged"):FireAllClients(LeaderboardService.snapshot())
end

function LeaderboardService.snapshot(): { BoardData }
	local out = {}
	for _, board in Config.Boards do
		local entry = data[board.Id]
		if entry then
			table.insert(out, entry)
		end
	end
	return out
end

function LeaderboardService.start(world: Instance)
	for _, d in world:GetDescendants() do
		if d:IsA("SurfaceGui") and d.Name == "Leaderboard" then
			local id = d:GetAttribute("BoardId")
			if type(id) == "string" then
				screens[id] = d
			end
		end
	end
	Net.fn("Leaderboards").OnServerInvoke = function(player: Player, request: any)
		if type(request) ~= "table" or request.action ~= "get" then
			return { ok = false, error = "BAD_REQUEST" }
		end
		local profile = CommanderService.whenLoaded(player)
		local yours = {}
		if profile then
			for _, board in Config.Boards do
				yours[board.Id] = statOf(profile, board.Stat)
			end
		end
		return { ok = true, boards = LeaderboardService.snapshot(), yours = yours }
	end
	local pending = false
	local function soon()
		if pending then
			return
		end
		pending = true
		task.delay(5, function()
			pending = false
			LeaderboardService.refresh()
		end)
	end
	CommanderService.onLoaded(function()
		soon()
	end)
	Players.PlayerRemoving:Connect(function()
		soon()
	end)
	task.spawn(function()
		LeaderboardService.refresh()
		while true do
			task.wait(Config.RefreshInterval)
			LeaderboardService.refresh()
		end
	end)
end

return LeaderboardService
