--!nocheck
-- PHASE 5 — POLISH: ambient animation, positional sound, the helicopter
-- flyby, UI feedback (credits, promotion, toasts, pressed buttons), code
-- hygiene and client-side performance of the ambient layer.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Bridge = require("../lib/Bridge")
local Runtime = require("../harness/Runtime")

local Scheduler = Runtime.Scheduler
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local function anchors(ctx, role)
	local list = {}
	for _, d in ctx.client.workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("AmbientRole") == role then
			table.insert(list, d)
		end
	end
	return list
end

local function lookFrom(ctx, position)
	ctx.client.workspace.CurrentCamera.CFrame = CFrame.new(position)
end

local function sourceFiles(dir, out)
	out = out or {}
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			sourceFiles(path, out)
		elseif name:match("%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

return function(test)
	test("ambient animation: radar, flags, lamps, CRTs and fire move", function(t)
		local ctx = Bridge.boot()
		local Animator = ctx.module("Ambient.AmbientAnimator")
		local counts = Animator.counts()
		t.ge(counts.radars, 1, "radar tracked")
		t.ge(counts.flags, 8, "flags tracked")
		t.ge(counts.blinkers, 10, "equipment / obstruction lamps tracked")
		t.ge(counts.screens, 5, "CRT screens tracked")
		t.ge(counts.fires, 2, "fires tracked (courtyard barrel, event brazier)")
		lookFrom(ctx, Vector3.new(0, 20, 30))
		local radar = anchors(ctx, "RadarSpin")[1]
		local model = radar.Parent
		local before = model:GetPivot()
		local flagPart = anchors(ctx, "Flag")[1]
		local tip = flagPart.Parent:FindFirstChild("FlagSegment3")
		local tipBefore = tip.CFrame
		local lamp
		for _, part in anchors(ctx, "BlinkFast") do
			lamp = part
		end
		local fire = anchors(ctx, "Fire")[1]:FindFirstChildOfClass("PointLight")
		local colors, brightness, dipped = {}, {}, false
		for _ = 1, 240 do
			ctx.client:step(1 / 30)
			colors[tostring(lamp.Color)] = true
			brightness[string.format("%.2f", fire.Brightness)] = true
			for _, d in ctx.client.workspace:GetDescendants() do
				if d:IsA("SurfaceGui") and d.Brightness < 1 then
					dipped = true
				end
			end
		end
		local turned = before.LookVector:Dot(model:GetPivot().LookVector)
		t.ok(turned < 0.999, "radar rotated")
		t.ok((tip.CFrame.Position - tipBefore.Position).Magnitude > 0.01, "flag fly end moves")
		local lampStates = 0
		for _ in colors do
			lampStates += 1
		end
		t.ge(lampStates, 2, "lamp blinks between on and off")
		local fireStates = 0
		for _ in brightness do
			fireStates += 1
		end
		t.ge(fireStates, 4, "fire light flickers")
		t.ok(dipped, "a CRT flickered")
		t.noRuntimeErrors()
	end)

	test("ambient sound: loops on their anchors, culled by distance, wind bed", function(t)
		local ctx = Bridge.boot()
		local AmbientSound = ctx.module("Ambient.AmbientSound")
		t.ge(AmbientSound.sourceCount(), 10, "positional sources created")
		local wind = AmbientSound.wind()
		t.ok(wind and wind.IsPlaying and wind.Looped, "wind bed looping")
		local canteen
		for _, part in anchors(ctx, "Sound") do
			if part:GetAttribute("AmbientValue") == "Canteen" then
				canteen = part:FindFirstChildOfClass("Sound")
			end
		end
		t.ok(canteen ~= nil, "canteen chatter source")
		local courtyard = AmbientSound.update(Vector3.new(-6, 6, 90))
		t.ok(canteen.IsPlaying, "canteen chatter plays in the courtyard")
		t.eq(canteen.RollOffMode, roblox.Enum.RollOffMode.InverseTapered, "3D roll-off")
		local far = AmbientSound.update(Vector3.new(0, 30, -600))
		t.ok(not canteen.IsPlaying, "paused far away")
		t.ok(far < courtyard, ("fewer sources playing far away (%d < %d)"):format(far, courtyard))
		local spawn = AmbientSound.update(Vector3.new(0, 8, 27))
		t.metric("sources playing at spawn", spawn)
		t.le(spawn, 8, "only a handful of loops audible at once at spawn")
		t.noRuntimeErrors()
	end)

	test("flyby: helicopter crosses the sky with sound and is cleaned up", function(t)
		local ctx = Bridge.boot()
		local Flyby = ctx.module("Ambient.Flyby")
		local Sounds = ctx.client:requirePath("ReplicatedStorage.Lobby.Config.Sounds")
		local heli = Flyby.run()
		t.ok(heli ~= nil and heli.Parent == ctx.client.workspace, "flyby helicopter spawned")
		local start = heli:GetPivot().Position
		t.ge(start.Y, 100, "flies at altitude")
		ctx.client:step(5)
		local moved = (heli:GetPivot().Position - start).Magnitude
		t.ge(moved, 100, ("moving across the base (%.0f studs in 5 s)"):format(moved))
		local played = false
		for _, id in ctx.client.soundsPlayed do
			if id == Sounds.Flyby.Id then
				played = true
			end
		end
		t.ok(played, "flyby sound played")
		t.eq(Flyby.run(), nil, "one flyby at a time")
		ctx.client:step(Flyby.Duration)
		t.ok(heli.Parent == nil, "helicopter removed after the pass")
		t.noRuntimeErrors()
	end)

	test("UI feedback: credit gain, promotion toast, toast slide-in, pressed buttons", function(t)
		local ctx = Bridge.boot()
		local CommanderService = ctx.serverModule("Services.CommanderService")
		CommanderService.update(ctx.serverPlayer, function(p)
			p.credits += 150
			return true
		end)
		Scheduler.advance(0.1)
		t.ok(ctx.find("CreditGain") ~= nil, "+credits floater on the HUD")
		t.eq(ctx.find("CreditGain").Text, "+150 CR", "floater amount")
		Scheduler.advance(2)
		t.ok(ctx.find("CreditGain") == nil, "floater removed")
		CommanderService.update(ctx.serverPlayer, function(p)
			p.xp = 600 -- level 4
			return true
		end)
		Scheduler.advance(0.05)
		local card = ctx.find("Toast") and ctx.find("Toast"):FindFirstChild("Card")
		t.ok(card ~= nil, "promotion toast shown")
		t.eq(card and card.Title.Text, "PROMOTED", "promotion title")
		t.ok(card and card.Position.X.Offset > 0, "toast starts offset (slides in)")
		Scheduler.advance(0.4)
		t.eq(card and card.Position.X.Offset, 0, "toast slid into place")
		ctx.use("Matchmaking", "QUICK")
		local join = ctx.findVisible("JoinQueue")
		local idle = join.BackgroundColor3
		Runtime.signalFor(join, "MouseButton1Down"):Fire()
		local pressed = join.BackgroundColor3
		t.ok(pressed.R + pressed.G + pressed.B < idle.R + idle.G + idle.B, "button darkens while pressed")
		Runtime.signalFor(join, "MouseButton1Up"):Fire()
		t.noRuntimeErrors()
	end)

	test("performance: ambient layer cost per frame", function(t)
		local ctx = Bridge.boot()
		local Animator = ctx.module("Ambient.AmbientAnimator")
		lookFrom(ctx, Vector3.new(0, 20, 30))
		local frames = 300
		local started = os.clock()
		for _ = 1, frames do
			Animator.step(1 / 60)
		end
		local ms = (os.clock() - started) / frames * 1000
		t.metric("ambient step (ms, headless Lune)", ms)
		-- Lune's property access is several times slower than the engine's,
		-- so this bound is generous; it catches accidental O(parts) work.
		t.le(ms, 4, "ambient update stays cheap")
		lookFrom(ctx, Vector3.new(0, 40, -700))
		started = os.clock()
		for _ = 1, frames do
			Animator.step(1 / 60)
		end
		local farMs = (os.clock() - started) / frames * 1000
		t.metric("ambient step far away (ms)", farMs)
		t.le(farMs, ms + 0.5, "distance culling does not cost more")
	end)

	test("code hygiene: strict mode, headers, no debug leftovers", function(t)
		local files = sourceFiles("src")
		t.ge(#files, 60, "source files scanned")
		local problems = {}
		for _, path in files do
			local source = fs.readFile(path)
			local lines = string.split(source, "\n")
			if lines[1] ~= "--!strict" then
				table.insert(problems, path .. ": missing --!strict")
			end
			if not (lines[2] or ""):match("^%-%-") then
				table.insert(problems, path .. ": missing header comment")
			end
			for number, line in lines do
				local code = line:gsub("%-%-.*$", "")
				if code:match("[^%w_%.]print%(") or code:match("^print%(") then
					if not line:find("[Lobby]", 1, true) then
						table.insert(problems, ("%s:%d: stray print"):format(path, number))
					end
				end
				if line:match("TODO") or line:match("FIXME") or line:match("XXX") then
					table.insert(problems, ("%s:%d: leftover marker"):format(path, number))
				end
				if code:match("local _ = ") then
					table.insert(problems, ("%s:%d: placeholder local"):format(path, number))
				end
				if code:match("[^%w_%.]wait%(") or code:match("[^%w_%.:]spawn%(") or code:match("[^%w_%.:]delay%(") then
					table.insert(problems, ("%s:%d: deprecated global scheduler call"):format(path, number))
				end
				if code:match('Instance%.new%("[%w]+",') then
					table.insert(problems, ("%s:%d: Instance.new with parent argument"):format(path, number))
				end
			end
		end
		t.ok(
			#problems == 0,
			("no hygiene problems (%d)"):format(#problems) .. (problems[1] and ": " .. problems[1] or "")
		)
		for i = 2, math.min(#problems, 12) do
			t.log(problems[i])
		end
	end)
end
