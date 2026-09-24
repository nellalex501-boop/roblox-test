--!nocheck
-- PHASE 4 — DETAILING: props, furniture, parked vehicles, utility, light
-- fittings. Checks render cost, the muted palette, believable placement
-- (every floor prop rests on the floor and does not cut into existing
-- geometry) and re-runs the navigation / spawn / sightline regressions on
-- the fully detailed world.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local GuiExport = require("../lib/GuiExport")
local Nav = require("../lib/Nav")
local WorldChecks = require("../lib/WorldChecks")

local Vector3 = roblox.Vector3

local function hsv(color)
	local r, g, b = color.R, color.G, color.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local s = if max == 0 then 0 else (max - min) / max
	return s, max
end

local function partsOf(model)
	local list = {}
	if model:IsA("BasePart") then
		table.insert(list, model)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

return function(test)
	local runtime, root = WorldChecks.build("Full")
	local cfg = WorldChecks.config(runtime)
	local Layout = cfg.Layout
	local details = root:FindFirstChild("Details")

	test("detailed build completes without runtime errors", function(t)
		t.ok(details ~= nil, "Details folder built")
		t.ok(details and details:FindFirstChild("Outdoor") and details:FindFirstChild("Interior"), "outdoor + interior")
		local grounded = 0
		for _, d in details:GetDescendants() do
			if d:GetAttribute("Grounded") then
				grounded += 1
			end
		end
		t.metric("floor props", grounded)
		t.ge(grounded, 150, "props placed")
		t.noRuntimeErrors()
	end)

	test("performance budget (detailed world)", function(t)
		local stats = WorldChecks.stats(root)
		for name, value in stats do
			t.metric(name, value)
		end
		local detailParts = 0
		for _, d in details:GetDescendants() do
			if d:IsA("BasePart") then
				detailParts += 1
			end
		end
		t.metric("detail parts", detailParts)
		t.le(stats.parts, 9000, "total part count")
		t.eq(stats.unanchored, 0, "no physics-simulated parts")
		t.eq(stats.touchEnabled, 0, "CanTouch disabled everywhere")
		t.le(stats.transparentParts, 30, "semi-transparent parts kept rare")
		t.le(stats.lights, 60, "light count")
		t.eq(stats.shadowLights, 0, "no shadow-casting lights")
		t.le(stats.shadowCasters, 5000, "shadow casters")
		local brightest = 0
		for _, d in root:GetDescendants() do
			if d:IsA("Light") then
				brightest = math.max(brightest, d.Brightness)
			end
		end
		t.le(brightest, 2, "light brightness stays subtle")
		local emitters, rate = 0, 0
		for _, d in root:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				emitters += 1
				rate += d.Rate
			elseif d:IsA("Fire") or d:IsA("Smoke") then
				emitters += 1
			end
		end
		t.metric("particle emitters", emitters)
		t.metric("particles per second", rate)
		t.le(emitters, 12, "few particle effects")
		t.le(rate, 20, "low total particle rate")
		local pixels, unculled = 0, 0
		for _, surface in GuiExport.surfaces(root) do
			pixels += surface.px[1] * surface.px[2]
		end
		for _, gui in root:GetDescendants() do
			if gui:IsA("SurfaceGui") and gui.MaxDistance == 0 then
				unculled += 1
			end
		end
		t.metric("SurfaceGui canvas pixels", pixels)
		t.metric("SurfaceGuis without distance culling", unculled)
		t.le(pixels, 4500000, "total SurfaceGui canvas under 4.5 Mpx")
		t.le(unculled, 45, "always-rendered SurfaceGuis unchanged by detailing")
	end)

	test("visual consistency: detailing keeps the muted palette", function(t)
		local offenders = {}
		local neon = 0
		for _, part in details:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				if part.Material == roblox.Enum.Material.Neon then
					neon += 1
					t.ok(part.Size.Magnitude < 7, "neon only on bulbs / tubes: " .. part:GetFullName())
				else
					local s, v = hsv(part.Color)
					if s > 0.72 and v > 0.7 then
						table.insert(offenders, part:GetFullName())
					end
				end
			end
		end
		t.metric("neon bulbs/tubes", neon)
		t.ok(
			#offenders == 0,
			"no bright saturated props" .. (if #offenders > 0 then " (e.g. " .. offenders[1] .. ")" else "")
		)
	end)

	-- Height field of the world WITHOUT detailing: props must rest on it and
	-- must not cut into it.
	local baseRuntime, baseRoot = WorldChecks.build("Full", { details = false })
	local bounds = {
		MinX = Layout.Perimeter.MinX - 40,
		MaxX = Layout.Perimeter.MaxX + 40,
		MinZ = Layout.Perimeter.MinZ - 80,
		MaxZ = Layout.Perimeter.MaxZ + 80,
	}
	local baseGrid = Nav.build(baseRoot, bounds)
	local _ = baseRuntime

	local function floorBelow(x, z, y)
		local idx = Nav.idxOf(baseGrid, x, z)
		if not idx then
			return nil
		end
		local best = nil
		for _, span in baseGrid.spans[idx] or {} do
			if span[2] <= y + 0.35 and (best == nil or span[2] > best) then
				best = span[2]
			end
		end
		return best
	end

	test("placement: floor props rest on the floor", function(t)
		local floating, sunk = {}, {}
		local checked = 0
		for _, model in details:GetDescendants() do
			if model:GetAttribute("Grounded") then
				checked += 1
				local minY = math.huge
				local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
				for _, part in partsOf(model) do
					local x0, x1, y0, _, z0, z1 = Nav.worldBounds(part)
					if part.Transparency < 1 then
						minY = math.min(minY, y0)
					end
					minX, maxX = math.min(minX, x0), math.max(maxX, x1)
					minZ, maxZ = math.min(minZ, z0), math.max(maxZ, z1)
				end
				local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
				local floor = floorBelow(cx, cz, minY) or 0
				local gap = minY - floor
				if gap > 0.35 then
					table.insert(floating, ("%s (%.2f above floor)"):format(model:GetFullName(), gap))
				elseif gap < -0.35 then
					table.insert(sunk, ("%s (%.2f below floor)"):format(model:GetFullName(), -gap))
				end
			end
		end
		t.metric("props checked", checked)
		t.ok(
			#floating == 0,
			("no floating props (%d)"):format(#floating) .. (floating[1] and ": " .. floating[1] or "")
		)
		t.ok(#sunk == 0, ("no sunken props (%d)"):format(#sunk) .. (sunk[1] and ": " .. sunk[1] or ""))
		for i = 2, math.min(#floating, 6) do
			t.log("floating: " .. floating[i])
		end
		for i = 2, math.min(#sunk, 6) do
			t.log("sunk: " .. sunk[i])
		end
	end)

	test("placement: props do not cut into walls, furniture or stations", function(t)
		local clashes = {}
		local seen = {}
		for _, model in details:GetDescendants() do
			if model:GetAttribute("Grounded") and not seen[model] then
				seen[model] = true
				for _, part in partsOf(model) do
					if part.CanCollide and part.Transparency < 1 then
						local x0, x1, y0, y1, z0, z1 = Nav.worldBounds(part)
						-- sample the part footprint on a 1-stud grid, inset
						-- 0.3 so touching faces are not clashes
						local hit = nil
						local x = x0 + 0.3
						while x <= x1 - 0.3 and not hit do
							local z = z0 + 0.3
							while z <= z1 - 0.3 and not hit do
								local idx = Nav.idxOf(baseGrid, x, z)
								for _, span in (idx and baseGrid.spans[idx]) or {} do
									if span[1] < y1 - 0.2 and span[2] > y0 + 0.3 then
										hit = ("%s/%s"):format(model.Name, part.Name)
										break
									end
								end
								z += 1
							end
							x += 1
						end
						if hit then
							table.insert(clashes, model:GetFullName() .. " · " .. part.Name)
							break
						end
					end
				end
			end
		end
		t.ok(#clashes == 0, ("no clashing props (%d)"):format(#clashes) .. (clashes[1] and ": " .. clashes[1] or ""))
		for i = 2, math.min(#clashes, 10) do
			t.log("clash: " .. clashes[i])
		end
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

	test("spawn and sightline regression", function(t)
		for _, spawn in WorldChecks.spawns(root) do
			local blockers = WorldChecks.spawnClearance(root, spawn)
			t.ok(#blockers == 0, spawn.Name .. " clear" .. (if #blockers > 0 then " (" .. blockers[1] .. ")" else ""))
		end
		for _, line in WorldChecks.sightlines(runtime, root) do
			if line.eye == "spawnCamera" then
				t.metric(
					("sightline %s"):format(line.zone),
					if line.visible then "clear" else ("%d occluders"):format(line.occluders)
				)
			end
		end
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
			"radome landmark still visible from spawn" .. (occ[1] and (" (" .. occ[1]:GetFullName() .. ")") or "")
		)
	end)

	test("ambient anchors: every positional ambient sound has a source", function(t)
		local Sounds = runtime:requirePath("ReplicatedStorage.Lobby.Config.Sounds")
		local have = {}
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("AmbientRole") then
				local role, value = d:GetAttribute("AmbientRole"), d:GetAttribute("AmbientValue")
				if value then
					have[value] = (have[value] or 0) + 1
				end
				have["role:" .. role] = (have["role:" .. role] or 0) + 1
			end
		end
		for name in Sounds.Ambient do
			if name == "Wind" then
				continue -- global 2D bed
			elseif name == "Flags" then
				t.ok((have["role:Flag"] or 0) > 0, "flag anchors for the flag-snapping sound")
			else
				t.ok((have[name] or 0) > 0, "anchor for ambient sound " .. name)
			end
		end
		t.ge(have["role:Smoke"] or 0, 2, "smoke anchors (chimney, field kitchen)")
		t.ge(have["role:Fire"] or 0, 1, "fire anchors")
	end)

	test("export: detailed geometry for preview renders", function(t)
		fs.writeDir("build/render")
		local count = WorldChecks.export(root, "build/render/detailing.json", { paths = {}, figures = {} })
		t.ge(count, 4000, "exported parts")
		fs.writeFile("build/render/detailing-summary.json", serde.encode("json", { parts = count }, true))
	end)
end
