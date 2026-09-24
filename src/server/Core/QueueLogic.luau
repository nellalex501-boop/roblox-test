--!strict
-- Matchmaking queues and private lobbies (pure logic, single server).
--
-- Fixed queues (1V1 / 2V2 / 4V4) form a match when enough players wait.
-- QUICK players are flexible: they top up fixed queues that already have
-- someone waiting, otherwise they are matched with each other in the
-- largest mode their number allows. Teams are balanced by rating with a
-- snake draft; the map is the most preferred map among the players,
-- falling back to a map recommended for the mode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Lobby.Config
local GameModes = require(Config.GameModes)
local Maps = require(Config.Maps)

export type Entry = {
	userId: number,
	mode: string,
	joinedAt: number,
	rating: number,
	preferredMap: string?,
}

export type Match = {
	mode: string,
	players: { number },
	teams: { { number } },
	map: string,
	private: boolean,
	code: string?,
}

export type Lobby = {
	code: string,
	host: number,
	size: string,
	map: string,
	members: { number },
	createdAt: number,
}

export type Queue = {
	entries: { Entry },
	lobbies: { [string]: Lobby },
	memberOf: { [number]: string },
	random: Random,
	join: (
		Queue,
		userId: number,
		mode: string,
		now: number,
		rating: number?,
		preferredMap: string?
	) -> (boolean, string?),
	leave: (Queue, userId: number) -> boolean,
	modeOf: (Queue, userId: number) -> string?,
	position: (Queue, userId: number) -> number?,
	counts: (Queue) -> { [string]: number },
	tick: (Queue, now: number) -> { Match },
	createPrivate: (Queue, host: number, size: string, code: string, now: number) -> (Lobby?, string?),
	joinPrivate: (Queue, userId: number, code: string) -> (Lobby?, string?),
	leavePrivate: (Queue, userId: number) -> Lobby?,
	setPrivateOptions: (Queue, host: number, size: string?, map: string?) -> (boolean, string?),
	startPrivate: (Queue, host: number) -> (Match?, string?),
	lobbyOf: (Queue, userId: number) -> Lobby?,
	ratings: { [number]: number },
}

local QueueLogic = {}

local function isFixed(mode: string): boolean
	return GameModes.playersNeeded(mode) ~= nil and mode ~= "QUICK" and mode ~= "PRIVATE"
end

-- Snake draft over players sorted by rating (desc): A B B A A B B A ...
function QueueLogic.balanceTeams(players: { number }, ratings: { [number]: number }): { { number } }
	local sorted = table.clone(players)
	table.sort(sorted, function(a, b)
		local ra, rb = ratings[a] or 1000, ratings[b] or 1000
		if ra == rb then
			return a < b
		end
		return ra > rb
	end)
	local teams = { {}, {} }
	for i, userId in sorted do
		local pick = (i - 1) % 4
		local team = if pick == 0 or pick == 3 then 1 else 2
		table.insert(teams[team], userId)
	end
	return teams
end

