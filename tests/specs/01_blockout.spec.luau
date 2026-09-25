--!nocheck
-- PHASE 1 — BLOCKOUT: navigation, scale, distances, visibility, player flow.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local WorldChecks = require("../lib/WorldChecks")

local function rectsOverlap(a, b)
	return a.MinX < b.MaxX and a.MaxX > b.MinX and a.MinZ < b.MaxZ and a.MaxZ > b.MinZ
end

return function(test)
	local runtime, root = WorldChecks.build("Blockout")
	local cfg = WorldChecks.config(runtime)
	local Layout = cfg.Layout

	test("blockout builds without runtime errors", function(t)
		t.ok(root ~= nil and root.Parent == runtime.workspace, "ColdWarLobby parented to Workspace")
		t.eq(root:GetAttribute("BuildMode"), "Blockout", "build mode attribute")
		local stats = WorldChecks.stats(root)
		t.metric("parts", stats.parts)
		t.metric("prompts", stats.prompts)
		t.ge(stats.prompts, 24, "planned interaction points placed")
		t.eq(stats.unanchored, 0, "every part anchored")
		t.noRuntimeErrors()
	end)

	test("spawn: count, placement, headroom, facing", function(t)
		local spawns = WorldChecks.spawns(root)
		t.ge(#spawns, 8, "at least 8 spawn pads for simultaneous joins")
		for _, spawn in spawns do
			local p = spawn.CFrame.Position
			local plaza = Layout.Plaza
			t.ok(
				p.X > plaza.MinX and p.X < plaza.MaxX and p.Z > plaza.MinZ and p.Z < plaza.MaxZ,
				spawn.Name .. " on the parade square"
			)
			local blockers = WorldChecks.spawnClearance(root, spawn)
			t.ok(
				#blockers == 0,
				spawn.Name
					.. " has 5.5 studs headroom"
					.. (if #blockers > 0 then " (blocked by " .. blockers[1] .. ")" else "")
			)
			local look = spawn.CFrame.LookVector
			t.ok(look.Z < -0.99, spawn.Name .. " faces north toward the Operations Center")
			t.ok(spawn.Neutral and spawn.Duration == 0, spawn.Name .. " neutral, no forcefield delay")
		end
		-- pads must not overlap each other (multiple players spawning together)
		for i = 1, #spawns do
			for j = i + 1, #spawns do
				local d = (spawns[i].CFrame.Position - spawns[j].CFrame.Position).Magnitude
				t.ok(d >= 4.5, ("%s / %s spaced %.1f studs"):format(spawns[i].Name, spawns[j].Name, d))
			end
		end
	end)

	test("layout: zones do not overlap each other, the plaza or roads", function(t)
		local ids = Layout.ZoneOrder
		for i = 1, #ids do
			local a = Layout.footprint(Layout.Zones[ids[i]])
			t.ok(not rectsOverlap(a, Layout.Plaza) or ids[i] == "MissionBoard", ids[i] .. " clear of the parade square")
			for _, road in Layout.Roads do
				t.ok(not rectsOverlap(a, road), ("%s clear of %s"):format(ids[i], road.Name))
			end
			for j = i + 1, #ids do
				local b = Layout.footprint(Layout.Zones[ids[j]])
				t.ok(not rectsOverlap(a, b), ("%s / %s footprints separate"):format(ids[i], ids[j]))
			end
		end
	end)

	test("scale: entrances and interiors fit a Roblox character", function(t)
		for _, zoneId in Layout.ZoneOrder do
			local zone = Layout.Zones[zoneId]
			if zone.Kind == "Building" then
				for i, entrance in zone.Entrances do
					t.ge(entrance.Width, 8, ("%s entrance %d width"):format(zoneId, i))
					t.ge(entrance.Height, 10, ("%s entrance %d height (character ~5.5)"):format(zoneId, i))
				end
				t.ge(zone.Height, 16, zoneId .. " interior height leaves room for the 3rd-person camera")
			end
		end
	end)

	local nav
	test("navigation: every entrance and interaction point is reachable", function(t)
		nav = WorldChecks.navigation(runtime, root)
		t.metric(
			"walkable grid cells reached",
			(function()
				local n = 0
				for _ in nav.dist do
					n += 1
				end
				return n
			end)()
		)
		for _, dest in nav.destinations do
			t.ok(dest.studs ~= nil, ("%s %s reachable"):format(dest.kind, dest.id))
		end
	end)

	test("navigation: compact — walking time from spawn", function(t)
		local worstEntrance, worstPoint = 0, 0
		for _, dest in nav.destinations do
			if dest.seconds then
				if dest.kind == "Entrance" then
					worstEntrance = math.max(worstEntrance, dest.seconds)
					t.metric(("walk %s (s)"):format(dest.id), dest.seconds)
					t.le(dest.seconds, 20, dest.id .. " entrance within 20 s")
				else
					worstPoint = math.max(worstPoint, dest.seconds)
				end
			end
		end
		t.metric("worst entrance walk (s)", worstEntrance)
		t.metric("worst interaction walk (s)", worstPoint)
		t.le(worstPoint, 30, "every interaction point within 30 s")
	end)

	test("visibility: landmarks readable from the spawn camera", function(t)
		local lines = WorldChecks.sightlines(runtime, root)
		local mustSee = { OperationsCenter = true, Garage = true, CommandHQ = true }
		for _, line in lines do
			if line.eye == "spawnCamera" then
				t.metric(
					("sightline %s"):format(line.zone),
					if line.visible then "clear" else ("%d occluders"):format(line.occluders)
				)
				if mustSee[line.zone] then
					t.ok(line.visible, line.zone .. " facade visible from spawn camera")
				end
			end
		end
	end)

	test("export: geometry + paths for the preview renderer", function(t)
		fs.writeDir("build/render")
		local paths = {}
		for _, dest in nav.destinations do
			if dest.kind == "Entrance" and dest.path then
				table.insert(paths, { id = dest.id, points = dest.path, seconds = dest.seconds })
			end
		end
		local figures = {}
		for _, spawn in WorldChecks.spawns(root) do
			local pos = spawn.CFrame.Position
			table.insert(figures, { pos.X, pos.Y + spawn.Size.Y / 2, pos.Z, 0 })
		end
		for _, zoneId in Layout.ZoneOrder do
			local e = Layout.entrancePoint(Layout.Zones[zoneId])
			table.insert(figures, { e.X, 0.3, e.Z, 0 })
		end
		local count = WorldChecks.export(
			root,
			"build/render/blockout.json",
			{ start = nav.start, paths = paths, figures = figures }
		)
		t.ge(count, 100, "exported parts")
		local summary = {}
		for _, dest in nav.destinations do
			table.insert(summary, { kind = dest.kind, id = dest.id, studs = dest.studs, seconds = dest.seconds })
		end
		fs.writeFile("build/render/blockout-nav.json", serde.encode("json", summary, true))
	end)
end
