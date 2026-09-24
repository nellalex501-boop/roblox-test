--!strict
-- Matchmaking backend for the physical terminals.
--
-- Players queue at a terminal (proximity is validated), can walk around
-- while queued, and are deployed when QueueLogic forms a match: a short
-- countdown, then a teleport to a reserved server of the RTS place with the
-- match data as teleport data. In Studio, or while
-- GameModes.Settings.TargetPlaceId is 0, deployment is simulated so the
-- whole flow can be tested in the lobby place alone.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Lobby = ReplicatedStorage.Lobby
local GameModes = require(Lobby.Config.GameModes)
local Maps = require(Lobby.Config.Maps)
local Net = require(Lobby.Net)
local QueueLogic = require(script.Parent.Parent.Core.QueueLogic)
local CommanderService = require(script.Parent.CommanderService)
local InteractionService = require(script.Parent.InteractionService)

type Deploy = {
	id: string,
	match: QueueLogic.Match,
	phase: string, -- "found" | "deploying" | "simulated" | "failed"
	endsAt: number,
	simulated: boolean,
	message: string?,
}

local MatchmakingService = {}

local settings = GameModes.Settings
local queue = QueueLogic.new(os.time())
local deploys: { [number]: Deploy } = {}
local stats = { formed = 0, deployed = 0 }

local CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local codeRandom = Random.new()

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function nameOf(userId: number): string
	local player = playerOf(userId)
	return if player then player.DisplayName else ("Commander %d"):format(userId)
end

local function shouldSimulate(): boolean
	return settings.TargetPlaceId == 0 or RunService:IsStudio()
end

local function teamNames(match: QueueLogic.Match): { { string } }
	local out = {}
	for _, team in match.teams do
		local names = {}
		for _, userId in team do
			table.insert(names, nameOf(userId))
		end
		table.insert(out, names)
	end
	return out
end

function MatchmakingService.stateFor(player: Player): { [string]: any }
	local userId = player.UserId
	local deploy = deploys[userId]
	if deploy then
		local map = Maps.List[deploy.match.map]
		return {
			state = deploy.phase,
			match = {
				mode = deploy.match.mode,
				map = deploy.match.map,
				mapName = if map then map.Name else deploy.match.map,
				teams = teamNames(deploy.match),
				endsAt = deploy.endsAt,
				private = deploy.match.private,
				simulated = deploy.simulated,
			},
			message = deploy.message,
			serverTime = os.time(),
		}
	end
	local lobby = queue:lobbyOf(userId)
	if lobby then
		local members = {}
		for _, member in lobby.members do
			table.insert(members, { name = nameOf(member), host = member == lobby.host, you = member == userId })
		end
		local map = Maps.List[lobby.map]
		return {
			state = "private",
			lobby = {
				code = lobby.code,
				isHost = lobby.host == userId,
				hostName = nameOf(lobby.host),
				size = lobby.size,
				map = lobby.map,
				mapName = if map then map.Name else lobby.map,
				members = members,
				capacity = GameModes.playersNeeded(lobby.size),
			},
			serverTime = os.time(),
		}
	end
	local mode = queue:modeOf(userId)
	if mode then
		local since = os.time()
		for _, entry in queue.entries do
			if entry.userId == userId then
				since = entry.joinedAt
			end
		end
		return {
			state = "queued",
			mode = mode,
			since = since,
			position = queue:position(userId),
			count = queue:counts()[mode] or 0,
			needed = GameModes.playersNeeded(mode) or 2,
			serverTime = os.time(),
		}
	end
	return { state = "idle", serverTime = os.time() }
end

local function push(player: Player?)
	if player and player.Parent then
		Net.event("MatchmakingChanged"):FireClient(player, MatchmakingService.stateFor(player))
	end
end

local function pushUserIds(ids: { number })
	for _, userId in ids do
		push(playerOf(userId))
	end
end

local function pushQueue(mode: string)
	for _, entry in queue.entries do
		if entry.mode == mode then
			push(playerOf(entry.userId))
		end
	end
end

local function pushLobby(lobby: QueueLogic.Lobby?)
	if lobby then
		pushUserIds(lobby.members)
	end
end

