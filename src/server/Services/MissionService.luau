--!strict
-- Mission board backend: lists missions with progress, validates claims,
-- announces newly completed missions once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage.Lobby
local Missions = require(Lobby.Config.Missions)
local Net = require(Lobby.Net)
local MissionLogic = require(script.Parent.Parent.Core.MissionLogic)
local ProfileSchema = require(script.Parent.Parent.Core.ProfileSchema)
local CommanderService = require(script.Parent.CommanderService)
local DataService = require(script.Parent.DataService)

local MissionService = {}

local announced: { [Player]: { [string]: boolean } } = {}

local function view(player: Player): { [string]: any }
	local now = os.time()
	CommanderService.update(player, function(profile)
		return MissionLogic.ensurePeriod(profile, now)
	end)
	local profile = CommanderService.get(player)
	if not profile then
		return { ok = false, error = "NO_PROFILE" }
	end
	return {
		ok = true,
		missions = MissionLogic.list(profile, now),
		resetIn = MissionLogic.secondsToReset(now),
		period = profile.missions.period,
	}
end
MissionService.view = view

local function announce(player: Player, profile: ProfileSchema.Profile, silent: boolean)
	local seen = announced[player]
	if not seen then
		seen = {}
		announced[player] = seen
	end
	local fresh = {}
	for _, id in MissionLogic.claimable(profile, os.time()) do
		if not seen[id] then
			seen[id] = true
			table.insert(fresh, id)
		end
	end
	if silent then
		if #fresh > 0 then
			Net.event("Notify"):FireClient(player, {
				kind = "Mission",
				title = "MISSIONS READY",
				text = ("%d completed mission%s to claim"):format(#fresh, if #fresh == 1 then "" else "s"),
				detail = "Report to the Mission Board",
			})
		end
		return
	end
	for _, id in fresh do
		Net.event("Notify"):FireClient(player, {
			kind = "Mission",
			title = "MISSION COMPLETE",
			text = Missions.List[id].Text,
			detail = "Claim your reward at the Mission Board",
		})
	end
end

local function claim(player: Player, request: { [string]: any }): { [string]: any }
	local id = request.id
	if type(id) ~= "string" or not Missions.List[id] then
		return { ok = false, error = "UNKNOWN_MISSION" }
	end
	local result: { [string]: any } = { ok = false, error = "NO_PROFILE" }
	CommanderService.update(player, function(profile)
		local ok, err, reward = MissionLogic.claim(profile, id, os.time())
		result = { ok = ok, error = err, reward = reward }
		return ok
	end)
	if result.ok and result.reward then
		Net.event("Notify"):FireClient(player, {
			kind = "Reward",
			title = "REWARD RECEIVED",
			text = ("+%d CR · +%d XP"):format(result.reward.credits, result.reward.xp),
			detail = Missions.List[id].Text,
		})
	end
	local current = view(player)
	result.missions = current.missions
	result.resetIn = current.resetIn
	return result
end

function MissionService.start()
	Net.fn("Missions").OnServerInvoke = function(player: Player, request: any)
		if type(request) ~= "table" or type(request.action) ~= "string" then
			return { ok = false, error = "BAD_REQUEST" }
		end
		if not CommanderService.whenLoaded(player) then
			return { ok = false, error = "NO_PROFILE" }
		end
		if request.action == "list" then
			return view(player)
		elseif request.action == "claim" then
			return claim(player, request)
		end
		return { ok = false, error = "UNKNOWN_ACTION" }
	end
	CommanderService.onLoaded(function(player, profile)
		-- start today's period before anything else sees the profile, then
		-- summarise (silently) what is already claimable
		if MissionLogic.ensurePeriod(profile, os.time()) then
			DataService.markDirty(player)
		end
		announce(player, profile, true)
	end)
	CommanderService.onChanged(function(player, profile)
		announce(player, profile, false)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		announced[player] = nil
	end)
end

return MissionService
