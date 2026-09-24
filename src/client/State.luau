--!strict
-- Client-side store: the latest server data (profile snapshot, matchmaking
-- state, lobby status, leaderboards, event, missions) plus change signals.
-- UI reads from here and calls State.request() for actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Net = require(Lobby:WaitForChild("Net"))
local Signal = require(Lobby:WaitForChild("Util"):WaitForChild("Signal"))

type Data = { [string]: any }

local State = {}

State.profile = nil :: Data?
State.matchmaking = { state = "idle" } :: Data
State.status = nil :: Data?
State.leaderboards = nil :: { Data }?
State.leaderboardsMine = nil :: Data?
State.event = nil :: Data?
State.missions = nil :: Data?

-- Fired with the key that changed ("profile", "matchmaking", ...).
State.changed = Signal.new() :: Signal.Signal<string>
-- Fired for every server notification ({ kind, title, text, detail }).
State.notified = Signal.new() :: Signal.Signal<Data>

local started = false

function State.set(key: string, value: any)
	(State :: any)[key] = value
	State.changed:Fire(key)
end

-- Calls a server RemoteFunction. Never throws: network/server errors come
-- back as { ok = false, error = "NETWORK" }.
function State.request(remoteName: string, payload: Data): Data
	local ok, result = pcall(function()
		return Net.fn(remoteName):InvokeServer(payload)
	end)
	if not ok then
		warn("[Lobby] request failed", remoteName, result)
		return { ok = false, error = "NETWORK" }
	end
	if type(result) ~= "table" then
		return { ok = false, error = "BAD_RESPONSE" }
	end
	local response = result :: Data
	-- responses that carry a fresh snapshot update the store directly
	if type(response.profile) == "table" then
		State.set("profile", response.profile)
	end
	return response
end

function State.serverNow(): number
	return workspace:GetServerTimeNow()
end

function State.refreshEvent(): Data?
	local response = State.request("Event", { action = "get" })
	if response.ok then
		State.set("event", { info = response.event, progress = response.progress })
	end
	return State.event
end

function State.refreshMissions(): Data?
	local response = State.request("Missions", { action = "list" })
	if response.ok then
		State.set("missions", response)
	end
	return State.missions
end

function State.refreshLeaderboards(): Data?
	local response = State.request("Leaderboards", { action = "get" })
	if response.ok then
		State.set("leaderboards", response.boards)
		State.set("leaderboardsMine", response.yours)
	end
	return response
end

function State.start()
	if started then
		return
	end
	started = true
	Net.event("ProfileChanged").OnClientEvent:Connect(function(snapshot: Data)
		State.set("profile", snapshot)
	end)
	Net.event("MatchmakingChanged").OnClientEvent:Connect(function(state: Data)
		State.set("matchmaking", state)
	end)
	Net.event("LeaderboardsChanged").OnClientEvent:Connect(function(boards: { Data })
		State.set("leaderboards", boards)
	end)
	Net.event("LobbyStatus").OnClientEvent:Connect(function(status: Data)
		State.set("status", status)
	end)
	Net.event("Notify").OnClientEvent:Connect(function(payload: Data)
		State.notified:Fire(payload)
		-- progress-related notifications mean mission/event data changed
		if payload.kind == "Mission" or payload.kind == "Reward" then
			task.spawn(State.refreshMissions)
		end
		if payload.kind == "Event" or payload.kind == "Reward" then
			task.spawn(State.refreshEvent)
		end
	end)
	task.spawn(function()
		local response = State.request("Profile", { action = "get" })
		if response.ok and response.profile then
			State.set("profile", response.profile)
		end
		local mm = State.request("Matchmaking", { action = "status" })
		if mm.ok and mm.state then
			State.set("matchmaking", mm.state)
		end
		State.refreshEvent()
		State.refreshMissions()
	end)
end

return State
