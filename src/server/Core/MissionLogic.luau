--!strict
-- Mission board rules: daily period reset, progress, claiming rewards.
-- Pure logic on a profile table (no Roblox services) so it can be tested.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Missions = require(ReplicatedStorage.Lobby.Config.Missions)
local ProfileSchema = require(script.Parent.ProfileSchema)
local Trackers = require(script.Parent.Trackers)

export type MissionView = {
	id: string,
	group: string,
	text: string,
	progress: number,
	target: number,
	complete: boolean,
	claimed: boolean,
	credits: number,
	xp: number,
}

local MissionLogic = {}

-- UTC calendar day, e.g. "2026-09-24".
function MissionLogic.periodKey(now: number): string
	local t = os.date("!*t", math.floor(now))
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

-- Seconds until the next daily reset (00:00 UTC).
function MissionLogic.secondsToReset(now: number): number
	return 86400 - (math.floor(now) % 86400)
end

local function dailyTrackers(): { Trackers.Tracker }
	local list = {}
	for _, id in Missions.Order do
		local mission = Missions.List[id]
		if mission.Group == "DAILY" then
			table.insert(list, mission.Tracker)
		end
	end
	return list
end

-- Starts a new daily period when the day changed. Returns true on reset.
function MissionLogic.ensurePeriod(profile: ProfileSchema.Profile, now: number): boolean
	local key = MissionLogic.periodKey(now)
	if profile.missions.period == key then
		return false
	end
	profile.missions.period = key
	profile.missions.baseline = Trackers.baseline(profile, dailyTrackers())
	-- daily claims reset; orientation claims persist
	local kept = {}
	for id, claimed in profile.missions.claimed do
		local mission = Missions.List[id]
		if claimed and mission and mission.Group == "ORIENTATION" then
			kept[id] = true
		end
	end
	profile.missions.claimed = kept
	return true
end

local ZERO = ProfileSchema.emptyBaseline()

function MissionLogic.progress(profile: ProfileSchema.Profile, missionId: string): (number, number)
	local mission = Missions.List[missionId]
	if not mission then
		return 0, 1
	end
	-- orientation missions count lifetime interactions (baseline zero)
	local base = if mission.Group == "DAILY" then profile.missions.baseline else ZERO
	local value = Trackers.progress(profile, mission.Tracker, base)
	return math.min(value, mission.Target), mission.Target
end

function MissionLogic.list(profile: ProfileSchema.Profile, now: number): { MissionView }
	MissionLogic.ensurePeriod(profile, now)
	local out: { MissionView } = {}
	for _, id in Missions.Order do
		local mission = Missions.List[id]
		local progress, target = MissionLogic.progress(profile, id)
		table.insert(out, {
			id = id,
			group = mission.Group,
			text = mission.Text,
			progress = progress,
			target = target,
			complete = progress >= target,
			claimed = profile.missions.claimed[id] == true,
			credits = mission.Reward.Credits,
			xp = mission.Reward.XP,
		})
	end
	return out
end

-- Validates and applies a reward claim. Returns ok, error code, reward.
function MissionLogic.claim(
	profile: ProfileSchema.Profile,
	missionId: string,
	now: number
): (boolean, string?, { credits: number, xp: number }?)
	MissionLogic.ensurePeriod(profile, now)
	local mission = Missions.List[missionId]
	if not mission then
		return false, "UNKNOWN_MISSION", nil
	end
	if profile.missions.claimed[missionId] then
		return false, "ALREADY_CLAIMED", nil
	end
	local progress, target = MissionLogic.progress(profile, missionId)
	if progress < target then
		return false, "NOT_COMPLETE", nil
	end
	profile.missions.claimed[missionId] = true
	profile.credits += mission.Reward.Credits
	profile.xp += mission.Reward.XP
	return true, nil, { credits = mission.Reward.Credits, xp = mission.Reward.XP }
end

-- Ids of missions that are complete but not yet claimed.
function MissionLogic.claimable(profile: ProfileSchema.Profile, now: number): { string }
	local out = {}
	for _, view in MissionLogic.list(profile, now) do
		if view.complete and not view.claimed then
			table.insert(out, view.id)
		end
	end
	return out
end

return MissionLogic
