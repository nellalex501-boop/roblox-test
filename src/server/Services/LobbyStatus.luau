--!strict
-- Live lobby status on the world displays and the HUD: commanders online,
-- queue counts per mode, battles deployed, the current operation and a
-- Zulu clock. Feeds the plaza status pylon, the Operations Center
-- deployment board, every terminal's queue line, and the LobbyStatus
-- remote (clients show it in the HUD).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage.Lobby
local Events = require(Lobby.Config.Events)
local Format = require(Lobby.Util.Format)
local GameModes = require(Lobby.Config.GameModes)
local Net = require(Lobby.Net)
local EventService = require(script.Parent.EventService)
local MatchmakingService = require(script.Parent.MatchmakingService)

export type Status = {
	online: number,
	queued: number,
	counts: { [string]: number },
	formed: number,
	deployed: number,
	operation: { id: string, title: string, days: number, active: boolean },
	serverTime: number,
}

local LobbyStatus = {}

LobbyStatus.Interval = 2
LobbyStatus.BroadcastInterval = 10

local pylons: { Instance } = {}
local boards: { Instance } = {}
local terminals: { [string]: { Instance } } = {}
local lastBroadcast = 0
local lastKey = ""

local function setText(root: Instance, name: string, text: string)
	local label = root:FindFirstChild(name, true)
	if label and label:IsA("TextLabel") and label.Text ~= text then
		label.Text = text
	end
end

function LobbyStatus.compute(now: number): Status
	local counts = MatchmakingService.counts()
	local queued = 0
	for _, n in counts do
		queued += n
	end
	local stats = MatchmakingService.stats()
	local event = EventService.current()
	return {
		online = #Players:GetPlayers(),
		queued = queued,
		counts = counts,
		formed = stats.formed,
		deployed = stats.deployed,
		operation = {
			id = event.Id,
			title = event.Title,
			days = Events.daysRemaining(event, now),
			active = event.Id ~= Events.Standby.Id,
		},
		serverTime = now,
	}
end

local function terminalLine(modeId: string, status: Status): string
	local n = status.counts[modeId] or 0
	if modeId == "PRIVATE" then
		return ("IN LOBBIES: %d"):format(n)
	elseif modeId == "QUICK" then
		return ("SEARCHING: %d"):format(status.queued - (status.counts.PRIVATE or 0))
	end
	return ("IN QUEUE: %d / %d"):format(n, GameModes.playersNeeded(modeId) or 2)
end

function LobbyStatus.apply(status: Status)
	local clock = Format.zulu(status.serverTime)
	for _, gui in pylons do
		setText(gui, "OnlineValue", tostring(status.online))
		setText(gui, "QueuedValue", tostring(status.queued))
		setText(gui, "DeployedValue", tostring(status.deployed))
		setText(gui, "OperationValue", status.operation.title)
		setText(gui, "Clock", clock)
	end
	for _, gui in boards do
		for _, modeId in GameModes.Order do
			local n = status.counts[modeId] or 0
			setText(gui, "Count_" .. modeId, if n == 0 then "STANDBY" else ("%d WAITING"):format(n))
		end
		setText(gui, "Operation", "CURRENT OPERATION: " .. status.operation.title)
		setText(gui, "Clock", clock)
	end
	for modeId, list in terminals do
		local line = terminalLine(modeId, status)
		for _, gui in list do
			setText(gui, "QueueCount", line)
		end
	end
end

function LobbyStatus.update(force: boolean?)
	local now = os.time()
	local status = LobbyStatus.compute(now)
	LobbyStatus.apply(status)
	local key = ("%d|%d|%d|%s|%d"):format(
		status.online,
		status.queued,
		status.deployed,
		status.operation.id,
		status.operation.days
	)
	for _, modeId in GameModes.Order do
		key ..= "|" .. tostring(status.counts[modeId] or 0)
	end
	if force or key ~= lastKey or now - lastBroadcast >= LobbyStatus.BroadcastInterval then
		lastKey = key
		lastBroadcast = now
		Net.event("LobbyStatus"):FireAllClients(status)
	end
end

function LobbyStatus.start(world: Instance)
	for _, d in world:GetDescendants() do
		if d:IsA("SurfaceGui") then
			if d.Name:sub(1, 12) == "StatusScreen" then
				table.insert(pylons, d)
			elseif d.Name == "DeploymentBoard" then
				table.insert(boards, d)
			elseif d.Name == "TerminalScreen" then
				local modeId = d:GetAttribute("ModeId")
				if type(modeId) == "string" then
					terminals[modeId] = terminals[modeId] or {}
					table.insert(terminals[modeId], d)
				end
			end
		end
	end
	Players.PlayerAdded:Connect(function(player)
		-- new arrivals get the current status right away
		task.defer(function()
			if player.Parent then
				Net.event("LobbyStatus"):FireClient(player, LobbyStatus.compute(os.time()))
			end
		end)
	end)
	task.spawn(function()
		while true do
			LobbyStatus.update()
			task.wait(LobbyStatus.Interval)
		end
	end)
end

return LobbyStatus
