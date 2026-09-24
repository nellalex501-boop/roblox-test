--!nocheck
-- PHASE 3 — client integration: a real server runtime (LobbyServer) and a
-- client runtime (LobbyClient) bridged through the remotes. The client
-- world is built with the same deterministic builder (standing in for
-- replication). Tests drive the UI like a player: trigger prompts, press
-- buttons and keys, walk around; results are checked on both sides.
-- Also exports each screen for tools/render/screens.mjs previews.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local GuiExport = require("../lib/GuiExport")
local Runtime = require("../harness/Runtime")

local Scheduler = Runtime.Scheduler
local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local screens = {}

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

local function bootServer(options)
	local server = Runtime.new({ place = "build/lobby.rbxl", studio = true, epoch = options.epoch })
	server:runScript(server:find("ServerScriptService.LobbyServer"))
	Scheduler.advance(0.5)
	return server
end

-- Server + one bridged client. Returns a context table.
local function boot(options)
	options = options or {}
	local server = bootServer(options)
	local name = options.name or "Pilot"
	local userId = options.userId or 5001
	local serverPlayer = server:addPlayer(name, userId)
	server:spawnCharacter(serverPlayer)
	Scheduler.advance(1)
	local client = Runtime.new({
		place = "build/lobby.rbxl",
		context = "client",
		touch = options.touch,
		viewport = options.viewport or Vector2.new(1280, 720),
		epoch = options.epoch,
	})
	-- "replicate" the world, remotes and preview models
	local Builder = client:requirePath("ServerScriptService.LobbyServer.World.Builder")
	Builder.Build({ Parent = client.workspace, SkipLighting = true })
	local lobby = client:find("ReplicatedStorage.Lobby")
	local remotes = roblox.Instance.new("Folder")
	remotes.Name = "Remotes"
	for _, remote in server:find("ReplicatedStorage.Lobby.Remotes"):GetChildren() do
		local copy = roblox.Instance.new(remote.ClassName)
		copy.Name = remote.Name
		copy.Parent = remotes
	end
	remotes.Parent = lobby
	client:requirePath("ServerScriptService.LobbyServer.Services.GarageService").buildPreviews()
	local clientPlayer = client:setLocalPlayer(name, userId)
	client:spawnCharacter(clientPlayer, serverPlayer.Character.HumanoidRootPart.CFrame)
	server:bridgeClient(client, serverPlayer)
	client:runScript(client:find("StarterPlayer.StarterPlayerScripts.LobbyClient"))
	Scheduler.advance(2)
	local ctx = { server = server, client = client, serverPlayer = serverPlayer, player = clientPlayer }
	function ctx.module(path)
		return client:requirePath("StarterPlayer.StarterPlayerScripts.LobbyClient." .. path)
	end
	function ctx.serverModule(path)
		return server:requirePath("ServerScriptService.LobbyServer." .. path)
	end
	function ctx.profile()
		return ctx.serverModule("Services.CommanderService").get(serverPlayer)
	end
	function ctx.move(position)
		client:moveCharacter(clientPlayer, position)
		server:moveCharacter(serverPlayer, position)
	end
	function ctx.gui()
		return clientPlayer.PlayerGui:FindFirstChild("LobbyUI")
	end
	function ctx.find(name, root)
		local found = (root or ctx.gui()):FindFirstChild(name, true)
		return found
	end
	function ctx.findVisible(name)
		for _, d in ctx.gui():GetDescendants() do
			if d.Name == name then
				local visible = true
				local node = d
				while node and node:IsA("GuiObject") do
					if not node.Visible then
						visible = false
					end
					node = node.Parent
				end
				if visible then
					return d
				end
			end
		end
		return nil
	end
	function ctx.click(name)
		local button = ctx.findVisible(name)
		assert(button, "no visible button " .. name)
		run(function()
			Runtime.signalFor(button, "Activated"):Fire()
		end)
		Scheduler.advance(0.5)
		return button
	end
	function ctx.key(keyCode)
		local uis = client.game:GetService("UserInputService")
		Runtime.signalFor(uis, "InputBegan")
			:Fire({ KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard }, false)
		Scheduler.advance(0.4)
	end
	function ctx.prompt(kind, id)
		for _, d in client.workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "LobbyPrompt" then
				local part = d.Parent
				if
					part:GetAttribute("InteractionKind") == kind
					and (id == nil or part:GetAttribute("InteractionId") == id)
				then
					return d
				end
			end
		end
		error(("no client prompt %s %s"):format(kind, tostring(id)))
	end
	-- walk to a station and press its prompt
	function ctx.use(kind, id)
		local prompt = ctx.prompt(kind, id)
		ctx.move(prompt.Parent.CFrame.Position)
		client:triggerPrompt(prompt, clientPlayer)
		Scheduler.advance(1)
		return prompt
	end
	function ctx.current()
		return ctx.module("UI.WindowManager").current()
	end
	function ctx.capture(screenName, background)
		table.insert(screens, {
			name = screenName,
			w = math.floor(client.viewport.X),
			h = math.floor(client.viewport.Y),
			background = background,
			tree = GuiExport.node(ctx.gui()),
		})
	end
	function ctx.text(name)
		local label = ctx.findVisible(name)
		return label and label.Text
	end
	return ctx
