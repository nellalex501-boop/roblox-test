--!strict
-- Seasonal events: the active operation, per-player challenge progress
-- (measured from when the player first saw the event), the reward track,
-- and applying the event to the Event Area. Checks every minute whether the
-- active event changed (scheduled rotation) and swaps the world dressing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage.Lobby
local Events = require(Lobby.Config.Events)
local Maps = require(Lobby.Config.Maps)
local Net = require(Lobby.Net)
local Units = require(Lobby.Config.Units)
local Layout = require(Lobby.Config.Layout)
local ProfileSchema = require(script.Parent.Parent.Core.ProfileSchema)
local Trackers = require(script.Parent.Parent.Core.Trackers)
local EventAreaStations = require(script.Parent.Parent.World.Stations.EventArea)
local CommanderService = require(script.Parent.CommanderService)

local EventService = {}

local current: Events.Event = Events.current(os.time())
local world: Instance? = nil
local announced: { [Player]: { [string]: boolean } } = {}

function EventService.current(): Events.Event
	return current
end

local function trackers(event: Events.Event): { Trackers.Tracker }
	local list = {}
	for _, challenge in event.Challenges do
		table.insert(list, challenge.Tracker)
	end
	return list
end

-- Starts the event for this profile the first time it sees it.
local function ensure(profile: ProfileSchema.Profile): boolean
	if profile.event.id == current.Id then
		return false
	end
	profile.event = { id = current.Id, baseline = Trackers.baseline(profile, trackers(current)), claimedTiers = {} }
	return true
end

function EventService.progress(profile: ProfileSchema.Profile): { [string]: any }
	local challenges = {}
	local points = 0
	for _, challenge in current.Challenges do
		local value = math.min(Trackers.progress(profile, challenge.Tracker, profile.event.baseline), challenge.Target)
		local complete = value >= challenge.Target
		if complete then
			points += challenge.Points
		end
		table.insert(challenges, {
			id = challenge.Id,
			text = challenge.Text,
			progress = value,
			target = challenge.Target,
			points = challenge.Points,
			complete = complete,
		})
	end
	local rewards = {}
	for index, tier in current.Rewards do
		local claimed = profile.event.claimedTiers[tostring(index)] == true
		table.insert(rewards, {
			index = index,
			points = tier.Points,
			name = tier.Name,
			kind = tier.Kind,
			claimed = claimed,
			claimable = not claimed and points >= tier.Points,
		})
	end
	return { challenges = challenges, points = points, rewards = rewards }
end

function EventService.publicInfo(now: number): { [string]: any }
	local limited = {}
	for _, id in current.LimitedUnits do
		local unit = Units.List[id]
		if unit then
			table.insert(limited, { id = id, name = unit.Name })
		end
	end
	local featured = current.FeaturedMap and Maps.List[current.FeaturedMap]
	return {
		id = current.Id,
		label = current.Label,
		title = current.Title,
		codename = current.Codename,
		tagline = current.Tagline,
		description = current.Description,
		endsAt = current.EndsAt,
		daysRemaining = Events.daysRemaining(current, now),
		featuredMap = current.FeaturedMap,
		featuredMapName = current.FeaturedMapName or (if featured then featured.Name else nil),
		limitedUnits = limited,
		palette = current.Palette,
		active = current.Id ~= Events.Standby.Id,
	}
end

local function applyReward(profile: ProfileSchema.Profile, tier: Events.RewardTier)
	if tier.Kind == "Credits" and type(tier.Value) == "number" then
		profile.credits += tier.Value
	elseif tier.Kind == "Camo" and type(tier.Value) == "string" then
		profile.camosOwned[tier.Value] = true
	elseif tier.Kind == "Title" and type(tier.Value) == "string" then
		profile.titlesUnlocked[tier.Value] = true
	elseif tier.Kind == "Unit" and type(tier.Value) == "string" then
		profile.unitsUnlocked[tier.Value] = true
	end
end

local function announce(player: Player, profile: ProfileSchema.Profile, silent: boolean)
	local seen = announced[player]
	if not seen then
		seen = {}
		announced[player] = seen
	end
	for _, challenge in EventService.progress(profile).challenges do
		local key = current.Id .. ":" .. challenge.id
		if challenge.complete and not seen[key] then
			seen[key] = true
			if not silent then
				Net.event("Notify"):FireClient(player, {
					kind = "Event",
					title = "CHALLENGE COMPLETE",
					text = challenge.text,
					detail = ("+%d OPERATION POINTS"):format(challenge.points),
				})
			end
		end
	end
end

function EventService.applyWorld()
	local root = world
	if not root then
		return
	end
	local zones = root:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("EventArea")
	if zone then
		EventAreaStations.apply(zone, Layout.frame(Layout.Zones.EventArea), current, os.time())
	end
end

local function request(player: Player, req: { [string]: any }): { [string]: any }
	local profile = CommanderService.whenLoaded(player)
	if not profile then
		return { ok = false, error = "NO_PROFILE" }
	end
	CommanderService.update(player, ensure)
	if req.action == "get" then
		return { ok = true, event = EventService.publicInfo(os.time()), progress = EventService.progress(profile) }
	elseif req.action == "claim" then
		local index = req.tier
		if type(index) ~= "number" or index % 1 ~= 0 then
			return { ok = false, error = "BAD_TIER" }
		end
		local tier = current.Rewards[index]
		if not tier then
			return { ok = false, error = "BAD_TIER" }
		end
		local result: { [string]: any } = { ok = false, error = "NOT_ENOUGH_POINTS" }
		CommanderService.update(player, function(p)
			local state = EventService.progress(p)
			if p.event.claimedTiers[tostring(index)] then
				result = { ok = false, error = "ALREADY_CLAIMED" }
				return false
			end
			if state.points < tier.Points then
				return false
			end
			p.event.claimedTiers[tostring(index)] = true
			applyReward(p, tier)
			result = { ok = true, reward = tier.Name }
			return true
		end)
		if result.ok then
			Net.event("Notify"):FireClient(
				player,
				{ kind = "Reward", title = "OPERATION REWARD", text = tier.Name, detail = current.Codename }
			)
		end
		result.event = EventService.publicInfo(os.time())
		result.progress = EventService.progress(profile)
		return result
	end
	return { ok = false, error = "UNKNOWN_ACTION" }
end

function EventService.start(root: Instance)
	world = root
	Net.fn("Event").OnServerInvoke = function(player: Player, req: any)
		if type(req) ~= "table" or type(req.action) ~= "string" then
			return { ok = false, error = "BAD_REQUEST" }
		end
		return request(player, req)
	end
	CommanderService.onLoaded(function(player, profile)
		CommanderService.update(player, ensure)
		announce(player, profile, true)
	end)
	CommanderService.onChanged(function(player, profile)
		if profile.event.id == current.Id then
			announce(player, profile, false)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		announced[player] = nil
	end)
	-- the builder already applied the event; keep texts (days left) fresh
	-- and rotate when the schedule changes
	task.spawn(function()
		local lastDays = Events.daysRemaining(current, os.time())
		while true do
			task.wait(60)
			local now = os.time()
			local active = Events.current(now)
			local days = Events.daysRemaining(active, now)
			if active.Id ~= current.Id or days ~= lastDays then
				current = active
				lastDays = days
				EventService.applyWorld()
			end
		end
	end)
end

return EventService