local function newCode(): string
	for _ = 1, 50 do
		local chars = {}
		for i = 1, settings.PrivateCodeLength do
			local index = codeRandom:NextInteger(1, #CODE_ALPHABET)
			chars[i] = CODE_ALPHABET:sub(index, index)
		end
		local code = table.concat(chars)
		if not queue.lobbies[code] then
			return code
		end
	end
	return HttpService:GenerateGUID(false):sub(1, settings.PrivateCodeLength):upper()
end

local function clearDeploy(userIds: { number }, id: string)
	for _, userId in userIds do
		local deploy = deploys[userId]
		if deploy and deploy.id == id then
			deploys[userId] = nil
		end
	end
end

local function notify(userIds: { number }, payload: { [string]: any })
	for _, userId in userIds do
		local player = playerOf(userId)
		if player then
			Net.event("Notify"):FireClient(player, payload)
		end
	end
end

local function teleport(present: { Player }, deploy: Deploy)
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	local teams = {}
	for _, team in deploy.match.teams do
		local ids = {}
		for _, userId in team do
			table.insert(ids, userId)
		end
		table.insert(teams, ids)
	end
	options:SetTeleportData({
		source = "ColdWarLobby",
		mode = deploy.match.mode,
		map = deploy.match.map,
		teams = teams,
		private = deploy.match.private,
	})
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(settings.TargetPlaceId, present, options)
	end)
	return ok, err
end

function MatchmakingService.deploy(match: QueueLogic.Match)
	stats.formed += 1
	local id = HttpService:GenerateGUID(false)
	local simulated = shouldSimulate()
	local endsAt = os.time() + settings.DeployCountdown
	for _, userId in match.players do
		deploys[userId] =
			{ id = id, match = match, phase = "found", endsAt = endsAt, simulated = simulated, message = nil }
	end
	pushUserIds(match.players)
	local map = Maps.List[match.map]
	notify(match.players, {
		kind = "Match",
		title = "MATCH FOUND",
		text = ("%s · %s"):format(GameModes.Modes[match.mode].Title, if map then map.Name else match.map),
		detail = ("DEPLOYING IN %d"):format(settings.DeployCountdown),
	})
	task.delay(settings.DeployCountdown, function()
		local present = {}
		for _, userId in match.players do
			local player = playerOf(userId)
			if player and deploys[userId] and deploys[userId].id == id then
				table.insert(present, player)
			end
		end
		if #present < 2 then
			for _, player in present do
				deploys[player.UserId].phase = "failed"
				deploys[player.UserId].message = "DEPLOYMENT CANCELLED — NOT ENOUGH COMMANDERS"
			end
			pushUserIds(match.players)
			task.delay(4, function()
				clearDeploy(match.players, id)
				pushUserIds(match.players)
			end)
			return
		end
		for _, player in present do
			deploys[player.UserId].phase = "deploying"
		end
		pushUserIds(match.players)
		if simulated then
			stats.deployed += 1
			for _, player in present do
				local deploy = deploys[player.UserId]
				deploy.phase = "simulated"
				deploy.message = "DEPLOYMENT SIMULATED — SET GameModes.Settings.TargetPlaceId TO TELEPORT"
			end
			pushUserIds(match.players)
			task.delay(5, function()
				clearDeploy(match.players, id)
				pushUserIds(match.players)
			end)
			return
		end
		local ok, err = teleport(present, deploys[present[1].UserId])
		if ok then
			stats.deployed += 1
		else
			warn("[Lobby] Teleport failed:", err)
			for _, player in present do
				local deploy = deploys[player.UserId]
				if deploy then
					deploy.phase = "failed"
					deploy.message = "DEPLOYMENT FAILED — PLEASE QUEUE AGAIN"
				end
			end
			pushUserIds(match.players)
			task.delay(4, function()
				clearDeploy(match.players, id)
				pushUserIds(match.players)
			end)
		end
	end)
end

local function atTerminal(player: Player, mode: string): boolean
	if not settings.RequireProximity then
		return true
	end
	return InteractionService.isNear(player, "Matchmaking", mode)
end

-- Request handlers -------------------------------------------------------

local ACTIONS: { [string]: (Player, { [string]: any }) -> { [string]: any } } = {}

ACTIONS.status = function(player)
	return { ok = true, state = MatchmakingService.stateFor(player) }
end

ACTIONS.join = function(player, request)
	local mode = request.mode
	if type(mode) ~= "string" or (mode ~= "QUICK" and not table.find(GameModes.QueueModes, mode)) then
		return { ok = false, error = "INVALID_MODE" }
	end
	if deploys[player.UserId] then
		return { ok = false, error = "DEPLOYING" }
	end
	if not atTerminal(player, mode) then
		return { ok = false, error = "NOT_AT_TERMINAL" }
	end
	local profile = CommanderService.get(player)
	local previous = queue:modeOf(player.UserId)
	local ok, err = queue:join(
		player.UserId,
		mode,
		os.time(),
		if profile then profile.stats.rating else 1000,
		if profile and profile.preferredMap ~= "" then profile.preferredMap else nil
	)
	if not ok then
		return { ok = false, error = err }
	end
	if previous and previous ~= mode then
		pushQueue(previous)
	end
	pushQueue(mode)
	return { ok = true, state = MatchmakingService.stateFor(player) }
