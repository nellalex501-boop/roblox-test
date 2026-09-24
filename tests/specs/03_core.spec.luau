--!nocheck
-- PHASE 3 — core logic unit tests: profiles, trackers, missions, queues.

local Runtime = require("../harness/Runtime")

local NOW = Runtime.DEFAULT_EPOCH -- 2026-09-24 12:00 UTC

return function(test)
	local rt = Runtime.new({ place = "build/lobby.rbxl" })
	local ProfileSchema = rt:requirePath("ServerScriptService.LobbyServer.Core.ProfileSchema")
	local Trackers = rt:requirePath("ServerScriptService.LobbyServer.Core.Trackers")
	local MissionLogic = rt:requirePath("ServerScriptService.LobbyServer.Core.MissionLogic")
	local QueueLogic = rt:requirePath("ServerScriptService.LobbyServer.Core.QueueLogic")
	local Units = rt:requirePath("ReplicatedStorage.Lobby.Config.Units")
	local Progression = rt:requirePath("ReplicatedStorage.Lobby.Config.Progression")
	local Events = rt:requirePath("ReplicatedStorage.Lobby.Config.Events")

	test("profile: defaults, reconcile, snapshot, DataStore-safe", function(t)
		local p = ProfileSchema.default(NOW)
		t.eq(p.credits, 500, "starting credits")
		t.eq(p.faction, "NATO", "default faction")
		t.ok(p.unitsUnlocked.M1_ABRAMS and p.unitsUnlocked.T72, "default units unlocked")
		t.ok(not p.unitsUnlocked.LEOPARD_2, "locked units stay locked")
		-- stored data from an older/partial profile is completed
		local stored = { xp = 450, credits = "oops", stats = { victories = 3 }, faction = "MARS" }
		local r = ProfileSchema.reconcile(stored, NOW)
		t.eq(r.xp, 450, "keeps stored xp")
		t.eq(r.credits, 500, "fixes mistyped credits")
		t.eq(r.stats.victories, 3, "keeps nested stat")
		t.eq(r.stats.matches, 0, "fills missing nested stat")
		t.eq(r.faction, "NATO", "invalid faction reset")
		t.ok(type(r.missions.baseline.stats) == "table", "fills nested records")
		local snap = ProfileSchema.snapshot(r, 1, "Tester", false)
		t.eq(snap.level, Progression.levelForXp(450), "snapshot level")
		t.ok(#snap.achievements == #Progression.Achievements, "achievements listed")
		-- must survive a JSON round trip (DataStore rules) and remote rules
		local store = rt.datastores.dataStore("SchemaTest")
		local ok
		rt.globals.task.spawn(function()
			ok = pcall(store.SetAsync, store, "k", r)
		end)
		Runtime.Scheduler.advance(1)
		t.ok(ok, "profile is DataStore-serialisable")
		t.ok(pcall(Runtime.remoteCopy, snap, "snapshot"), "snapshot obeys remote serialisation rules")
	end)

	test("progression: levels, ranks per faction", function(t)
		t.eq(Progression.levelForXp(0), 1, "level 1 at 0 xp")
		t.eq(Progression.levelForXp(100), 2, "level 2 at 100 xp")
		t.eq(Progression.levelForXp(99), 1, "just below level 2")
		t.eq(Progression.levelForXp(4500), 10, "level 10 at 4500 xp")
		local level, into, need = Progression.levelProgress(150)
		t.ok(level == 2 and into == 50 and need == 200, "progress within level 2")
		t.eq(Progression.rankName(8, "NATO"), "SERGEANT", "NATO rank")
		t.eq(Progression.rankName(8, "PACT"), "SERZHANT", "Warsaw Pact rank")
	end)

	test("trackers: stat, distinct, interaction since baseline", function(t)
		local p = ProfileSchema.default(NOW)
		p.stats.sectorsCaptured = 7
		p.stats.mapsPlayed = { DAM = 1 }
		local trackers = {
			{ Type = "Stat", Stat = "sectorsCaptured" },
			{ Type = "Distinct", Stat = "mapsPlayed" },
			{ Type = "Interaction", Kind = "UnitInspect", DistinctIds = true },
			{ Type = "Interaction", Kind = "UnitInspect", Id = "T80BV_ZIMA" },
		}
		local base = Trackers.baseline(p, trackers)
		p.stats.sectorsCaptured = 12
		p.stats.mapsPlayed = { DAM = 3, HIGHWAY = 1, AIRBASE = 1 }
		Trackers.recordInteraction(p, "UnitInspect", "T72")
		Trackers.recordInteraction(p, "UnitInspect", "T72")
		Trackers.recordInteraction(p, "UnitInspect", "T80BV_ZIMA")
		t.eq(Trackers.progress(p, trackers[1], base), 5, "stat delta")
		t.eq(Trackers.progress(p, trackers[2], base), 2, "new distinct maps only")
		t.eq(Trackers.progress(p, trackers[3], base), 2, "distinct vehicles inspected")
		t.eq(Trackers.progress(p, trackers[4], base), 1, "specific id interaction")
	end)

	test("missions: daily reset, progress, claim once, orientation persists", function(t)
		local p = ProfileSchema.default(NOW)
		p.stats.victories = 10
		local list = MissionLogic.list(p, NOW)
		t.eq(#list, 10, "ten missions listed")
		t.eq(p.missions.period, "2026-09-24", "period started")
		local ok, err = MissionLogic.claim(p, "WIN_3", NOW)
		t.ok(not ok and err == "NOT_COMPLETE", "old wins do not count toward today")
		p.stats.victories = 13
		local credits = p.credits
		ok = MissionLogic.claim(p, "WIN_3", NOW)
		t.ok(ok, "claim after 3 new wins")
		t.eq(p.credits, credits + 200, "credits rewarded")
		ok, err = MissionLogic.claim(p, "WIN_3", NOW)
		t.ok(not ok and err == "ALREADY_CLAIMED", "cannot claim twice")
		-- orientation: interaction driven, lifetime
		Trackers.recordInteraction(p, "Profile", "PROFILE")
		ok = MissionLogic.claim(p, "ORI_PROFILE", NOW)
		t.ok(ok, "orientation mission claimed")
		-- next day: daily reset, orientation claim kept
		local tomorrow = NOW + 86400
		local reset = MissionLogic.ensurePeriod(p, tomorrow)
		t.ok(reset, "new day resets daily missions")
		t.ok(not p.missions.claimed.WIN_3, "daily claim cleared")
		t.ok(p.missions.claimed.ORI_PROFILE, "orientation claim kept")
		local progress = MissionLogic.progress(p, "WIN_3")
		t.eq(progress, 0, "daily progress restarts")
		t.ok(MissionLogic.secondsToReset(NOW) == 12 * 3600, "12 h to reset at noon UTC")
	end)

	test("queue: fixed modes form matches at the right size", function(t)
		local q = QueueLogic.new(1)
		for i = 1, 3 do
			q:join(i, "2V2", NOW, 1000)
		end
		t.eq(#q:tick(NOW), 0, "3/4 players: no 2v2 yet")
		q:join(4, "2V2", NOW, 1000)
		local matches = q:tick(NOW)
		t.eq(#matches, 1, "4th player forms a 2v2")
		t.eq(#matches[1].players, 4, "4 players in the match")
		t.eq(#matches[1].teams[1], 2, "team A size")
		t.eq(#matches[1].teams[2], 2, "team B size")
		t.eq(q:counts()["2V2"], 0, "queue emptied")
		for i = 10, 17 do
			q:join(i, "4V4", NOW, 1000)
		end
		matches = q:tick(NOW)
		t.ok(#matches == 1 and matches[1].mode == "4V4" and #matches[1].players == 8, "8 players form a 4v4")
		q:join(30, "1V1", NOW)
		q:join(31, "1V1", NOW)
		matches = q:tick(NOW)
		t.ok(#matches == 1 and matches[1].mode == "1V1", "1v1 formed")
	end)

	test("queue: quick match tops up waiting queues, then pairs itself", function(t)
		local q = QueueLogic.new(2)
		q:join(1, "2V2", NOW)
		q:join(2, "2V2", NOW)
		q:join(3, "2V2", NOW)
		q:join(4, "QUICK", NOW)
		local matches = q:tick(NOW)
		t.ok(#matches == 1 and matches[1].mode == "2V2", "quick player completes the 2v2")
		t.ok(table.find(matches[1].players, 4) ~= nil, "quick player included")
		q:join(5, "QUICK", NOW)
		t.eq(#q:tick(NOW), 0, "a single quick player waits")
		q:join(6, "QUICK", NOW)
		matches = q:tick(NOW)
		t.ok(#matches == 1 and matches[1].mode == "1V1", "two quick players get a 1v1")
		for i = 40, 43 do
			q:join(i, "QUICK", NOW)
		end
		matches = q:tick(NOW)
		t.ok(#matches == 1 and matches[1].mode == "2V2", "four quick players get a 2v2")
	end)

	test("queue: switching queues, leaving, balanced teams, map vote", function(t)
		local q = QueueLogic.new(3)
		q:join(1, "1V1", NOW)
		q:join(1, "2V2", NOW)
		t.eq(q:modeOf(1), "2V2", "joining another queue moves the player")
		t.eq(q:counts()["1V1"], 0, "not in two queues at once")
		t.ok(q:leave(1), "leave queue")
		t.eq(q:modeOf(1), nil, "left")
		t.ok(not q:join(1, "BANANA", NOW), "invalid mode rejected")
		local teams = QueueLogic.balanceTeams({ 1, 2, 3, 4 }, { [1] = 1400, [2] = 1300, [3] = 1200, [4] = 1100 })
		local sum = function(team, r)
			local s = 0
			for _, id in team do
				s += r[id]
			end
			return s
		end
		local ratings = { [1] = 1400, [2] = 1300, [3] = 1200, [4] = 1100 }
		t.eq(sum(teams[1], ratings), sum(teams[2], ratings), "snake draft balances 4 ratings")
		local map = QueueLogic.pickMap("2V2", { "DAM", "HIGHWAY", "DAM" }, rt.globals.Random.new(1))
		t.eq(map, "DAM", "majority preference wins")
	end)

	test("private lobbies: create, join by code, capacity, options, start", function(t)
		local q = QueueLogic.new(4)
		local lobby = q:createPrivate(1, "1V1", "AB12C", NOW)
		t.ok(lobby ~= nil and lobby.host == 1, "lobby created")
		local _, err = q:startPrivate(1)
		t.eq(err, "NEED_TWO_PLAYERS", "cannot start alone")
		t.ok(q:joinPrivate(2, "ab12c") ~= nil, "join with lower-case code")
		local _, full = q:joinPrivate(3, "AB12C")
		t.eq(full, "LOBBY_FULL", "1v1 lobby holds two")
		t.ok(q:setPrivateOptions(1, "2V2", "CATHEDRAL"), "host changes size and map")
		t.ok(q:joinPrivate(3, "AB12C") ~= nil, "now room for more")
		local ok, notHost = q:setPrivateOptions(2, nil, "DAM")
		t.ok(not ok and notHost == "NOT_HOST", "only the host sets options")
		q:join(3, "1V1", NOW)
		t.eq(q:modeOf(3), nil, "lobby members cannot queue")
		local match = q:startPrivate(1)
		t.ok(
			match ~= nil and match.private and match.map == "CATHEDRAL" and #match.players == 3,
			"private match starts with chosen map"
		)
		t.eq(q:lobbyOf(1), nil, "lobby closed after start")
		-- host leaving hands the lobby over
		q:createPrivate(10, "4V4", "ZZ999", NOW)
		q:joinPrivate(11, "ZZ999")
		q:leavePrivate(10)
		t.eq(q:lobbyOf(11).host, 11, "host migrates")
	end)

	test("events: active event and days remaining", function(t)
		local event = Events.current(NOW)
		t.eq(event.Id, "IRON_WINTER", "Iron Winter active on 2026-09-24")
		t.eq(Events.daysRemaining(event, NOW), 23, "23 days remaining (as in the brief)")
		t.eq(Events.current(event.EndsAt + 1).Id, "STANDBY", "standby after the event ends")
		local total = 0
		for _, c in event.Challenges do
			total += c.Points
		end
		t.ge(total, event.Rewards[#event.Rewards].Points, "all reward tiers reachable")
		for _, r in event.Rewards do
			if r.Kind == "Unit" then
				t.ok(Units.List[r.Value] ~= nil, "reward unit exists")
			end
		end
	end)
end
