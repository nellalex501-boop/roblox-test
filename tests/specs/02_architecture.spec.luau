--!nocheck
-- PHASE 2 — ARCHITECTURE: visual consistency, readability, navigation,
-- performance. Regression-runs every Phase 1 measurement on the Full build.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Nav = require("../lib/Nav")
local WorldChecks = require("../lib/WorldChecks")

local Vector3 = roblox.Vector3

local function hsv(color)
	local r, g, b = color.R, color.G, color.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local s = if max == 0 then 0 else (max - min) / max
	return s, max
end

return function(test)
	local runtime, root = WorldChecks.build("Full")
	local cfg = WorldChecks.config(runtime)
	local Layout = cfg.Layout
	local stats

	test("full build completes without runtime errors", function(t)
		t.ok(root ~= nil and root.Parent == runtime.workspace, "ColdWarLobby parented")
		t.eq(root:GetAttribute("BuildMode"), "Full", "build mode")
		for _, zoneId in Layout.ZoneOrder do
			t.ok(root.Zones:FindFirstChild(zoneId) ~= nil, zoneId .. " built")
		end
		t.noRuntimeErrors()
	end)

	test("performance budget (static geometry)", function(t)
		stats = WorldChecks.stats(root)
		for name, value in stats do
			t.metric(name, value)
		end
		t.le(stats.parts, 9000, "part count (Phase 4 detailing still to come)")
		t.eq(stats.unanchored, 0, "no physics-simulated parts")
		t.eq(stats.touchEnabled, 0, "CanTouch disabled on all static parts")
		t.le(stats.transparentParts, 20, "semi-transparent parts kept rare")
		t.le(stats.surfaceGuis, 120, "SurfaceGui count")
	end)

	test("visual consistency: muted palette (no neon/cartoon colours)", function(t)
		local offenders = {}
		for _, part in root:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 and part.Material ~= roblox.Enum.Material.Neon then
				local s, v = hsv(part.Color)
				if s > 0.72 and v > 0.7 then
					table.insert(offenders, part:GetFullName())
				end
			end
		end
		t.metric("bright saturated parts", #offenders)
		t.ok(
			#offenders == 0,
			"no bright saturated parts" .. (if #offenders > 0 then " (e.g. " .. offenders[1] .. ")" else "")
		)
		local neon = 0
		for _, part in root:GetDescendants() do
			if part:IsA("BasePart") and part.Material == roblox.Enum.Material.Neon then
				neon += 1
				t.ok(part.Size.Magnitude < 3, "neon only on small light bulbs: " .. part.Name)
			end
		end
		t.metric("neon light bulbs", neon)
	end)

	test("readability: every zone has a named sign readable from the plaza", function(t)
		local spawnEye = Layout.Spawn.Center + Vector3.new(0, 9, 12)
		for _, zoneId in Layout.ZoneOrder do
			local zone = Layout.Zones[zoneId]
			local model = root.Zones[zoneId]
			local best = nil
			for _, d in model:GetDescendants() do
				if d:IsA("TextLabel") and d.Name == "Title" then
					local part = d.Parent and d.Parent.Parent
					if part and part:IsA("BasePart") then
						local textHeight = part.Size.Y * d.Size.Y.Scale
						local distance = (part.CFrame.Position - spawnEye).Magnitude
						local ratio = textHeight / distance
						if not best or ratio > best.ratio then
							best = { ratio = ratio, text = d.Text, height = textHeight, distance = distance }
						end
					end
				end
			end
			t.ok(best ~= nil, zoneId .. " has a sign")
			if best then
				-- 0.012 rad ~ 7 px text at 720p / 70 deg FOV (legible); the
				-- mission board is read up close, so only require that it exists.
				local minRatio = if zoneId == "MissionBoard" then 0.005 else 0.012
				t.metric(
					("sign %s"):format(zoneId),
					("%s — %.1f studs tall at %d studs"):format(best.text, best.height, best.distance)
				)
				t.ge(best.ratio, minRatio, zoneId .. " main sign legible from the spawn camera")
			end
		end
	end)

	test("signposts: every arrow points at its destination", function(t)
		local Signage = runtime:requirePath("ServerScriptService.LobbyServer.World.Signage")
		local count = 0
		for _, plate in root:GetDescendants() do
			if plate:IsA("BasePart") and plate:GetAttribute("Destination") then
				count += 1
				local zone = Layout.Zones[plate:GetAttribute("Destination")]
				local post = plate.Parent:FindFirstChild("Post")
				local position = Vector3.new(post.CFrame.Position.X, 0.3, post.CFrame.Position.Z)
				local facing = plate.CFrame.LookVector
				local expected = Signage.arrowAngle(position, facing, Layout.entrancePoint(zone))
				local arrow = plate:FindFirstChildOfClass("SurfaceGui"):FindFirstChild("Arrow")
				t.eq(arrow.Rotation, expected, ("arrow to %s"):format(zone.DisplayName))
				-- sanity: the arrow direction really points toward the target in world space
				local forward = Vector3.new(-facing.X, 0, -facing.Z).Unit
				local right = forward:Cross(Vector3.new(0, 1, 0))
				local a = math.rad(arrow.Rotation)
				local worldDir = (right * math.cos(a) + forward * -math.sin(a)).Unit
				local toTarget = (Layout.entrancePoint(zone) - position)
				toTarget = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
				t.ok(
					worldDir:Dot(toTarget) > 0.7,
					("arrow to %s within 45 deg of the true direction"):format(zone.DisplayName)
				)
			end
		end
		t.ge(count, 12, "signpost plates")
	end)

	local nav
	test("navigation regression: every entrance and interaction reachable", function(t)
		nav = WorldChecks.navigation(runtime, root)
		for _, dest in nav.destinations do
			t.ok(dest.studs ~= nil, ("%s %s reachable"):format(dest.kind, dest.id))
		end
	end)

	test("navigation regression: compact walking times", function(t)
		local worstEntrance, worstPoint = 0, 0
		for _, dest in nav.destinations do
			if dest.seconds then
				if dest.kind == "Entrance" then
					worstEntrance = math.max(worstEntrance, dest.seconds)
					t.metric(("walk %s (s)"):format(dest.id), dest.seconds)
				else
					worstPoint = math.max(worstPoint, dest.seconds)
				end
			end
		end
		t.metric("worst entrance walk (s)", worstEntrance)
		t.metric("worst interaction walk (s)", worstPoint)
		t.le(worstEntrance, 20, "all entrances within 20 s")
		t.le(worstPoint, 30, "all interaction points within 30 s")
	end)

	test("boundary: players cannot walk out of the base", function(t)
		local p = Layout.Perimeter
		local grid = nav.grid
		local outside = 0
		for idx in nav.dist do
			local c = (idx - 1) % grid.cols
			local r = (idx - 1) // grid.cols
			local x = grid.minX + (c + 0.5) * grid.cell
			local z = grid.minZ + (r + 0.5) * grid.cell
			if x < p.MinX - 1 or x > p.MaxX + 1 or z < p.MinZ - 1 or z > p.MaxZ + 1 then
				outside += 1
			end
		end
		t.eq(outside, 0, "no reachable cell outside the perimeter fence")
	end)

	test("spawn regression", function(t)
		local spawns = WorldChecks.spawns(root)
		t.ge(#spawns, 8, "spawn pads")
		for _, spawn in spawns do
			local blockers = WorldChecks.spawnClearance(root, spawn)
			t.ok(#blockers == 0, spawn.Name .. " clear" .. (if #blockers > 0 then " (" .. blockers[1] .. ")" else ""))
			t.ok(spawn.CFrame.LookVector.Z < -0.99, spawn.Name .. " faces north")
		end
	end)

	test("sightlines: landmarks from the spawn camera", function(t)
		local lines = WorldChecks.sightlines(runtime, root)
		for _, line in lines do
			if line.eye == "spawnCamera" then
				t.metric(
					("sightline %s"):format(line.zone),
					if line.visible then "clear" else ("%d occluders"):format(line.occluders)
				)
			end
		end
		-- the radome/tower must rise above everything when seen from the plaza
		local eye = Layout.Spawn.Center + Vector3.new(0, 9, 12)
		local dome = root.Zones.OperationsCenter.Architecture:FindFirstChild("Radome")
		local occ = Nav.occluders(root, eye, dome.CFrame.Position, function(part)
			return part == dome
				or part.Name == "RadomeSeam"
				or part.Name == "RadomeBase"
				or part:FindFirstAncestor("Flag") ~= nil
		end)
		t.ok(
			#occ == 0,
			"radome landmark visible from spawn"
				.. (if #occ > 0 then " (blocked by " .. occ[1]:GetFullName() .. ")" else "")
		)
	end)

	test("export: geometry for preview renders", function(t)
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
			"build/render/architecture.json",
			{ start = nav.start, paths = paths, figures = figures }
		)
		t.ge(count, 1000, "exported parts")
		local summary = {}
		for _, dest in nav.destinations do
			table.insert(summary, { kind = dest.kind, id = dest.id, studs = dest.studs, seconds = dest.seconds })
		end
		fs.writeFile("build/render/architecture-nav.json", serde.encode("json", summary, true))
	end)
end