-- Most preferred map among the players; ties broken by catalogue order;
-- without preferences, a map recommended for the mode.
function QueueLogic.pickMap(mode: string, preferences: { string }, random: Random): string
	local votes: { [string]: number } = {}
	for _, map in preferences do
		if Maps.List[map] then
			votes[map] = (votes[map] or 0) + 1
		end
	end
	local best, bestVotes = nil, 0
	for _, id in Maps.Order do
		local v = votes[id] or 0
		if v > bestVotes then
			best, bestVotes = id, v
		end
	end
	if best then
		return best
	end
	local candidates = {}
	for _, id in Maps.Order do
		if table.find(Maps.List[id].Recommended, mode) then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then
		candidates = table.clone(Maps.Order)
	end
	return candidates[random:NextInteger(1, #candidates)]
end

function QueueLogic.new(seed: number?): Queue
	local self = {} :: Queue
	self.entries = {}
	self.lobbies = {}
	self.memberOf = {}
	self.ratings = {}
	self.random = Random.new(seed or 1985)

	function self.join(q: Queue, userId: number, mode: string, now: number, rating: number?, preferredMap: string?)
		if mode ~= "QUICK" and not isFixed(mode) then
			return false, "INVALID_MODE"
		end
		if q.memberOf[userId] then
			return false, "IN_PRIVATE_LOBBY"
		end
		q:leave(userId)
		q.ratings[userId] = rating or 1000
		local entry: Entry = {
			userId = userId,
			mode = mode,
			joinedAt = now,
			rating = rating or 1000,
			preferredMap = preferredMap,
		}
		table.insert(q.entries, entry)
		return true, nil
	end

	function self.leave(q: Queue, userId: number)
		for i, entry in q.entries do
			if entry.userId == userId then
				table.remove(q.entries, i)
				return true
			end
		end
		return false
	end

	function self.modeOf(q: Queue, userId: number)
		for _, entry in q.entries do
			if entry.userId == userId then
				return entry.mode
			end
		end
		return nil
	end

	function self.position(q: Queue, userId: number)
		local mode = q:modeOf(userId)
		if not mode then
			return nil
		end
		local n = 0
		for _, entry in q.entries do
			if entry.mode == mode then
				n += 1
				if entry.userId == userId then
					return n
				end
			end
		end
		return nil
	end

	function self.counts(q: Queue)
		local counts: { [string]: number } = { QUICK = 0 }
		for _, mode in GameModes.QueueModes do
			counts[mode] = 0
		end
		for _, entry in q.entries do
			counts[entry.mode] = (counts[entry.mode] or 0) + 1
		end
		local inPrivate = 0
		for _, lobby in q.lobbies do
			inPrivate += #lobby.members
		end
		counts.PRIVATE = inPrivate
		return counts
	end

	local function take(q: Queue, list: { Entry }, count: number): { Entry }
		local taken = {}
		for _ = 1, count do
			local entry = table.remove(list, 1)
			if not entry then
				break
			end
			table.insert(taken, entry)
			local index = table.find(q.entries, entry)
			if index then
				table.remove(q.entries, index)
			end
		end
		return taken
	end

	local function makeMatch(q: Queue, mode: string, group: { Entry }): Match
		local players, prefs = {}, {}
		for _, entry in group do
			table.insert(players, entry.userId)
			if entry.preferredMap and entry.preferredMap ~= "" then
				table.insert(prefs, entry.preferredMap)
			end
		end
		return {
			mode = mode,
			players = players,
			teams = QueueLogic.balanceTeams(players, q.ratings),
			map = QueueLogic.pickMap(mode, prefs, q.random),
			private = false,
			code = nil,
		}
	end

	function self.tick(q: Queue, _now: number)
		local matches = {}
		local byMode: { [string]: { Entry } } = { QUICK = {} }
		for _, mode in GameModes.QueueModes do
			byMode[mode] = {}
		end
		for _, entry in q.entries do
			table.insert(byMode[entry.mode], entry)
		end
		-- largest fixed modes first; quick players top up waiting queues
		for _, mode in GameModes.QueueModes do
			local needed = GameModes.playersNeeded(mode) :: number
			local dedicated = byMode[mode]
			while #dedicated >= 1 and #dedicated + #byMode.QUICK >= needed do
				local group = take(q, dedicated, math.min(#dedicated, needed))
				for _, entry in take(q, byMode.QUICK, needed - #group) do
					table.insert(group, entry)
				end
				table.insert(matches, makeMatch(q, mode, group))
			end
		end
		-- quick-only matches: largest mode their count allows
		while #byMode.QUICK >= 2 do
			local mode = if #byMode.QUICK >= 8 then "4V4" elseif #byMode.QUICK >= 4 then "2V2" else "1V1"
			local needed = GameModes.playersNeeded(mode) :: number
			table.insert(matches, makeMatch(q, mode, take(q, byMode.QUICK, needed)))
		end
		return matches
	end

	function self.lobbyOf(q: Queue, userId: number)
		local code = q.memberOf[userId]
		return if code then q.lobbies[code] else nil
	end

	function self.createPrivate(q: Queue, host: number, size: string, code: string, now: number)
		if not isFixed(size) then
			return nil, "INVALID_SIZE"
		end
		if q.lobbies[code] then
			return nil, "CODE_TAKEN"
		end
		q:leave(host)
		q:leavePrivate(host)
		local lobby: Lobby = {
			code = code,
			host = host,
			size = size,
			map = QueueLogic.pickMap(size, {}, q.random),
			members = { host },
			createdAt = now,
		}
		q.lobbies[code] = lobby
		q.memberOf[host] = code
		return lobby, nil
	end

	function self.joinPrivate(q: Queue, userId: number, code: string)
		local lobby = q.lobbies[string.upper(code)]
		if not lobby then
			return nil, "NO_SUCH_LOBBY"
		end
		if q.memberOf[userId] == lobby.code then
			return lobby, nil
		end
		local capacity = GameModes.playersNeeded(lobby.size) :: number
		if #lobby.members >= capacity then
			return nil, "LOBBY_FULL"
		end
		q:leave(userId)
		q:leavePrivate(userId)
		table.insert(lobby.members, userId)
		q.memberOf[userId] = lobby.code
		return lobby, nil
	end

	function self.leavePrivate(q: Queue, userId: number)
		local code = q.memberOf[userId]
		if not code then
			return nil
		end
		q.memberOf[userId] = nil
		local lobby = q.lobbies[code]
		if not lobby then
			return nil
		end
		local index = table.find(lobby.members, userId)
		if index then
			table.remove(lobby.members, index)
		end
		if #lobby.members == 0 then
			q.lobbies[code] = nil
		elseif lobby.host == userId then
			lobby.host = lobby.members[1]
		end
		return lobby
	end

	function self.setPrivateOptions(q: Queue, host: number, size: string?, map: string?)
		local lobby = q:lobbyOf(host)
		if not lobby then
			return false, "NOT_IN_LOBBY"
		end
		if lobby.host ~= host then
			return false, "NOT_HOST"
		end
		if size then
			if not isFixed(size) then
				return false, "INVALID_SIZE"
			end
			if #lobby.members > (GameModes.playersNeeded(size) :: number) then
				return false, "TOO_MANY_FOR_SIZE"
			end
			lobby.size = size
		end
		if map then
			if not Maps.List[map] then
				return false, "INVALID_MAP"
			end
			lobby.map = map
		end
		return true, nil
	end

	function self.startPrivate(q: Queue, host: number)
		local lobby = q:lobbyOf(host)
		if not lobby then
			return nil, "NOT_IN_LOBBY"
		end
		if lobby.host ~= host then
			return nil, "NOT_HOST"
		end
		if #lobby.members < 2 then
			return nil, "NEED_TWO_PLAYERS"
		end
		local players = table.clone(lobby.members)
		for _, userId in players do
			q.memberOf[userId] = nil
		end
		q.lobbies[lobby.code] = nil
		return {
			mode = lobby.size,
			players = players,
			teams = QueueLogic.balanceTeams(players, q.ratings),
			map = lobby.map,
			private = true,
			code = lobby.code,
		},
			nil
	end

	return self
end

return QueueLogic
