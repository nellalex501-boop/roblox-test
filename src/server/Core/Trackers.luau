--!strict
-- Progress trackers shared by missions and event challenges.
--
-- A baseline is captured at the start of a period (daily missions) or an
-- event; progress is measured against it:
--   Stat        current stat value - baseline value
--   Distinct    new keys in a stat set (e.g. maps played) since baseline
--   Interaction lobby interactions of a kind (optionally one id, or
--               distinct ids) since baseline

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventTypes = require(ReplicatedStorage.Lobby.Config.EventTypes)
local ProfileSchema = require(script.Parent.ProfileSchema)

export type Tracker = EventTypes.Tracker

local Trackers = {}

local function interactionKey(tracker: Tracker): string
	local kind = tracker.Kind or ""
	if tracker.Id then
		return kind .. ":" .. tracker.Id
	elseif tracker.DistinctIds then
		return kind .. "#distinct"
	end
	return kind
end

local function interactionValue(profile: ProfileSchema.Profile, tracker: Tracker): number
	local kind = tracker.Kind or ""
	local lobby = profile.lobby
	if tracker.Id then
		return lobby.interactions[kind .. ":" .. tracker.Id] or 0
	elseif tracker.DistinctIds then
		local n = 0
		local set = lobby.distinct[kind]
		if set then
			for _ in set do
				n += 1
			end
		end
		return n
	end
	return lobby.interactions[kind] or 0
end

-- Captures the current values of everything the trackers measure.
function Trackers.baseline(profile: ProfileSchema.Profile, trackers: { Tracker }): ProfileSchema.Baseline
	local base = ProfileSchema.emptyBaseline()
	for _, tracker in trackers do
		if tracker.Type == "Stat" and tracker.Stat then
			base.stats[tracker.Stat] = ProfileSchema.statValue(profile, tracker.Stat)
		elseif tracker.Type == "Distinct" and tracker.Stat then
			local set = {}
			for key in ProfileSchema.statSet(profile, tracker.Stat) do
				set[key] = true
			end
			base.sets[tracker.Stat] = set
		elseif tracker.Type == "Interaction" then
			base.interactions[interactionKey(tracker)] = interactionValue(profile, tracker)
		end
	end
	return base
end

function Trackers.progress(profile: ProfileSchema.Profile, tracker: Tracker, base: ProfileSchema.Baseline): number
	if tracker.Type == "Stat" and tracker.Stat then
		local start = base.stats[tracker.Stat] or 0
		return math.max(0, ProfileSchema.statValue(profile, tracker.Stat) - start)
	elseif tracker.Type == "Distinct" and tracker.Stat then
		local seen = base.sets[tracker.Stat] or {}
		local n = 0
		for key in ProfileSchema.statSet(profile, tracker.Stat) do
			if not seen[key] then
				n += 1
			end
		end
		return n
	elseif tracker.Type == "Interaction" then
		local start = base.interactions[interactionKey(tracker)] or 0
		return math.max(0, interactionValue(profile, tracker) - start)
	end
	return 0
end

-- Records a lobby interaction on the profile. Returns true if it was new
-- for distinct-id tracking.
function Trackers.recordInteraction(profile: ProfileSchema.Profile, kind: string, id: string): boolean
	local lobby = profile.lobby
	lobby.interactions[kind] = (lobby.interactions[kind] or 0) + 1
	if id ~= "" then
		local key = kind .. ":" .. id
		lobby.interactions[key] = (lobby.interactions[key] or 0) + 1
	end
	local set = lobby.distinct[kind]
	if not set then
		set = {}
		lobby.distinct[kind] = set
	end
	local new = id ~= "" and not set[id]
	if id ~= "" then
		set[id] = true
	end
	return new
end

return Trackers
