--!strict
-- Commander profile: defaults, reconciliation of stored data, and the
-- snapshot sent to the owning client.
--
-- Stored data must stay DataStore-safe: dictionaries only use string keys
-- and no Roblox datatypes are stored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Lobby.Config
local Progression = require(Config.Progression)
local Units = require(Config.Units)

export type Stats = {
	matches: number,
	victories: number,
	defeats: number,
	sectorsCaptured: number,
	unitsDestroyed: number,
	teamBattles: number,
	playMinutes: number,
	rating: number,
	mapsPlayed: { [string]: number },
	victoriesByMap: { [string]: number },
}

export type Baseline = {
	stats: { [string]: number },
	sets: { [string]: { [string]: boolean } },
	interactions: { [string]: number },
}

export type Profile = {
	version: number,
	createdAt: number,
	lastLogin: number,
	xp: number,
	credits: number,
	faction: string,
	title: string,
	insignia: string,
	preferredMap: string,
	titlesUnlocked: { [string]: boolean },
	unitsUnlocked: { [string]: boolean },
	camosOwned: { [string]: boolean },
	unitCamos: { [string]: string },
	stats: Stats,
	lobby: {
		interactions: { [string]: number },
		distinct: { [string]: { [string]: boolean } },
	},
	missions: {
		period: string,
		baseline: Baseline,
		claimed: { [string]: boolean },
	},
	event: {
		id: string,
		baseline: Baseline,
		claimedTiers: { [string]: boolean },
	},
}

local ProfileSchema = {}

ProfileSchema.Version = 1

local function emptyBaseline(): Baseline
	return { stats = {}, sets = {}, interactions = {} }
end
ProfileSchema.emptyBaseline = emptyBaseline

function ProfileSchema.default(now: number): Profile
	local units: { [string]: boolean } = {}
	for id, unit in Units.List do
		if unit.Unlock.Default then
			units[id] = true
		end
	end
	return {
		version = ProfileSchema.Version,
		createdAt = now,
		lastLogin = now,
		xp = 0,
		credits = 500,
		faction = "NATO",
		title = "RECRUIT",
		insignia = Progression.Insignia[1].Id,
		preferredMap = "",
		titlesUnlocked = { RECRUIT = true },
		unitsUnlocked = units,
		camosOwned = { FACTORY = true },
		unitCamos = {},
		stats = {
			matches = 0,
			victories = 0,
			defeats = 0,
			sectorsCaptured = 0,
			unitsDestroyed = 0,
			teamBattles = 0,
			playMinutes = 0,
			rating = 1000,
			mapsPlayed = {},
			victoriesByMap = {},
		},
		lobby = { interactions = {}, distinct = {} },
		missions = { period = "", baseline = emptyBaseline(), claimed = {} },
		event = { id = "", baseline = emptyBaseline(), claimedTiers = {} },
	}
end

-- Fills anything missing/mistyped in stored data from the defaults (keeps
-- stored values of the right type). Unknown extra keys are preserved.
local function reconcile(target: any, defaults: any): any
	if type(target) ~= "table" then
		return defaults
	end
	for key, default in defaults do
		local value = target[key]
		if type(default) == "table" then
			-- only reconcile "record" tables; open dictionaries stay as stored
			if type(value) ~= "table" then
				target[key] = default
			elseif next(default) ~= nil then
				reconcile(value, default)
			end
		elseif type(value) ~= type(default) then
			target[key] = default
		end
	end
	return target
end

function ProfileSchema.reconcile(stored: any, now: number): Profile
	local defaults = ProfileSchema.default(now)
	if type(stored) ~= "table" then
		return defaults
	end
	local profile = reconcile(stored, defaults)
	-- default unlocks added after the profile was created
	for id in defaults.unitsUnlocked do
		profile.unitsUnlocked[id] = true
	end
	profile.titlesUnlocked.RECRUIT = true
	profile.camosOwned.FACTORY = true
	if profile.faction ~= "NATO" and profile.faction ~= "PACT" then
		profile.faction = "NATO"
	end
	profile.version = ProfileSchema.Version
	return profile :: Profile
end

-- Numeric value of a stat path. Supports dotted paths and the derived
-- "mapsPlayedCount".
function ProfileSchema.statValue(profile: Profile, path: string): number
	if path == "mapsPlayedCount" then
		local n = 0
		for _ in profile.stats.mapsPlayed do
			n += 1
		end
		return n
	end
	local node: any = profile.stats
	for key in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return 0
		end
		node = node[key]
	end
	return if type(node) == "number" then node else 0
end

function ProfileSchema.statSet(profile: Profile, path: string): { [string]: any }
	local node = (profile.stats :: any)[path]
	return if type(node) == "table" then node else {}
end

export type Snapshot = {
	userId: number,
	name: string,
	xp: number,
	level: number,
	levelXp: number,
	levelNeed: number,
	rankShort: string,
	rankName: string,
	credits: number,
	faction: string,
	title: string,
	titleName: string,
	insignia: string,
	preferredMap: string,
	titlesUnlocked: { string },
	unitsUnlocked: { string },
	camosOwned: { string },
	unitCamos: { [string]: string },
	stats: Stats,
	achievements: { { id: string, name: string, description: string, progress: number, target: number, done: boolean } },
	temporary: boolean,
}

local function keys(dict: { [string]: any }): { string }
	local out = {}
	for key in dict do
		table.insert(out, key)
	end
	table.sort(out)
	return out
end

function ProfileSchema.snapshot(profile: Profile, userId: number, name: string, temporary: boolean): Snapshot
	local level, into, need = Progression.levelProgress(profile.xp)
	local rank = Progression.rankFor(level)
	local titleName = profile.title
	for _, title in Progression.Titles do
		if title.Id == profile.title then
			titleName = title.Name
		end
	end
	local achievements = {}
	for _, a in Progression.Achievements do
		local value = ProfileSchema.statValue(profile, a.Stat)
		table.insert(achievements, {
			id = a.Id,
			name = a.Name,
			description = a.Description,
			progress = math.min(value, a.Target),
			target = a.Target,
			done = value >= a.Target,
		})
	end
	return {
		userId = userId,
		name = name,
		xp = profile.xp,
		level = level,
		levelXp = into,
		levelNeed = need,
		rankShort = rank.Short,
		rankName = Progression.rankName(level, profile.faction),
		credits = profile.credits,
		faction = profile.faction,
		title = profile.title,
		titleName = titleName,
		insignia = profile.insignia,
		preferredMap = profile.preferredMap,
		titlesUnlocked = keys(profile.titlesUnlocked),
		unitsUnlocked = keys(profile.unitsUnlocked),
		camosOwned = keys(profile.camosOwned),
		unitCamos = table.clone(profile.unitCamos),
		stats = profile.stats,
		achievements = achievements,
		temporary = temporary,
	}
end

-- Titles whose requirement is met (level / victories); event titles are
-- granted by the event reward track instead.
function ProfileSchema.refreshTitles(profile: Profile): { string }
	local granted = {}
	local level = Progression.levelForXp(profile.xp)
	for _, title in Progression.Titles do
		if not profile.titlesUnlocked[title.Id] then
			local ok = false
			if title.Level and level >= title.Level then
				ok = true
			elseif title.Victories and profile.stats.victories >= title.Victories then
				ok = true
			end
			if ok then
				profile.titlesUnlocked[title.Id] = true
				table.insert(granted, title.Id)
			end
		end
	end
	return granted
end

return ProfileSchema
