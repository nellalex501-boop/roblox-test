--!strict
-- Commander profiles at runtime: loading on join, snapshots to the owning
-- client, validated profile/customisation requests, and a change hook for
-- other services.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage.Lobby
local Maps = require(Lobby.Config.Maps)
local Net = require(Lobby.Net)
local Progression = require(Lobby.Config.Progression)
local ProfileSchema = require(script.Parent.Parent.Core.ProfileSchema)
local DataService = require(script.Parent.DataService)

type Profile = ProfileSchema.Profile

local CommanderService = {}

local loaded: { [Player]: boolean } = {}
local changeHandlers: { (Player, Profile) -> () } = {}
local loadHandlers: { (Player, Profile) -> () } = {}

function CommanderService.get(player: Player): Profile?
	local session = DataService.get(player)
	return if session then session.profile else nil
end

function CommanderService.isTemporary(player: Player): boolean
	local session = DataService.get(player)
	return session == nil or session.temporary
end

function CommanderService.snapshot(player: Player): ProfileSchema.Snapshot?
	local profile = CommanderService.get(player)
	if not profile then
		return nil
	end
	return ProfileSchema.snapshot(profile, player.UserId, player.DisplayName, CommanderService.isTemporary(player))
end

function CommanderService.push(player: Player)
	local snap = CommanderService.snapshot(player)
	if snap then
		Net.event("ProfileChanged"):FireClient(player, snap)
	end
end

-- Mutates a profile and propagates the change (titles, save flag, client
-- snapshot, listeners). The mutator returns false to signal "no change".
function CommanderService.update(player: Player, mutator: (Profile) -> boolean?): boolean
	local profile = CommanderService.get(player)
	if not profile then
		return false
	end
	local changed = mutator(profile)
	if changed == false then
		return false
	end
	ProfileSchema.refreshTitles(profile)
	DataService.markDirty(player)
	CommanderService.push(player)
	for _, handler in changeHandlers do
		task.spawn(handler, player, profile)
	end
	return true
end

function CommanderService.onChanged(handler: (Player, Profile) -> ())
	table.insert(changeHandlers, handler)
end

function CommanderService.onLoaded(handler: (Player, Profile) -> ())
	table.insert(loadHandlers, handler)
	for player in loaded do
		local profile = CommanderService.get(player)
		if profile then
			task.spawn(handler, player, profile)
		end
	end
end

function CommanderService.whenLoaded(player: Player, timeout: number?): Profile?
	local waited = 0
	while not loaded[player] and player.Parent and waited < (timeout or 15) do
		waited += task.wait(0.1)
	end
	return CommanderService.get(player)
end

local function onPlayerAdded(player: Player)
	DataService.load(player)
	if not player.Parent then
		DataService.release(player)
		return
	end
	loaded[player] = true
	local profile = CommanderService.get(player)
	if profile then
		ProfileSchema.refreshTitles(profile)
		for _, handler in loadHandlers do
			task.spawn(handler, player, profile)
		end
	end
	CommanderService.push(player)
end

local function onPlayerRemoving(player: Player)
	loaded[player] = nil
	DataService.release(player)
end

-- Request handlers (all input is untrusted).
local ACTIONS: { [string]: (Player, { [string]: any }) -> { [string]: any } } = {}

ACTIONS.get = function(player)
	local profile = CommanderService.whenLoaded(player)
	return { ok = profile ~= nil, profile = CommanderService.snapshot(player) }
end

ACTIONS.setFaction = function(player, request)
	local faction = request.faction
	if faction ~= "NATO" and faction ~= "PACT" then
		return { ok = false, error = "INVALID_FACTION" }
	end
	CommanderService.update(player, function(profile)
		if profile.faction == faction then
			return false
		end
		profile.faction = faction
		return true
	end)
	return { ok = true, profile = CommanderService.snapshot(player) }
end

ACTIONS.setTitle = function(player, request)
	local id = request.title
	local profile = CommanderService.get(player)
	if type(id) ~= "string" or not profile or not profile.titlesUnlocked[id] then
		return { ok = false, error = "TITLE_LOCKED" }
	end
	CommanderService.update(player, function(p)
		p.title = id
		return true
	end)
	return { ok = true, profile = CommanderService.snapshot(player) }
end

ACTIONS.setInsignia = function(player, request)
	local id = request.insignia
	local profile = CommanderService.get(player)
	if type(id) ~= "string" or not profile then
		return { ok = false, error = "INVALID_INSIGNIA" }
	end
	local level = Progression.levelForXp(profile.xp)
	for _, insignia in Progression.Insignia do
		if insignia.Id == id then
			if level < insignia.Level then
				return { ok = false, error = "LEVEL_TOO_LOW" }
			end
			CommanderService.update(player, function(p)
				p.insignia = id
				return true
			end)
			return { ok = true, profile = CommanderService.snapshot(player) }
		end
	end
	return { ok = false, error = "INVALID_INSIGNIA" }
end

ACTIONS.setPreferredMap = function(player, request)
	local id = request.map
	if type(id) ~= "string" or (id ~= "" and not Maps.List[id]) then
		return { ok = false, error = "INVALID_MAP" }
	end
	CommanderService.update(player, function(p)
		p.preferredMap = id
		return true
	end)
	return { ok = true, profile = CommanderService.snapshot(player) }
end

function CommanderService.start()
	Net.fn("Profile").OnServerInvoke = function(player: Player, request: any)
		if type(request) ~= "table" or type(request.action) ~= "string" then
			return { ok = false, error = "BAD_REQUEST" }
		end
		local handler = ACTIONS[request.action]
		if not handler then
			return { ok = false, error = "UNKNOWN_ACTION" }
		end
		return handler(player, request)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return CommanderService
