--!strict
-- Commander profile persistence.
--
-- * Loads with retries (exponential backoff).
-- * Saves with UpdateAsync and merges instead of overwriting: credits/xp
--   changes made in the lobby are applied as deltas on top of whatever is
--   stored, and match stats never go backwards. That keeps the lobby safe
--   when RTS match servers also write stats to the same key.
-- * Autosave loop + save on leave + BindToClose.
-- * When DataStores are unavailable (e.g. an unpublished place in Studio)
--   profiles are temporary in-memory copies and the client is told so.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Core = script.Parent.Parent.Core
local ProfileSchema = require(Core.ProfileSchema)

export type Session = {
	profile: ProfileSchema.Profile,
	baseCredits: number,
	baseXp: number,
	temporary: boolean,
	dirty: boolean,
	saving: boolean,
	released: boolean,
}

local DataService = {}

DataService.StoreName = "ColdWarLobby_Commanders_v1"
DataService.AutosaveInterval = 120
DataService.Retries = 3
-- In Studio without DataStore access, seed temporary profiles with demo
-- stats so every panel shows realistic data while testing.
DataService.DemoDataInStudio = true

local store: DataStore? = nil
local available = false
local sessions: { [Player]: Session } = {}

local function now(): number
	return os.time()
end

local function retry<T>(fn: () -> T): (boolean, T | string)
	local lastError = ""
	for attempt = 1, DataService.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		-- access errors will not fix themselves; stop retrying
		if lastError:find("StudioAccessToApisNotAllowed") or lastError:find("publish") then
			break
		end
		if attempt < DataService.Retries then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

local function keyFor(player: Player): string
	return "commander_" .. tostring(player.UserId)
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataService.StoreName)
	end)
	if ok then
		store = result
		available = true
	else
		warn("[Lobby] DataStores unavailable, profiles will be temporary:", result)
	end
end

function DataService.isAvailable(): boolean
	return available
end

-- Access errors (unpublished place, Studio API access off) will not fix
-- themselves: stop using DataStores for this server session.
function DataService.reportError(err: any): boolean
	local text = tostring(err)
	if text:find("StudioAccessToApisNotAllowed") or text:find("publish") then
		if available then
			warn("[Lobby] DataStores unavailable for this session:", text)
		end
		available = false
		return true
	end
	return false
end

local function seedDemo(profile: ProfileSchema.Profile, userId: number)
	local rng = Random.new(math.abs(userId) % 100000 + 7)
	local stats = profile.stats
	stats.matches = rng:NextInteger(24, 90)
	stats.victories = math.floor(stats.matches * rng:NextNumber(0.42, 0.62))
	stats.defeats = stats.matches - stats.victories
	stats.sectorsCaptured = stats.matches * rng:NextInteger(3, 6)
	stats.unitsDestroyed = stats.matches * rng:NextInteger(8, 15)
	stats.teamBattles = math.floor(stats.matches * 0.4)
	stats.playMinutes = stats.matches * 22
	stats.rating = 1000 + (stats.victories - stats.defeats) * 12
	stats.mapsPlayed = { TRAIN_STATION = 6, RIVER_CROSSING = 11, CATHEDRAL = 4, DAM = 3 }
	stats.victoriesByMap = { RIVER_CROSSING = 6, TRAIN_STATION = 3 }
	profile.xp = stats.matches * 140 + stats.victories * 90
	profile.credits = 2400
end

-- Loads (or creates) the player's profile. Yields.
function DataService.load(player: Player): Session
	local profile: ProfileSchema.Profile
	local temporary = true
	local s = store
	if available and s then
		local ok, result = retry(function()
			return s:GetAsync(keyFor(player))
		end)
		if ok then
			profile = ProfileSchema.reconcile(result, now())
			temporary = false
		else
			if not DataService.reportError(result) then
				warn(("[Lobby] Could not load profile for %s: %s"):format(player.Name, tostring(result)))
			end
			profile = ProfileSchema.default(now())
		end
	else
		profile = ProfileSchema.default(now())
	end
	if temporary and RunService:IsStudio() and DataService.DemoDataInStudio then
		seedDemo(profile, player.UserId)
	end
	profile.lastLogin = now()
	local session: Session = {
		profile = profile,
		baseCredits = profile.credits,
		baseXp = profile.xp,
		temporary = temporary,
		dirty = false,
		saving = false,
		released = false,
	}
	sessions[player] = session
	return session
end

function DataService.get(player: Player): Session?
	return sessions[player]
end

function DataService.markDirty(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = true
	end
end

local function maxMerge(stored: { [string]: number }, current: { [string]: number }): { [string]: number }
	local out = table.clone(stored)
	for key, value in current do
		out[key] = math.max(out[key] or 0, value)
	end
	return out
end

-- Saves one session. Returns true when written (or nothing to write).
function DataService.save(player: Player): boolean
	local session = sessions[player]
	local s = store
	if not session or session.temporary or not available or not s then
		return true
	end
	if session.saving then
		return false
	end
	session.saving = true
	local profile = session.profile
	local creditsAtStart = profile.credits
	local xpAtStart = profile.xp
	local creditsDelta = creditsAtStart - session.baseCredits
	local xpDelta = xpAtStart - session.baseXp
	local ok, result = retry(function()
		return s:UpdateAsync(keyFor(player), function(old: any)
			local stored = ProfileSchema.reconcile(old, now())
			local merged = table.clone(profile) :: any
			merged.credits = math.max(0, stored.credits + creditsDelta)
			merged.xp = math.max(0, stored.xp + xpDelta)
			local stats = table.clone(profile.stats) :: any
			for key, value in stored.stats :: any do
				if type(value) == "number" then
					stats[key] = math.max(value, stats[key] or 0)
				end
			end
			stats.mapsPlayed = maxMerge(stored.stats.mapsPlayed, profile.stats.mapsPlayed)
			stats.victoriesByMap = maxMerge(stored.stats.victoriesByMap, profile.stats.victoriesByMap)
			merged.stats = stats
			return merged
		end)
	end)
	session.saving = false
	if ok and type(result) == "table" then
		local merged = result :: any
		-- adopt the stored values so later deltas start from them, keeping
		-- any change made while the save was in flight
		profile.credits = merged.credits + (profile.credits - creditsAtStart)
		profile.xp = merged.xp + (profile.xp - xpAtStart)
		for key, value in merged.stats do
			local mine = (profile.stats :: any)[key]
			if type(value) == "number" and type(mine) == "number" then
				(profile.stats :: any)[key] = math.max(mine, value)
			end
		end
		profile.stats.mapsPlayed = maxMerge(merged.stats.mapsPlayed, profile.stats.mapsPlayed)
		profile.stats.victoriesByMap = maxMerge(merged.stats.victoriesByMap, profile.stats.victoriesByMap)
		session.baseCredits = merged.credits
		session.baseXp = merged.xp
		session.dirty = profile.credits ~= creditsAtStart or profile.xp ~= xpAtStart
		return true
	end
	warn(("[Lobby] Save failed for %s: %s"):format(player.Name, tostring(result)))
	return false
end

function DataService.release(player: Player)
	local session = sessions[player]
	if not session or session.released then
		return
	end
	session.released = true
	DataService.save(player)
	sessions[player] = nil
end

function DataService.startAutosave()
	task.spawn(function()
		while true do
			task.wait(DataService.AutosaveInterval)
			for player, session in sessions do
				if session.dirty and not session.released then
					task.spawn(DataService.save, player)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.5)
		end
	end)
end

return DataService
