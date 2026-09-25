--!nocheck
-- PHASE 3 — server integration: boots the real LobbyServer script on the
-- built place (world, remotes, every service) and drives it like players
-- would: joining, walking to stations, triggering prompts and calling the
-- remotes. Each case boots a fresh server (the scheduler resets per case).

local roblox = require("@lune/roblox")

local Runtime = require("../harness/Runtime")

local Scheduler = Runtime.Scheduler
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Instance = roblox.Instance

local function boot(options)
	options = options or {}
	local rt = Runtime.new({
		place = "build/lobby.rbxl",
		studio = options.studio ~= false,
		epoch = options.epoch,
		datastores = options.datastores,
	})
	if options.template then
		local base = Instance.new("Part")
		base.Name = "Baseplate"
		base.Anchored = true
		base.Size = Vector3.new(2048, 16, 2048)
		base.CFrame = CFrame.new(0, -8, 0)
		base.Parent = rt.workspace
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Anchored = true
		spawn.CFrame = CFrame.new(0, 0.5, 0)
		spawn.Parent = rt.workspace
	end
	if options.before then
		options.before(rt)
	end
	rt:runScript(rt:find("ServerScriptService.LobbyServer"))
	Scheduler.advance(0.5)
	return rt
end

-- Runs fn inside a scheduler thread (remote handlers may yield).
local function run(fn, maxSeconds)
	local done, result = false, nil
	Scheduler.spawn(function()
		result = table.pack(fn())
		done = true
	end)
	local waited = 0
	while not done and waited < (maxSeconds or 30) do
		Scheduler.advance(0.1)
		waited += 0.1
	end
	assert(done, "call did not complete")
	return table.unpack(result, 1, result.n)
end

local function invoke(rt, player, remote, request)
	return run(function()
		return rt:invoke(player, remote, request)
	end)
end

local function join(rt, name, userId)
	local player = rt:addPlayer(name, userId)
	rt:spawnCharacter(player)
	Scheduler.advance(1)
	return player
end

local function world(rt)
	return rt.workspace:FindFirstChild("ColdWarLobby")
end

local function promptsOf(rt)
	local list = {}
	for _, d in world(rt):GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "LobbyPrompt" then
			local part = d.Parent
			table.insert(list, {
				prompt = d,
				part = part,
				kind = part:GetAttribute("InteractionKind"),
				id = part:GetAttribute("InteractionId"),
			})
		end
	end
	return list
end

local function findPrompt(rt, kind, id)
	for _, entry in promptsOf(rt) do
		if entry.kind == kind and (id == nil or entry.id == id) then
			return entry
		end
	end
	return nil
end

-- Walks the player's character to a station and triggers its prompt.
local function use(rt, player, kind, id)
	local entry = findPrompt(rt, kind, id)
	assert(entry, ("no %s prompt %s"):format(kind, tostring(id)))
	rt:moveCharacter(player, entry.part.CFrame.Position)
	rt:triggerPrompt(entry.prompt, player)
	Scheduler.advance(0.2)
	return entry
end

local function stand(rt, player, kind, id)
	local entry = findPrompt(rt, kind, id)
	assert(entry, ("no %s prompt %s"):format(kind, tostring(id)))
	rt:moveCharacter(player, entry.part.CFrame.Position)
	return entry
end

local function profileOf(rt, player)
	local CommanderService = rt:requirePath("ServerScriptService.LobbyServer.Services.CommanderService")
	return CommanderService.get(player)
end

local function messages(rt, player, remote)
	local out = {}
	for _, entry in rt.clientLog[player.Name] or {} do
		if entry.remote == remote then
			table.insert(out, entry.args[1])
		end
	end
	return out
end

local function label(root, name)
	local found = root:FindFirstChild(name, true)
	return found and found.Text
end