end

local BG = {
	plaza = "docs/previews/phase2-spawn.png",
	side = "docs/previews/phase2-spawn-left.png",
	back = "docs/previews/phase2-spawn-back.png",
}

return function(test)
	test("client boots: lobby UI, HUD commander card, status", function(t)
		local ctx = boot()
		local gui = ctx.gui()
		t.ok(gui ~= nil, "LobbyUI ScreenGui created")
		t.eq(gui and gui.ResetOnSpawn, false, "UI survives respawn")
		t.eq(ctx.text("Credits"), "500 CR", "HUD shows credits from the server profile")
		t.eq(ctx.text("Rank"), "PVT", "HUD shows rank")
		local State = ctx.module("State")
		t.ok(State.status ~= nil, "lobby status received")
		t.ok(State.event ~= nil and State.event.info.title == "IRON WINTER", "event info loaded")
		t.ok(State.missions ~= nil and #State.missions.missions == 10, "missions loaded")
		local scale = gui.Root.UIScale.Scale
		t.ok(scale > 1 and scale < 1.2, ("UI scale for 1280x720 (%.2f)"):format(scale))
		ctx.capture("hud-plaza", BG.plaza)
		t.noRuntimeErrors()
	end)

	test("custom prompt plate for keyboard, gamepad and touch", function(t)
		local ctx = boot()
		local service = ctx.client.game:GetService("ProximityPromptService")
		local prompt = ctx.prompt("Matchmaking", "QUICK")
		Runtime.signalFor(service, "PromptShown"):Fire(prompt, Enum.ProximityPromptInputType.Keyboard)
		Scheduler.advance(0.2)
		local plate = ctx.player.PlayerGui:FindFirstChild("LobbyPromptPlate")
		t.ok(plate ~= nil, "prompt plate shown")
		t.eq(plate and plate.Adornee, prompt.Parent, "plate adorns the station")
		t.eq(plate and plate:FindFirstChild("Key", true).Text, "E", "keyboard key")
		t.eq(plate and plate:FindFirstChild("Action", true).Text, "JOIN MATCH", "action text")
		t.eq(plate and plate:FindFirstChild("Object", true).Text, "QUICK MATCH TERMINAL", "station name")
		table.insert(screens, {
			name = "prompt-plate",
			w = 280,
			h = 60,
			tree = GuiExport.node(plate),
		})
		Runtime.signalFor(service, "PromptHidden"):Fire(prompt)
		Scheduler.advance(0.1)
		t.ok(ctx.player.PlayerGui:FindFirstChild("LobbyPromptPlate") == nil, "plate removed when hidden")
		Runtime.signalFor(service, "PromptShown"):Fire(prompt, Enum.ProximityPromptInputType.Gamepad)
		Scheduler.advance(0.1)
		plate = ctx.player.PlayerGui:FindFirstChild("LobbyPromptPlate")
		local key = plate:FindFirstChild("Key", true)
		t.ok(key.Text == "X" or key:FindFirstChild("Glyph") ~= nil, "gamepad glyph")
		Runtime.signalFor(service, "PromptHidden"):Fire(prompt)
		Runtime.signalFor(service, "PromptShown"):Fire(prompt, Enum.ProximityPromptInputType.Touch)
		Scheduler.advance(0.1)
		plate = ctx.player.PlayerGui:FindFirstChild("LobbyPromptPlate")
		t.eq(plate:FindFirstChild("Key", true).Text, "TAP", "touch target")
		-- tapping the plate triggers the prompt (opens the panel + server records)
		ctx.move(prompt.Parent.CFrame.Position)
		Runtime.signalFor(plate:FindFirstChild("Key", true), "InputBegan"):Fire({
			UserInputType = Enum.UserInputType.Touch,
		})
		Scheduler.advance(1)
		t.eq(ctx.current(), "Matchmaking", "tapping the plate opens the terminal")
		t.eq(ctx.profile().lobby.interactions.Matchmaking, 1, "server recorded the interaction")
		t.noRuntimeErrors()
	end)

	test("every station opens its panel and tab; Esc and walking away close it", function(t)
		local ctx = boot()
		local Interactions = ctx.module("UI.Kit") and ctx.client:requirePath("ReplicatedStorage.Lobby.Interactions")
		local seen = {}
		for _, d in ctx.client.workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "LobbyPrompt" then
				local kind = d.Parent:GetAttribute("InteractionKind")
				if not seen[kind] then
					seen[kind] = d
				end
			end
		end
		local WindowManager = ctx.module("UI.WindowManager")
		for kind, prompt in seen do
			local def = Interactions.Kinds[kind]
			ctx.move(prompt.Parent.CFrame.Position)
			ctx.client:triggerPrompt(prompt, ctx.player)
			Scheduler.advance(1)
			t.eq(WindowManager.current(), def.Panel, kind .. " opens " .. def.Panel)
			local shell = WindowManager.shell(def.Panel)
			if def.Tab then
				t.eq(shell and shell.tab, def.Tab, kind .. " selects tab " .. def.Tab)
			end
			t.ok(shell and shell.root.Visible, def.Panel .. " visible")
			t.eq(ctx.client.game:GetService("ProximityPromptService").Enabled, false, "prompts hidden while open")
			ctx.key(Enum.KeyCode.Escape)
			t.eq(WindowManager.current(), nil, "Esc closes " .. def.Panel)
		end
		t.eq(ctx.client.game:GetService("ProximityPromptService").Enabled, true, "prompts back after closing")
		-- walking away
		ctx.use("Leaderboard")
		t.eq(WindowManager.current(), "Leaderboards", "opened again")
		ctx.move(Vector3.new(0, 3, 30))
		Scheduler.advance(1)
		t.eq(WindowManager.current(), nil, "walking away closes the panel")
		t.noRuntimeErrors()
	end)

	test("matchmaking terminal UI: join, HUD strip, match found overlay", function(t)
		local ctx = boot()
		ctx.use("Matchmaking", "1V1")
		t.eq(ctx.text("ModeTitle"), "1v1 DUEL", "terminal shows its mode")
		ctx.capture("matchmaking-idle", BG.plaza)
		ctx.click("JoinQueue")
		local State = ctx.module("State")
		t.eq(State.matchmaking.state, "queued", "queued through the UI")
		t.ok(ctx.findVisible("LeaveQueue") ~= nil, "leave button shown")
		Scheduler.advance(2)
		ctx.capture("matchmaking-queued", BG.plaza)
		ctx.key(Enum.KeyCode.Escape)
		local strip = ctx.find("QueueStrip")
		t.eq(strip.Visible, true, "HUD queue strip visible after closing the panel")
		t.ok(ctx.text("Text"):find("1v1 DUEL") ~= nil, "strip names the mode")
		ctx.capture("hud-queued", BG.side)
		-- another commander joins at the terminal on the server
		local rival = ctx.server:addPlayer("Rival", 6001)
		ctx.server:spawnCharacter(rival)
		Scheduler.advance(1)
		local terminal = ctx.serverModule("Services.InteractionService")
		local _ = terminal
		for _, d in ctx.server.workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Parent:GetAttribute("InteractionId") == "1V1" then
				ctx.server:moveCharacter(rival, d.Parent.CFrame.Position)
			end
		end
		run(function()
			return ctx.server:invoke(rival, "Matchmaking", { action = "join", mode = "1V1" })
		end)
		Scheduler.advance(1.5)
		local overlay = ctx.find("MatchOverlay")
		t.eq(overlay.Visible, true, "match overlay shown")
		t.eq(ctx.text("Title"), "MATCH FOUND", "overlay title")
		Scheduler.advance(0.3)
		local countdown = overlay:FindFirstChild("Countdown").Text
		t.ok(
			countdown == "DEPLOYING IN 4" or countdown == "DEPLOYING IN 5",
			"countdown from the server deadline: " .. countdown
		)
		ctx.capture("match-found", BG.side)
		Scheduler.advance(6)
		t.eq(State.matchmaking.state, "simulated", "deployment simulated")
		t.ok(
			overlay.Visible and overlay:FindFirstChild("Countdown").Text:find("SIMULATED") ~= nil,
			"overlay explains the simulation"
		)
		Scheduler.advance(6)
		t.eq(overlay.Visible, false, "overlay hidden afterwards")
		t.eq(strip.Visible, false, "strip hidden when idle")
		t.noRuntimeErrors()
	end)

	test("private lobby UI: create with size, code shown, friend joins", function(t)
		local ctx = boot()
		ctx.use("Matchmaking", "PRIVATE")
		ctx.click("Size_1V1")
		ctx.click("CreateLobby")
		local State = ctx.module("State")
		t.eq(State.matchmaking.state, "private", "lobby created from the UI")
		local code = State.matchmaking.lobby.code
		t.eq(ctx.text("AccessCode"), code, "access code displayed")
		local friend = ctx.server:addPlayer("Friend", 6002)
		ctx.server:spawnCharacter(friend)
		Scheduler.advance(1)
		for _, d in ctx.server.workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Parent:GetAttribute("InteractionId") == "PRIVATE" then
				ctx.server:moveCharacter(friend, d.Parent.CFrame.Position)
			end
		end
		run(function()
			return ctx.server:invoke(friend, "Matchmaking", { action = "joinPrivate", code = code })
		end)
		Scheduler.advance(0.5)
		t.eq(#State.matchmaking.lobby.members, 2, "friend appears in the lobby")
		t.ok(ctx.findVisible("StartMatch") ~= nil, "host sees START")
		ctx.capture("private-lobby", BG.plaza)
		ctx.click("NextMap")
		t.ok(State.matchmaking.lobby.map ~= nil, "host cycles the map")
		ctx.click("StartMatch")
		t.eq(State.matchmaking.state, "found", "private match starts")
		t.noRuntimeErrors()
	end)

	test("map room UI: dossier per screen, preferred map saved", function(t)
		local ctx = boot()
		ctx.use("MapInfo", "DAM")
		t.eq(ctx.current(), "Maps", "map panel open")
		t.eq(ctx.text("MapName"), "DAM", "opened on the map of that screen")
		t.ok(ctx.find("MapCanvas") ~= nil, "map preview drawn")
		ctx.capture("maps-dossier", BG.back)
		ctx.click("SetPreferred")
		t.eq(ctx.profile().preferredMap, "DAM", "preferred map saved on the server")
		t.eq(ctx.text("SetPreferred"), "PREFERRED MAP ✓", "button reflects the saved state")
		ctx.click("Tab_THEATRE")
		t.ok(ctx.find("TheaterCanvas") ~= nil, "theatre map drawn")
		ctx.capture("maps-theatre", BG.back)
		ctx.key(Enum.KeyCode.Escape)
		ctx.use("TheaterMap")
		t.eq(ctx.module("UI.WindowManager").shell("Maps").tab, "THEATRE", "plaza table opens the theatre tab")
		t.noRuntimeErrors()
	end)

	test("command HQ UI: dossier, statistics, customise, achievements", function(t)
		local ctx = boot()
		ctx.use("Profile")
		t.eq(ctx.text("Name"), "PILOT", "dossier name")
		ctx.capture("profile-dossier", BG.side)
		ctx.click("Tab_STATISTICS")
		t.ok(ctx.findVisible("Stat_MATCHES") ~= nil, "statistics tiles")
		ctx.capture("profile-statistics", BG.side)
		ctx.click("Tab_CUSTOMIZE")
		ctx.click("Faction_PACT")
		t.eq(ctx.profile().faction, "PACT", "allegiance changed on the server")
		local stripe = ctx.find("CommanderCard"):FindFirstChild("Faction")
		t.eq(stripe.BackgroundColor3, ctx.module("UI.Kit").Colors.Pact, "HUD card shows the new allegiance")
		ctx.capture("profile-customize", BG.side)
		ctx.click("Tab_ACHIEVEMENTS")
		t.ok(ctx.findVisible("Achievement_FIRST_WIN") ~= nil, "achievements listed")
		ctx.capture("profile-achievements", BG.side)
		ctx.key(Enum.KeyCode.Escape)
		ctx.use("Statistics")
		t.eq(ctx.module("UI.WindowManager").shell("Profile").tab, "STATISTICS", "records room opens statistics")
		t.noRuntimeErrors()
	end)

	test("garage UI: inspect sheet with orbit camera, unlock, paint shop", function(t)
		local ctx = boot()
		local CommanderService = ctx.serverModule("Services.CommanderService")
		CommanderService.update(ctx.serverPlayer, function(p)
			p.xp = 1200
			p.credits = 5000
			return true
		end)
		Scheduler.advance(0.5)
		ctx.use("UnitInspect", "M2_BRADLEY")
		t.eq(ctx.current(), "Inspect", "inspection sheet open")
		local camera = ctx.client.workspace.CurrentCamera
		t.eq(camera.CameraType, Enum.CameraType.Scriptable, "camera orbits the vehicle")
		t.ok(ctx.findVisible("Unlock") ~= nil, "unlock offered")
		ctx.capture("garage-inspect", BG.side)
		ctx.click("Unlock")
		t.ok(ctx.profile().unitsUnlocked.M2_BRADLEY, "unit unlocked on the server")
		t.eq(ctx.profile().credits, 3500, "credits spent")
		ctx.key(Enum.KeyCode.Escape)
		t.eq(camera.CameraType, Enum.CameraType.Custom, "camera handed back")
		ctx.use("UnitCollection")
		t.eq(ctx.current(), "Garage", "registry opens the garage panel")
		t.ok(ctx.findVisible("Unit_LEOPARD_2") ~= nil, "collection lists locked units")
		ctx.capture("garage-collection", BG.side)
		ctx.key(Enum.KeyCode.Escape)
		ctx.use("UnitCosmetics")
		t.eq(ctx.module("UI.WindowManager").shell("Garage").tab, "PAINT", "paint shop tab")
		ctx.click("Camo_WOODLAND")
		ctx.click("BuyCamo")
		t.ok(ctx.profile().camosOwned.WOODLAND, "camo bought")
		ctx.click("ApplyCamo")
		t.eq(ctx.profile().unitCamos.M1_ABRAMS, "WOODLAND", "camo applied to the selected unit")
		ctx.capture("garage-paint", BG.side)
		t.noRuntimeErrors()
	end)

	test("missions UI: claim from the board, board ticks personalised", function(t)
		local ctx = boot()
		ctx.use("Matchmaking", "QUICK")
		ctx.key(Enum.KeyCode.Escape)
		Scheduler.advance(1)
		ctx.use("Missions")
		t.eq(ctx.current(), "Missions", "mission board open")
		local row = ctx.find("Mission_ORI_TERMINAL")
		t.ok(row ~= nil, "orientation mission row")
		ctx.capture("missions", BG.back)
		local credits = ctx.profile().credits
		run(function()
			Runtime.signalFor(row:FindFirstChild("Claim"), "Activated"):Fire()
		end)
		Scheduler.advance(1)
		t.eq(ctx.profile().credits, credits + 50, "reward claimed through the UI")
		local label
		for _, d in ctx.client.workspace:GetDescendants() do
			if d:IsA("TextLabel") and d.Name == "Mission_ORI_TERMINAL" then
				label = d
			end
		end
		t.ok(label and label.Text:sub(1, 3) == "[X]", "physical board ticked for this player")
		t.noRuntimeErrors()
	end)

	test("leaderboards UI and event UI", function(t)
		local ctx = boot()
		ctx.use("Leaderboard", "MOST_VICTORIES")
		Scheduler.advance(1)
		t.eq(ctx.module("UI.WindowManager").shell("Leaderboards").tab, "VICTORIES", "board opens its tab")
		t.ok(ctx.text("Mine"):find("YOUR STANDING") ~= nil, "your standing shown")
		t.ok(ctx.find("Row1") ~= nil, "rows drawn")
		ctx.capture("leaderboards", BG.back)
		ctx.key(Enum.KeyCode.Escape)
		ctx.use("Event", "CURRENT")
		ctx.use("UnitInspect", "T80BV_ZIMA")
		ctx.key(Enum.KeyCode.Escape)
		ctx.use("Event", "CURRENT")
		Scheduler.advance(1)
		t.eq(ctx.current(), "Event", "event briefing open")
		t.eq(ctx.text("Days"), "AVAILABLE: 23 DAYS", "days remaining")
		ctx.capture("event", BG.back)
		local credits = ctx.profile().credits
		local tier = ctx.find("Tier1")
		run(function()
			Runtime.signalFor(tier:FindFirstChild("Claim", true), "Activated"):Fire()
		end)
		Scheduler.advance(1)
		t.eq(ctx.profile().credits, credits + 500, "tier 1 reward claimed from the UI")
		t.noRuntimeErrors()
	end)

	test("HUD: zone banner, locator arrows, toasts", function(t)
		local ctx = boot()
		local Hud = ctx.module("UI.Hud.Hud")
		ctx.move(Vector3.new(-110, 3, -10))
		Scheduler.advance(0.5)
		t.eq(ctx.text("Title"), "GARAGE", "zone banner on entering the garage")
		ctx.key(Enum.KeyCode.L)
		Scheduler.advance(0.5)
		local dest = ctx.find("Dest_OperationsCenter")
		t.ok(dest and dest.Distance.Text:find("m") ~= nil, "locator distance")
		t.eq(ctx.find("Dest_Garage").Distance.Text, "HERE", "current zone marked")
		local forward = Vector3.new(0, 0, -1)
		t.eq(Hud.arrowFor(Vector3.zero, Vector3.new(0, 0, -50), forward), "↑", "ahead")
		t.eq(Hud.arrowFor(Vector3.zero, Vector3.new(50, 0, 0), forward), "→", "right")
		t.eq(Hud.arrowFor(Vector3.zero, Vector3.new(-50, 0, 0), forward), "←", "left")
		t.eq(Hud.arrowFor(Vector3.zero, Vector3.new(0, 0, 50), forward), "↓", "behind")
		ctx.capture("hud-locator", BG.side)
		local State = ctx.module("State")
		State.notified:Fire({
			kind = "Reward",
			title = "REWARD RECEIVED",
			text = "+150 CR · +200 XP",
			detail = "Capture 10 sectors",
		})
		Scheduler.advance(0.3)
		t.ok(ctx.find("Toast") ~= nil, "toast shown")
		ctx.capture("hud-toast", BG.side)
		Scheduler.advance(6)
		t.ok(ctx.find("Toast") == nil, "toast dismissed")
		t.noRuntimeErrors()
	end)

	test("phone-size touch screen: scaled UI fits, panels open", function(t)
		local ctx = boot({ touch = true, viewport = Vector2.new(800, 360) })
		local scale = ctx.gui().Root.UIScale.Scale
		t.ok(scale >= 0.5 and scale <= 0.52, ("UI scale on a small phone (%.3f)"):format(scale))
		ctx.use("Matchmaking", "QUICK")
		local WindowManager = ctx.module("UI.WindowManager")
		local shell = WindowManager.shell("Matchmaking")
		local size = shell.root.Size
		t.le(size.X.Offset * scale, 800, "panel width fits")
		t.le(size.Y.Offset * scale + 58, 360, "panel height fits below the top bar")
		ctx.capture("phone-matchmaking")
		ctx.key(Enum.KeyCode.Escape)
		ctx.capture("phone-hud")
		t.noRuntimeErrors()
	end)

	test("export UI previews", function(t)
		fs.writeDir("build/ui")
		fs.writeFile("build/ui/screens.json", serde.encode("json", screens))
		t.ge(#screens, 20, "screens exported")
	end)
end