end

ACTIONS.leave = function(player)
	local mode = queue:modeOf(player.UserId)
	if mode then
		queue:leave(player.UserId)
		pushQueue(mode)
	end
	local lobby = queue:leavePrivate(player.UserId)
	pushLobby(lobby)
	push(player)
	return { ok = true, state = MatchmakingService.stateFor(player) }
end

ACTIONS.createPrivate = function(player, request)
	local size = request.size
	if type(size) ~= "string" or not table.find(GameModes.PrivateSizes, size) then
		return { ok = false, error = "INVALID_SIZE" }
	end
	if deploys[player.UserId] then
		return { ok = false, error = "DEPLOYING" }
	end
	if not atTerminal(player, "PRIVATE") then
		return { ok = false, error = "NOT_AT_TERMINAL" }
	end
	local count = 0
	for _ in queue.lobbies do
		count += 1
	end
	if count >= settings.MaxPrivateLobbies then
		return { ok = false, error = "TOO_MANY_LOBBIES" }
	end
	local previous = queue:modeOf(player.UserId)
	local lobby, err = queue:createPrivate(player.UserId, size, newCode(), os.time())
	if not lobby then
		return { ok = false, error = err }
	end
	if previous then
		pushQueue(previous)
	end
	push(player)
	return { ok = true, state = MatchmakingService.stateFor(player) }
end

ACTIONS.joinPrivate = function(player, request)
	local code = request.code
	if type(code) ~= "string" or #code < 3 or #code > 10 or code:find("[^%w]") then
		return { ok = false, error = "INVALID_CODE" }
	end
	if deploys[player.UserId] then
		return { ok = false, error = "DEPLOYING" }
	end
	if not atTerminal(player, "PRIVATE") then
		return { ok = false, error = "NOT_AT_TERMINAL" }
	end
	local previous = queue:modeOf(player.UserId)
	local lobby, err = queue:joinPrivate(player.UserId, code)
	if not lobby then
		return { ok = false, error = err }
	end
	if previous then
		pushQueue(previous)
	end
	pushLobby(lobby)
	return { ok = true, state = MatchmakingService.stateFor(player) }
end

ACTIONS.privateOptions = function(player, request)
	local size = request.size
	local map = request.map
	if size ~= nil and type(size) ~= "string" then
		return { ok = false, error = "INVALID_SIZE" }
	end
	if map ~= nil and type(map) ~= "string" then
		return { ok = false, error = "INVALID_MAP" }
	end
	local ok, err = queue:setPrivateOptions(player.UserId, size, map)
	if not ok then
		return { ok = false, error = err }
	end
	pushLobby(queue:lobbyOf(player.UserId))
	return { ok = true, state = MatchmakingService.stateFor(player) }
end

ACTIONS.startPrivate = function(player)
	local match, err = queue:startPrivate(player.UserId)
	if not match then
		return { ok = false, error = err }
	end
	MatchmakingService.deploy(match)
	return { ok = true, state = MatchmakingService.stateFor(player) }
end

function MatchmakingService.counts(): { [string]: number }
	return queue:counts()
end

function MatchmakingService.stats(): { formed: number, deployed: number }
	return table.clone(stats)
end

function MatchmakingService.queue()
	return queue
end

function MatchmakingService.start()
	Net.fn("Matchmaking").OnServerInvoke = function(player: Player, request: any)
		if type(request) ~= "table" or type(request.action) ~= "string" then
			return { ok = false, error = "BAD_REQUEST" }
		end
		local handler = ACTIONS[request.action]
		if not handler then
			return { ok = false, error = "UNKNOWN_ACTION" }
		end
		return handler(player, request)
	end
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local mode = queue:modeOf(userId)
		if mode then
			queue:leave(userId)
			pushQueue(mode)
		end
		pushLobby(queue:leavePrivate(userId))
		deploys[userId] = nil
	end)
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		local deploy = deploys[player.UserId]
		if deploy then
			deploy.phase = "failed"
			deploy.message = "DEPLOYMENT FAILED — " .. string.upper(result.Name)
			push(player)
			task.delay(4, function()
				if deploys[player.UserId] == deploy then
					deploys[player.UserId] = nil
					push(player)
				end
			end)
		end
		warn("[Lobby] TeleportInitFailed", player.Name, result, message)
	end)
	task.spawn(function()
		while true do
			task.wait(settings.TickInterval)
			local matches = queue:tick(os.time())
			for _, match in matches do
				MatchmakingService.deploy(match)
			end
		end
	end)
end

return MatchmakingService