return function(test)
	test("boot: template displaced, lobby built, remotes and previews ready", function(t)
		local rt = boot({ template = true })
		local root = world(rt)
		t.ok(root ~= nil, "ColdWarLobby built")
		t.eq(root and root:GetAttribute("LobbyReady"), true, "LobbyReady set after all services started")
		local displaced = rt.game:GetService("ServerStorage"):FindFirstChild("LobbyDisplacedTemplate")
		t.ok(displaced and displaced:FindFirstChild("Baseplate"), "template Baseplate moved to ServerStorage")
		t.ok(displaced and displaced:FindFirstChild("SpawnLocation"), "template SpawnLocation moved to ServerStorage")
		t.ok(rt.workspace:FindFirstChild("Baseplate") == nil, "no Baseplate left in Workspace")
		local remotes = rt:find("ReplicatedStorage.Lobby.Remotes")
		local Net = rt:requirePath("ReplicatedStorage.Lobby.Net")
		for _, name in Net.Functions do
			t.ok(remotes:FindFirstChild(name) and remotes[name]:IsA("RemoteFunction"), "RemoteFunction " .. name)
		end
		for _, name in Net.Events do
			t.ok(remotes:FindFirstChild(name) and remotes[name]:IsA("RemoteEvent"), "RemoteEvent " .. name)
		end
		local previews = rt.game:GetService("ReplicatedStorage"):FindFirstChild("LobbyUnitPreviews")
		local Units = rt:requirePath("ReplicatedStorage.Lobby.Config.Units")
		t.eq(previews and #previews:GetChildren(), #Units.Order, "a preview model per unit")
		local painted = 0
		for _, d in previews:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Paint") then
				painted += 1
			end
		end
		t.ge(painted, #Units.Order * 3, "preview parts tagged for paint schemes")
		t.noRuntimeErrors()
	end)

	test("baked lobby is reused when its version matches", function(t)
		local rt = boot({
			before = function(rt)
				local Builder = rt:requirePath("ServerScriptService.LobbyServer.World.Builder")
				local baked = Builder.Build({ Parent = rt.workspace })
				baked:SetAttribute("BakedMarker", true)
			end,
		})
		t.eq(world(rt):GetAttribute("BakedMarker"), true, "existing ColdWarLobby kept (not rebuilt)")
		local count = 0
		for _, child in rt.workspace:GetChildren() do
			if child.Name == "ColdWarLobby" then
				count += 1
			end
		end
		t.eq(count, 1, "exactly one lobby")
		t.noRuntimeErrors()
	end)

	test("join: profile loads, snapshot + status pushed, early character relocated", function(t)
		local rt = boot({
			before = function(rt)
				-- a player whose character loaded before the lobby existed
				local early = rt:addPlayer("Early")
				rt:spawnCharacter(early, CFrame.new(0, -60, 0))
			end,
		})
		Scheduler.advance(1)
		local early = rt.game:GetService("Players"):FindFirstChild("Early")
		local y = early.Character.HumanoidRootPart.CFrame.Position.Y
		t.ok(y > 0 and y < 10, ("early character moved onto a spawn pad (y=%.1f)"):format(y))
		local player = join(rt, "Alpha")
		local snap = rt:lastClientMessage(player, "ProfileChanged")
		t.ok(snap ~= nil, "ProfileChanged pushed on join")
		t.eq(snap and snap[1].credits, 500, "new commander starts with 500 credits")
		t.eq(snap and snap[1].temporary, false, "profile is persistent when DataStores work")
		Scheduler.advance(3)
		local status = rt:lastClientMessage(player, "LobbyStatus")
		t.ok(status ~= nil, "LobbyStatus pushed")
		t.eq(status and status[1].online, 2, "status counts both commanders")
		local response = invoke(rt, player, "Profile", { action = "get" })
		t.ok(response.ok and response.profile.level == 1, "Profile.get returns the snapshot")
		t.eq(invoke(rt, player, "Profile", "nonsense").error, "BAD_REQUEST", "malformed requests rejected")
		t.eq(invoke(rt, player, "Profile", { action = "hack" }).error, "UNKNOWN_ACTION", "unknown actions rejected")
		t.noRuntimeErrors()
	end)

	test("interactions: every prompt in the lobby records on the profile", function(t)
		local rt = boot()
		local player = join(rt, "Walker")
		local list = promptsOf(rt)
		t.ge(#list, 25, "prompt count")
		local kinds = {}
		for _, entry in list do
			rt:moveCharacter(player, entry.part.CFrame.Position)
			rt:triggerPrompt(entry.prompt, player)
			Scheduler.advance(0.8)
			kinds[entry.kind] = (kinds[entry.kind] or 0) + 1
		end
		local profile = profileOf(rt, player)
		local Interactions = rt:requirePath("ReplicatedStorage.Lobby.Interactions")
		for kind in Interactions.Kinds do
			t.ok(kinds[kind] ~= nil, "a station exists for " .. kind)
			t.ok((profile.lobby.interactions[kind] or 0) >= 1, "interaction recorded: " .. kind)
		end
		-- cooldown: spamming one prompt counts once
		local entry = findPrompt(rt, "Leaderboard")
		local before = profile.lobby.interactions.Leaderboard
		for _ = 1, 5 do
			rt:triggerPrompt(entry.prompt, player)
		end
		Scheduler.advance(0.1)
		t.eq(profile.lobby.interactions.Leaderboard, before + 1, "rapid re-triggers are rate limited")
		t.noRuntimeErrors()
	end)

	test("matchmaking: terminals, 1v1 match found and simulated deployment", function(t)
		local rt = boot()
		local a = join(rt, "Able")
		local b = join(rt, "Baker")
		-- away from the terminal: refused
		rt:moveCharacter(a, Vector3.new(0, 3, 30))
		t.eq(
			invoke(rt, a, "Matchmaking", { action = "join", mode = "1V1" }).error,
			"NOT_AT_TERMINAL",
			"must be at the terminal"
		)
		t.eq(
			invoke(rt, a, "Matchmaking", { action = "join", mode = "5V5" }).error,
			"INVALID_MODE",
			"invalid mode rejected"
		)
		stand(rt, a, "Matchmaking", "1V1")
		local r = invoke(rt, a, "Matchmaking", { action = "join", mode = "1V1" })
		t.ok(r.ok and r.state.state == "queued", "queued at the 1V1 terminal")
		t.eq(r.state.needed, 2, "1V1 needs two commanders")
		-- the terminal screen shows the queue
		Scheduler.advance(2.5)
		local terminal
		for _, d in world(rt):GetDescendants() do
			if d:IsA("SurfaceGui") and d.Name == "TerminalScreen" and d:GetAttribute("ModeId") == "1V1" then
				terminal = d
			end
		end
		t.eq(label(terminal, "QueueCount"), "IN QUEUE: 1 / 2", "terminal screen shows queue count")
		-- walking away keeps the queue
		rt:moveCharacter(a, Vector3.new(0, 3, 30))
		stand(rt, b, "Matchmaking", "1V1")
		r = invoke(rt, b, "Matchmaking", { action = "join", mode = "1V1" })
		t.ok(r.ok, "second commander queued")
		Scheduler.advance(1.5)
		local state = rt:lastClientMessage(a, "MatchmakingChanged")[1]
		t.eq(state.state, "found", "match found pushed to the first commander")
		t.eq(#state.match.teams, 2, "two teams")
		t.ok(state.match.mapName ~= nil, "map chosen")
		local notify = rt:lastClientMessage(b, "Notify")[1]
		t.eq(notify.title, "MATCH FOUND", "match-found notification")
		Scheduler.advance(6)
		state = rt:lastClientMessage(a, "MatchmakingChanged")[1]
		t.eq(state.state, "simulated", "deployment simulated in Studio")
		Scheduler.advance(6)
		state = rt:lastClientMessage(a, "MatchmakingChanged")[1]
		t.eq(state.state, "idle", "back to idle after the simulated deployment")
		local MatchmakingService = rt:requirePath("ServerScriptService.LobbyServer.Services.MatchmakingService")
		t.eq(MatchmakingService.stats().deployed, 1, "deployment counted")
		t.noRuntimeErrors()
	end)

	test("matchmaking: 2v2 / 4v4 fill up, quick match tops up, leaving works", function(t)
		local rt = boot()
		local players = {}
		for i = 1, 8 do
			players[i] = join(rt, "P" .. i)
		end
		for i = 1, 3 do
			stand(rt, players[i], "Matchmaking", "2V2")
			t.ok(invoke(rt, players[i], "Matchmaking", { action = "join", mode = "2V2" }).ok, "P" .. i .. " joins 2V2")
		end
		Scheduler.advance(1.5)
		t.eq(invoke(rt, players[1], "Matchmaking", { action = "status" }).state.state, "queued", "3 of 4 keeps waiting")
		stand(rt, players[4], "Matchmaking", "QUICK")
		t.ok(invoke(rt, players[4], "Matchmaking", { action = "join", mode = "QUICK" }).ok, "quick match joined")
		Scheduler.advance(1.5)
		local s = invoke(rt, players[4], "Matchmaking", { action = "status" }).state
		t.eq(s.state, "found", "quick match player tops up the 2V2")
		t.eq(s.match.mode, "2V2", "formed a 2V2")
		t.eq(#s.match.teams[1] + #s.match.teams[2], 4, "four commanders")
		-- 4V4: seven wait, one leaves, then two more
		for i = 5, 8 do
			stand(rt, players[i], "Matchmaking", "4V4")
			invoke(rt, players[i], "Matchmaking", { action = "join", mode = "4V4" })
		end
		Scheduler.advance(1.5)
		t.eq(invoke(rt, players[5], "Matchmaking", { action = "status" }).state.count, 4, "4 of 8 in 4V4")
		local left = invoke(rt, players[8], "Matchmaking", { action = "leave" })
		t.eq(left.state.state, "idle", "leaving the queue")
		t.eq(invoke(rt, players[5], "Matchmaking", { action = "status" }).state.count, 3, "count drops after leaving")
		t.noRuntimeErrors()
	end)

	test("private lobby: create, join by code, host options, start", function(t)
		local rt = boot()
		local host = join(rt, "Host")
		local guest = join(rt, "Guest")
		stand(rt, host, "Matchmaking", "PRIVATE")
		local r = invoke(rt, host, "Matchmaking", { action = "createPrivate", size = "1V1" })
		t.ok(r.ok and r.state.state == "private", "private lobby created")
		local code = r.state.lobby.code
		t.eq(#code, 5, "5-character code")
		t.eq(invoke(rt, host, "Matchmaking", { action = "startPrivate" }).error ~= nil, true, "cannot start alone")
		stand(rt, guest, "Matchmaking", "PRIVATE")
		t.eq(
			invoke(rt, guest, "Matchmaking", { action = "joinPrivate", code = "ZZZZZ" }).error,
			"NO_SUCH_LOBBY",
			"wrong code"
		)
		r = invoke(rt, guest, "Matchmaking", { action = "joinPrivate", code = code:lower() })
		t.ok(r.ok and #r.state.lobby.members == 2, "guest joined with the code (case-insensitive)")
		t.eq(
			invoke(rt, guest, "Matchmaking", { action = "privateOptions", map = "DAM" }).ok,
			false,
			"only the host sets options"
		)
		r = invoke(rt, host, "Matchmaking", { action = "privateOptions", map = "DAM" })
		t.ok(r.ok and r.state.lobby.map == "DAM", "host picks the map")
		r = invoke(rt, host, "Matchmaking", { action = "startPrivate" })
		t.ok(r.ok, "host starts the match")
		local s = invoke(rt, guest, "Matchmaking", { action = "status" }).state
		t.ok(s.state == "found" and s.match.map == "DAM" and s.match.private, "guest deploys to the chosen map")
		t.noRuntimeErrors()
	end)

	test("teleport: live servers teleport to a reserved RTS server with match data", function(t)
		local rt = boot({
			studio = false,
			before = function(rt)
				local GameModes = rt:requirePath("ReplicatedStorage.Lobby.Config.GameModes")
				GameModes.Settings.TargetPlaceId = 123456
			end,
		})
		local a = join(rt, "Red")
		local b = join(rt, "Blue")
		for _, p in { a, b } do
			stand(rt, p, "Matchmaking", "1V1")
			invoke(rt, p, "Matchmaking", { action = "join", mode = "1V1" })
		end
		Scheduler.advance(8)
		t.eq(#rt.teleports, 1, "one teleport for the match")
		local tp = rt.teleports[1]
		t.eq(tp and tp.placeId, 123456, "to the RTS place")
		t.eq(tp and #tp.players, 2, "both commanders together")
		t.ok(tp and tp.data and tp.data.mode == "1V1" and tp.data.map ~= nil, "teleport data carries mode and map")
		t.ok(tp and tp.data and #tp.data.teams == 2, "teleport data carries the teams")
		t.noRuntimeErrors()
	end)

	test("missions: orientation progress from stations, daily from match stats, claim once", function(t)
		local rt = boot()
		local player = join(rt, "Recruit")
		local list = invoke(rt, player, "Missions", { action = "list" })
		t.ok(list.ok and #list.missions == 10, "10 missions listed")
		t.ok(list.resetIn > 0 and list.resetIn <= 86400, "daily reset countdown")
		use(rt, player, "Matchmaking", "QUICK")
		local notifies = messages(rt, player, "Notify")
		t.eq(notifies[#notifies] and notifies[#notifies].title, "MISSION COMPLETE", "completion announced")
		local credits = profileOf(rt, player).credits
		local r = invoke(rt, player, "Missions", { action = "claim", id = "ORI_TERMINAL" })
		t.ok(r.ok, "claim orientation reward")
		t.eq(profileOf(rt, player).credits, credits + 50, "+50 credits")
		t.eq(
			invoke(rt, player, "Missions", { action = "claim", id = "ORI_TERMINAL" }).error,
			"ALREADY_CLAIMED",
			"only once"
		)
		t.eq(
			invoke(rt, player, "Missions", { action = "claim", id = "WIN_3" }).error,
			"NOT_COMPLETE",
			"incomplete refused"
		)
		t.eq(
			invoke(rt, player, "Missions", { action = "claim", id = "FAKE" }).error,
			"UNKNOWN_MISSION",
			"unknown refused"
		)
		-- three different vehicles viewed in the Garage showroom for ORI_INSPECT
		stand(rt, player, "Showroom", "SHOWROOM")
		for _, unit in { "M1_ABRAMS", "T72", "BMP2" } do
			t.ok(invoke(rt, player, "Garage", { action = "view", unit = unit }).ok, "showroom view " .. unit)
		end
		-- a match server reports stats (simulated here through the service)
		local CommanderService = rt:requirePath("ServerScriptService.LobbyServer.Services.CommanderService")
		CommanderService.update(player, function(p)
			p.stats.sectorsCaptured += 12
			return true
		end)
		Scheduler.advance(0.5)
		list = invoke(rt, player, "Missions", { action = "list" })
		local byId = {}
		for _, m in list.missions do
			byId[m.id] = m
		end
		t.ok(byId.ORI_INSPECT.complete, "inspect 3 vehicles complete")
		t.ok(byId.CAPTURE_10.complete, "capture 10 sectors complete from stats")
		t.ok(invoke(rt, player, "Missions", { action = "claim", id = "CAPTURE_10" }).ok, "daily reward claimed")
		-- next UTC day: daily missions reset, orientation claims persist
		Scheduler.advance(86400)
		list = invoke(rt, player, "Missions", { action = "list" })
		for _, m in list.missions do
			byId[m.id] = m
		end
		t.ok(not byId.CAPTURE_10.claimed and byId.CAPTURE_10.progress == 0, "daily mission reset next day")
		t.ok(byId.ORI_TERMINAL.claimed, "orientation claim persists")
		t.noRuntimeErrors()
	end)

	test("leaderboards: several commanders ranked on the boards and the UI", function(t)
		local rt = boot()
		local players = { join(rt, "Low"), join(rt, "High"), join(rt, "Mid") }
		local CommanderService = rt:requirePath("ServerScriptService.LobbyServer.Services.CommanderService")
		for i, value in { 1, 9, 5 } do
			CommanderService.update(players[i], function(p)
				p.stats.victories = value
				p.stats.matches = value * 2
				p.xp = value * 1000
				return true
			end)
		end
		local LeaderboardService = rt:requirePath("ServerScriptService.LobbyServer.Services.LeaderboardService")
		run(function()
			LeaderboardService.refresh()
		end)
		local r = invoke(rt, players[1], "Leaderboards", { action = "get" })
		t.ok(r.ok and #r.boards == 5, "five boards")
		local victories
		for _, board in r.boards do
			if board.id == "MOST_VICTORIES" then
				victories = board
			end
		end
		t.eq(victories.entries[1].name, "High", "most victories first")
		t.eq(victories.entries[3].name, "Low", "least victories last")
		t.eq(victories.source, "GLOBAL", "global OrderedDataStore source")
		t.eq(r.yours.MOST_VICTORIES, 1, "your own value included")
		local gui
		for _, d in world(rt):GetDescendants() do
			if d:IsA("SurfaceGui") and d.Name == "Leaderboard" and d:GetAttribute("BoardId") == "MOST_VICTORIES" then
				gui = d
			end
		end
		local row1 = gui:FindFirstChild("Row1", true)
		t.eq(row1 and row1.Name and label(row1, "Name"), "High", "physical board row 1")
		t.eq(label(row1, "Value"), "9", "physical board value")
		t.noRuntimeErrors()
	end)

	test("leaderboards: DataStores unavailable fall back to this server", function(t)
		local backend = Runtime.newDataStoreBackend()
		backend.unavailable = true
		local rt = boot({ datastores = backend })
		local player = join(rt, "Solo")
		local snap = rt:lastClientMessage(player, "ProfileChanged")[1]
		t.eq(snap.temporary, true, "temporary profile without DataStore access")
		t.ok(snap.stats.matches > 0, "Studio demo stats seeded for review")
		local LeaderboardService = rt:requirePath("ServerScriptService.LobbyServer.Services.LeaderboardService")
		run(function()
			LeaderboardService.refresh()
		end)
		local r = invoke(rt, player, "Leaderboards", { action = "get" })
		t.eq(r.boards[1].source, "STUDIO DEMO DATA", "labelled as demo data")
		local found = false
		for _, entry in r.boards[1].entries do
			if entry.name == "Solo" then
				found = true
			end
		end
		t.ok(found, "the local commander is ranked among the demo entries")
		t.noRuntimeErrors()
	end)

	test("event: challenges, reward track claims, world texts", function(t)
		local rt = boot()
		local player = join(rt, "Wolf")
		local r = invoke(rt, player, "Event", { action = "get" })
		t.ok(r.ok and r.event.title == "IRON WINTER", "Iron Winter active")
		t.eq(r.event.daysRemaining, 23, "23 days remaining")
		t.eq(r.progress.points, 0, "no points yet")
		use(rt, player, "Event", "CURRENT")
		use(rt, player, "UnitInspect", "T80BV_ZIMA")
		r = invoke(rt, player, "Event", { action = "get" })
		t.eq(r.progress.points, 100, "briefing + inspection = 100 points")
		local credits = profileOf(rt, player).credits
		t.ok(invoke(rt, player, "Event", { action = "claim", tier = 1 }).ok, "tier 1 claimed")
		t.eq(profileOf(rt, player).credits, credits + 500, "+500 credits")
		t.eq(invoke(rt, player, "Event", { action = "claim", tier = 1 }).error, "ALREADY_CLAIMED", "tier claimed once")
		t.eq(invoke(rt, player, "Event", { action = "claim", tier = 2 }).error, "NOT_ENOUGH_POINTS", "tier 2 locked")
		t.eq(invoke(rt, player, "Event", { action = "claim", tier = 99 }).error, "BAD_TIER", "bad tier")
		local billboard
		for _, d in world(rt):GetDescendants() do
			if d.Name == "EventBillboard" then
				billboard = d
			end
		end
		t.eq(label(billboard, "Days"), "AVAILABLE: 23 DAYS", "billboard shows days left")
		t.noRuntimeErrors()
	end)

	test("event: rotation to standby swaps the Event Area dressing", function(t)
		local Events = Runtime.new({ place = "build/lobby.rbxl" }):requirePath("ReplicatedStorage.Lobby.Config.Events")
		local ending = Events.Schedule[1].EndsAt
		local rt = boot({ epoch = ending - 30 })
		local zone = world(rt).Zones.EventArea
		t.eq(zone:GetAttribute("EventId"), "IRON_WINTER", "Iron Winter dressing at start")
		local hadZima = zone.Dressing:FindFirstChild("Showcase_T80BV_ZIMA") ~= nil
		t.ok(hadZima, "limited unit on display")
		Scheduler.advance(95)
		t.eq(zone:GetAttribute("EventId"), Events.Standby.Id, "rotated to standby after the end date")
		t.ok(zone.Dressing:FindFirstChild("Showcase_T80BV_ZIMA") == nil, "limited unit removed")
		t.noRuntimeErrors()
	end)

	test("garage showroom: unlock with credits and level, paint schemes, views, proximity", function(t)
		local rt = boot()
		local player = join(rt, "Tanker")
		local r = invoke(rt, player, "Garage", { action = "collection" })
		t.ok(r.ok and #r.units == 15, "collection lists 15 units")
		rt:moveCharacter(player, Vector3.new(0, 3, 30))
		t.eq(
			invoke(rt, player, "Garage", { action = "unlock", unit = "BRDM2" }).error,
			"NOT_AT_GARAGE",
			"must be in the garage"
		)
		t.eq(
			invoke(rt, player, "Garage", { action = "view", unit = "T72" }).error,
			"NOT_AT_GARAGE",
			"vehicles are viewed in the showroom"
		)
		stand(rt, player, "Showroom", "SHOWROOM")
		t.eq(invoke(rt, player, "Garage", { action = "unlock", unit = "BRDM2" }).error, "LEVEL_TOO_LOW", "level gate")
		t.eq(invoke(rt, player, "Garage", { action = "view", unit = "NOPE" }).error, "UNKNOWN_UNIT", "unknown unit")
		t.ok(invoke(rt, player, "Garage", { action = "view", unit = "T72" }).ok, "view at the showroom console")
		t.ok(invoke(rt, player, "Garage", { action = "view", unit = "T72" }).ok, "repeat view accepted")
		local counts = profileOf(rt, player).lobby.interactions
		t.eq(counts["UnitInspect:T72"], 1, "a showroom view counts as one inspection (repeat within cooldown ignored)")
		local CommanderService = rt:requirePath("ServerScriptService.LobbyServer.Services.CommanderService")
		CommanderService.update(player, function(p)
			p.xp = 1000
			p.credits = 1000
			return true
		end)
		r = invoke(rt, player, "Garage", { action = "unlock", unit = "BRDM2" })
		t.ok(r.ok, "BRDM-2 unlocked")
		t.eq(profileOf(rt, player).credits, 200, "800 credits spent")
		t.eq(
			invoke(rt, player, "Garage", { action = "unlock", unit = "T80BV_ZIMA" }).error,
			"EVENT_ONLY",
			"event unit not for sale"
		)
		t.eq(
			invoke(rt, player, "Garage", { action = "buyCamo", camo = "URBAN" }).error,
			"NOT_ENOUGH_CREDITS",
			"camo too expensive"
		)
		t.eq(
			invoke(rt, player, "Garage", { action = "setCamo", unit = "BRDM2", camo = "URBAN" }).error,
			"CAMO_LOCKED",
			"unowned camo"
		)
		CommanderService.update(player, function(p)
			p.credits = 2000
			return true
		end)
		t.ok(invoke(rt, player, "Garage", { action = "buyCamo", camo = "URBAN" }).ok, "urban camo bought")
		r = invoke(rt, player, "Garage", { action = "setCamo", unit = "BRDM2", camo = "URBAN" })
		t.ok(r.ok and r.profile.unitCamos.BRDM2 == "URBAN", "camo applied to the unit")
		t.eq(
			invoke(rt, player, "Garage", { action = "setCamo", unit = "LEOPARD_2", camo = "URBAN" }).error,
			"UNIT_LOCKED",
			"locked unit"
		)
		t.noRuntimeErrors()
	end)

	test("persistence: saved on leave, restored on rejoin, merges with match servers", function(t)
		local backend = Runtime.newDataStoreBackend()
		local rt = boot({ datastores = backend })
		local player = join(rt, "Keeper", 4242)
		local CommanderService = rt:requirePath("ServerScriptService.LobbyServer.Services.CommanderService")
		local DataService = rt:requirePath("ServerScriptService.LobbyServer.Services.DataService")
		CommanderService.update(player, function(p)
			p.credits += 250
			p.faction = "PACT"
			return true
		end)
		t.ok(
			run(function()
				return DataService.save(player)
			end),
			"autosave writes the profile"
		)
		-- meanwhile a match server wrote more victories and credits ...
		local store = backend.dataStore("ColdWarLobby_Commanders_v1")
		run(function()
			store:UpdateAsync("commander_4242", function(old)
				old.stats.victories = 7
				old.credits += 100
				return old
			end)
		end)
		-- ... and the commander spent/earned more in the lobby
		CommanderService.update(player, function(p)
			p.credits += 30
			return true
		end)
		rt:removePlayer(player)
		Scheduler.advance(2)
		local stored = run(function()
			return store:GetAsync("commander_4242")
		end)
		t.eq(stored.credits, 500 + 250 + 100 + 30, "credit changes merged as deltas (lobby + match server)")
		t.eq(stored.stats.victories, 7, "match server stats kept")
		t.eq(stored.faction, "PACT", "lobby changes saved")
		-- rejoin on a fresh server
		local rt2 = boot({ datastores = backend })
		local again = join(rt2, "Keeper", 4242)
		local snap = rt2:lastClientMessage(again, "ProfileChanged")[1]
		t.eq(snap.credits, 880, "credits restored")
		t.eq(snap.faction, "PACT", "faction restored")
		t.noRuntimeErrors()
	end)

	test("lobby status: pylons and the deployment board show live numbers", function(t)
		local rt = boot()
		local a = join(rt, "One")
		join(rt, "Two")
		stand(rt, a, "Matchmaking", "4V4")
		invoke(rt, a, "Matchmaking", { action = "join", mode = "4V4" })
		Scheduler.advance(2.5)
		local pylon, board
		for _, d in world(rt):GetDescendants() do
			if d:IsA("SurfaceGui") and d.Name == "StatusScreenFront" then
				pylon = d
			elseif d:IsA("SurfaceGui") and d.Name == "DeploymentBoard" then
				board = d
			end
		end
		t.eq(label(pylon, "OnlineValue"), "2", "commanders online")
		t.eq(label(pylon, "QueuedValue"), "1", "in matchmaking")
		t.eq(label(pylon, "OperationValue"), "IRON WINTER", "current operation")
		t.eq(label(pylon, "Clock"), "1200Z", "zulu clock (12:00 UTC test epoch)")
		t.eq(label(board, "Count_4V4"), "1 WAITING", "deployment board count")
		t.eq(label(board, "Count_1V1"), "STANDBY", "idle mode")
		t.noRuntimeErrors()
	end)
end
