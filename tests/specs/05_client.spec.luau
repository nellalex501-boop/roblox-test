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

local Bridge = require("../lib/Bridge")
local GuiExport = require("../lib/GuiExport")
local Runtime = require("../harness/Runtime")

local Scheduler = Runtime.Scheduler
local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local Enum = roblox.Enum

local screens = Bridge.screens
local run = Bridge.run
local boot = Bridge.boot

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

	test("every station opens its panel and tab; X and walking away close it", function(t)
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
			ctx.key(Enum.KeyCode.X)
			t.eq(WindowManager.current(), nil, "X closes " .. def.Panel)
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
		ctx.key(Enum.KeyCode.X)
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
		ctx.click("Tab_THEATER")
		t.ok(ctx.find("TheaterCanvas") ~= nil, "theatre map drawn")
		ctx.capture("maps-theater", BG.back)
		ctx.key(Enum.KeyCode.X)
		ctx.use("TheaterMap")
		t.eq(ctx.module("UI.WindowManager").shell("Maps").tab, "THEATER", "plaza table opens the theatre tab")
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
		ctx.key(Enum.KeyCode.X)
		ctx.use("Statistics")
		t.eq(ctx.module("UI.WindowManager").shell("Profile").tab, "STATISTICS", "records room opens statistics")
		t.noRuntimeErrors()
	end)

	test("garage showroom: picked vehicle on the turntable, camera clear of walls, unlock, paint", function(t)
		local ctx = boot()
		local CommanderService = ctx.serverModule("Services.CommanderService")
		CommanderService.update(ctx.serverPlayer, function(p)
			p.xp = 1200
			p.credits = 5000
			return true
		end)
		Scheduler.advance(0.5)
		local Showroom = ctx.module("Controllers.ShowroomController")
		local CameraController = ctx.module("Controllers.CameraController")
		local Units = ctx.client:requirePath("ReplicatedStorage.Lobby.Config.Units")
		local Layout = ctx.client:requirePath("ReplicatedStorage.Lobby.Config.Layout")
		t.ok(Showroom.stage() ~= nil, "turntable found")
		t.eq(Showroom.model() and Showroom.model():GetAttribute("UnitId"), "M1_ABRAMS", "default vehicle on show")
		local featuredLeft = false
		for _, d in ctx.client.workspace:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("ShowroomFeatured") then
				featuredLeft = true
			end
		end
		t.ok(not featuredLeft, "the server's featured vehicle is hidden for this player")
		ctx.use("Showroom")
		t.eq(ctx.current(), "Showroom", "showroom viewer open")
		local camera = ctx.client.workspace.CurrentCamera
		t.eq(camera.CameraType, Enum.CameraType.Scriptable, "camera focuses on the vehicle")
		t.ok(ctx.findVisible("Unit_T72") ~= nil and ctx.findVisible("Unit_LEOPARD_2") ~= nil, "every vehicle listed")
		t.ok(ctx.findVisible("Close") ~= nil, "clickable close button")
		ctx.capture("garage-showroom", BG.side)
		ctx.click("Unit_M2_BRADLEY")
		t.eq(Showroom.current(), "M2_BRADLEY", "picked vehicle")
		local model = Showroom.model()
		t.eq(model and model:GetAttribute("UnitId"), "M2_BRADLEY", "picked vehicle is on the turntable")
		t.eq(CameraController.state() and CameraController.state().model, model, "camera follows the new vehicle")
		t.eq(ctx.text("VehicleName"), "M2 BRADLEY", "name plate")
		-- the camera stays inside the hall with a clear view, at every angle
		-- and fully zoomed out (walls shorten the distance)
		local frame = Layout.frame(Layout.Zones.Garage)
		local halfW, depth = Layout.Zones.Garage.Width / 2, Layout.Zones.Garage.Depth
		local inside, clear = true, true
		CameraController.zoom(-20)
		for _ = 1, 12 do
			CameraController.turn(Vector2.new(260, 0))
			ctx.client:step(0.5)
			local eye = camera.CFrame.Position
			local localEye = frame:PointToObjectSpace(eye)
			if math.abs(localEye.X) > halfW - 1 or localEye.Z > -1 or localEye.Z < -depth + 1 or localEye.Y > 24 then
				inside = false
			end
			local center = CameraController.state().center
			local params = {
				FilterType = Enum.RaycastFilterType.Exclude,
				FilterDescendantsInstances = { model, ctx.player.Character },
			}
			if ctx.client.workspace:Raycast(center, eye - center, params) then
				clear = false
			end
		end
		t.ok(inside, "camera never leaves the Garage hall")
		t.ok(clear, "nothing comes between the camera and the vehicle")
		-- unlock
		t.ok(ctx.findVisible("Unlock") ~= nil, "unlock offered")
		ctx.click("Unlock")
		t.ok(ctx.profile().unitsUnlocked.M2_BRADLEY, "unit unlocked on the server")
		t.eq(ctx.profile().credits, 3500, "credits spent")
		-- paint: preview on the vehicle, buy, apply
		ctx.click("Tab_PAINT")
		ctx.click("Camo_WOODLAND")
		local base
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Paint") == "Base" then
				base = d
			end
		end
		t.eq(base and base.Color, Units.Camos.List.WOODLAND.Colors[1], "scheme previewed on the vehicle")
		ctx.click("BuyCamo")
		t.ok(ctx.profile().camosOwned.WOODLAND, "camo bought")
		ctx.click("ApplyCamo")
		t.eq(ctx.profile().unitCamos.M2_BRADLEY, "WOODLAND", "camo applied to the vehicle on show")
		ctx.capture("garage-paint", BG.side)
		-- viewing vehicles counts for the inspect mission
		ctx.click("Tab_INFO")
		ctx.click("Unit_T72")
		ctx.click("Unit_BMP2")
		Scheduler.advance(1)
		local distinct = 0
		for _ in ctx.profile().lobby.distinct.UnitInspect or {} do
			distinct += 1
		end
		t.ge(distinct, 3, "showroom views count as inspecting different vehicles")
		ctx.key(Enum.KeyCode.X)
		t.eq(ctx.current(), nil, "X closes the showroom")
		t.eq(camera.CameraType, Enum.CameraType.Custom, "camera handed back")
		-- the event's limited unit keeps its inspection sheet
		ctx.use("UnitInspect", "T80BV_ZIMA")
		t.eq(ctx.current(), "Inspect", "event unit inspection sheet")
		t.eq(camera.CameraType, Enum.CameraType.Scriptable, "camera orbits the event unit")
		ctx.capture("event-inspect", BG.side)
		ctx.key(Enum.KeyCode.X)
		t.noRuntimeErrors()
	end)

	test("missions UI: claim from the board, board ticks personalised", function(t)
		local ctx = boot()
		ctx.use("Matchmaking", "QUICK")
		ctx.key(Enum.KeyCode.X)
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
		ctx.key(Enum.KeyCode.X)
		ctx.use("Event", "CURRENT")
		ctx.use("UnitInspect", "T80BV_ZIMA")
		ctx.key(Enum.KeyCode.X)
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
		ctx.key(Enum.KeyCode.X)
		ctx.capture("phone-hud")
		t.noRuntimeErrors()
	end)

	test("export UI previews", function(t)
		fs.writeDir("build/ui")
		fs.writeFile("build/ui/screens.json", serde.encode("json", screens))
		t.ge(#screens, 20, "screens exported")
	end)
end
