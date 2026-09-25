--!nocheck
-- VISUAL REVIEW — regressions for the review list: no z-fighting anywhere,
-- signs and plates readable (not covered, not cut by columns or windows,
-- text large enough), flags built from enough segments, the winter yard's
-- effects in place, and the landscape closing the view on every side.
-- Second pass: nothing floats, no text has a part in front of it, trees
-- stay clear of structures, roads and footpaths form one network, every
-- zone's sign is in view from the spawn pads, and signs sit flush.

local roblox = require("@lune/roblox")

local Audit = require("../lib/Audit")
local Geometry = require("../lib/Geometry")
local WorldChecks = require("../lib/WorldChecks")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

return function(test)
	local runtime, root = WorldChecks.build("Full")
	local grid = Geometry.index(root, function(p)
		return p.Transparency < 0.1
	end, 8)
	local Layout = runtime:requirePath("ReplicatedStorage.Lobby.Config.Layout")
	-- the base inside the fence with a margin (the forest beyond is scenery)
	local BASE = { MinX = -200, MaxX = 205, MinZ = -185, MaxZ = 190 }

	-- 15 points spread over a part's front face, `lift` studs off it
	local function faceSamples(part, lift)
		local cf, size = part.CFrame, part.Size
		local list = {}
		for i = 0, 4 do
			for j = 0, 2 do
				table.insert(
					list,
					(cf * CFrame.new((i / 4 - 0.5) * size.X * 0.9, (j / 2 - 0.5) * size.Y * 0.8, -size.Z / 2 - lift)).Position
				)
			end
		end
		return list
	end

	local function listed(set)
		local list = {}
		for name in set do
			table.insert(list, name)
		end
		table.sort(list)
		return list
	end

	test("no z-fighting: no two faces share a plane where they overlap", function(t)
		-- two parts whose faces point the same way, lie within 0.045 studs and
		-- overlap flicker in Roblox; identical untextured faces look the same
		-- either way and are only counted
		local findings = Geometry.coplanar(root, { grid = grid })
		local visible, same = {}, 0
		for _, f in findings do
			if f.sameLook then
				same += 1
			else
				table.insert(visible, f)
			end
		end
		t.metric("coplanar overlaps (identical look)", same)
		t.metric("coplanar overlaps (visible)", #visible)
		for i = 1, math.min(#visible, 12) do
			local f = visible[i]
			t.ok(
				false,
				("flicker: %s | %s (gap %.3f, area %.2f)"):format(f.a:GetFullName(), f.b:GetFullName(), f.gap, f.area)
			)
		end
		t.eq(#visible, 0, "visible coplanar overlaps")
	end)

	test("signs: building plates and entrance signs are not covered, plates sit on solid wall", function(t)
		-- a grid of rays straight at each sign's face must hit the sign first
		-- (no column, strut, frame or roof in front); rays leaving a plate's
		-- back must meet wall within 0.25 (not a window recess or a gap)
		local names = { BuildingNumber = true, EntranceSign = true, ZoneName = true, YardSign = true }
		local checked = 0
		for _, sign in root:GetDescendants() do
			if sign:IsA("BasePart") and names[sign.Name] then
				checked += 1
				local cf, size = sign.CFrame, sign.Size
				local covered, open = {}, 0
				for i = 0, 4 do
					for j = 0, 2 do
						local lx = (i / 4 - 0.5) * size.X * 0.9
						local ly = (j / 2 - 0.5) * size.Y * 0.8
						local face = (cf * CFrame.new(lx, ly, -size.Z / 2)).Position
						local hit = Geometry.raycast(grid, face + cf.LookVector * 10, cf.LookVector * -10.3)
						if hit and hit ~= sign then
							covered[hit.Name] = true
						end
						if sign.Name == "BuildingNumber" then
							local back = (cf * CFrame.new(lx, ly, size.Z / 2 + 0.01)).Position
							if not Geometry.raycast(grid, back, cf.LookVector * -0.25) then
								open += 1
							end
						end
					end
				end
				local list = {}
				for name in covered do
					table.insert(list, name)
				end
				local where = sign:GetFullName():gsub("^Workspace%.ColdWarLobby%.", "")
				t.eq(
					#list,
					0,
					where .. " not covered" .. (if #list > 0 then " (" .. table.concat(list, ", ") .. ")" else "")
				)
				if sign.Name == "BuildingNumber" then
					t.eq(open, 0, where .. " on solid wall")
				end
			end
		end
		t.ge(checked, 14, "signs checked")
	end)

	test("world text: every label on a surface renders at least a quarter stud tall", function(t)
		-- a label's text height in pixels (TextScaled: limited by its box
		-- height per line and by its width for the longest line, ~0.55 em
		-- per glyph; otherwise TextSize), divided by the SurfaceGui's pixels
		-- per stud
		local FACES = { Front = "XY", Back = "XY", Left = "ZY", Right = "ZY", Top = "XZ", Bottom = "XZ" }
		local function textPixels(label, w, h)
			local text = label.Text
			if text == "" then
				return nil
			end
			local lines, longest = 0, 0
			for line in (text .. "\n"):gmatch("(.-)\n") do
				lines += 1
				longest = math.max(longest, utf8.len(line) or #line)
			end
			if not label.TextScaled then
				return label.TextSize
			end
			local size = math.min(h / lines, if longest > 0 then w / (longest * 0.55) else h)
			local cap = label:FindFirstChildOfClass("UITextSizeConstraint")
			if cap then
				size = math.min(size, cap.MaxTextSize)
			end
			return math.min(size, 100)
		end
		local small, total = {}, 0
		local function walk(inst, w, h, pps, where)
			for _, child in inst:GetChildren() do
				if child:IsA("GuiObject") then
					local cw = w * child.Size.X.Scale + child.Size.X.Offset
					local ch = h * child.Size.Y.Scale + child.Size.Y.Offset
					if child:IsA("TextLabel") or child:IsA("TextButton") then
						local px = textPixels(child, cw, ch)
						if px then
							total += 1
							if px / pps < 0.25 then
								table.insert(
									small,
									("%s > %s [%s] %.2f"):format(where, child.Name, child.Text, px / pps)
								)
							end
						end
					end
					walk(child, cw, ch, pps, where)
				end
			end
		end
		for _, gui in root:GetDescendants() do
			if gui:IsA("SurfaceGui") and gui.Parent and gui.Parent:IsA("BasePart") then
				local part = gui.Parent
				local dims = FACES[gui.Face.Name]
				local w = if dims == "ZY" then part.Size.Z else part.Size.X
				local h = if dims == "XZ" then part.Size.Z else part.Size.Y
				local where = part:GetFullName():gsub("^Workspace%.ColdWarLobby%.", "")
				walk(gui, w * gui.PixelsPerStud, h * gui.PixelsPerStud, gui.PixelsPerStud, where)
			end
		end
		t.metric("world labels", total)
		t.ge(total, 300, "labels measured")
		for i = 1, math.min(#small, 10) do
			t.ok(false, "too small: " .. small[i])
		end
		t.eq(#small, 0, "labels under 0.25 studs")
	end)

	test("street lamps stand clear of doorways, windows and flagpoles", function(t)
		local lamps, windows, flagpoles = {}, {}, {}
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Pole" and d.Parent and d.Parent.Name == "StreetLamp" then
					table.insert(lamps, d)
				elseif d.Name == "Window" or d.Name == "BoothGlass" then
					table.insert(windows, d)
				elseif d.Name == "Pole" and d.Parent and d.Parent:FindFirstChild("Finial") then
					table.insert(flagpoles, d)
				end
			end
		end
		t.ge(#lamps, 30, "street lamps found")
		local problems = {}
		for _, lamp in lamps do
			local p = lamp.CFrame.Position
			local where = ("lamp at (%.0f, %.0f)"):format(p.X, p.Z)
			-- not in front of a building's doors (6 studs deep); the open zones'
			-- "entrances" are whole frontages along the sidewalk
			for _, zoneId in Layout.ZoneOrder do
				local zone = Layout.Zones[zoneId]
				local lp = Layout.frame(zone):PointToObjectSpace(p)
				for _, e in if zone.Kind == "Building" then zone.Entrances else {} do
					if math.abs(lp.X - e.Offset) < e.Width / 2 + 0.5 and lp.Z > -0.5 and lp.Z < 6 then
						table.insert(problems, where .. " in front of the " .. zoneId .. " entrance")
					end
				end
			end
			-- not right in front of a window
			for _, w in windows do
				local lp = w.CFrame:PointToObjectSpace(Vector3.new(p.X, w.CFrame.Position.Y, p.Z))
				if math.abs(lp.X) < w.Size.X / 2 + 1 and math.abs(lp.Z) < w.Size.Z / 2 + 3.5 then
					table.insert(problems, where .. " in front of " .. w:GetFullName())
					break
				end
			end
			-- 6+ studs from a flagpole (flags fly at lamp-head height)
			for _, pole in flagpoles do
				local q = pole.CFrame.Position
				if Vector3.new(q.X - p.X, 0, q.Z - p.Z).Magnitude < 6 then
					table.insert(problems, where .. " next to a flagpole")
				end
			end
		end
		for i = 1, math.min(#problems, 10) do
			t.ok(false, problems[i])
		end
		t.eq(#problems, 0, "lamps clear")
	end)

	test("theatre maps: no label covers another label or a battle-map marker", function(t)
		local canvases = {}
		for _, d in root:GetDescendants() do
			if d.Name == "TheaterCanvas" then
				table.insert(canvases, d)
			end
		end
		t.ge(#canvases, 2, "theatre maps drawn (Ops wall, HQ office)")
		for _, canvas in canvases do
			local boxes = {}
			for _, child in canvas:GetChildren() do
				if child:IsA("GuiObject") and (child:IsA("TextLabel") or child.Name == "MapMarker") then
					local size, pos, anchor = child.Size, child.Position, child.AnchorPoint
					local x0 = pos.X.Offset - anchor.X * size.X.Offset
					local y0 = pos.Y.Offset - anchor.Y * size.Y.Offset
					table.insert(boxes, {
						name = if child:IsA("TextLabel")
							then child.Text
							else "marker " .. tostring(child:GetAttribute("MapId")),
						x0 = x0,
						y0 = y0,
						x1 = x0 + size.X.Offset,
						y1 = y0 + size.Y.Offset,
					})
				end
			end
			local overlaps = {}
			for i = 1, #boxes do
				for j = i + 1, #boxes do
					local a, b = boxes[i], boxes[j]
					local ox = math.min(a.x1, b.x1) - math.max(a.x0, b.x0)
					local oy = math.min(a.y1, b.y1) - math.max(a.y0, b.y0)
					if ox > 1 and oy > 1 then
						table.insert(overlaps, a.name .. " / " .. b.name)
					end
				end
			end
			local where = canvas:GetFullName():gsub("^Workspace%.ColdWarLobby%.", "")
			t.eq(
				#overlaps,
				0,
				where .. " labels clear" .. (if #overlaps > 0 then " (" .. table.concat(overlaps, "; ") .. ")" else "")
			)
		end
	end)

	test("operations hall: from the doorway no terminal sign hides another or the wall display", function(t)
		local stations = root.Zones.OperationsCenter:FindFirstChild("Stations")
		local signs, isSign = {}, {}
		for _, model in stations:GetChildren() do
			local id = model.Name:match("^Terminal_(.+)$")
			local sign = id and model:FindFirstChild("OverheadSign")
			if sign then
				signs[id] = sign
				isSign[sign] = id
			end
		end
		local wall = stations:FindFirstChild("CommandWall")
		t.ok(wall ~= nil, "command wall found")
		-- hanging light fittings count as clutter in front of a sign too
		local fixtures = { Housing = true, Tube = true, Cord = true }
		local function samples(part)
			local cf, size = part.CFrame, part.Size
			local list = {}
			for i = 0, 4 do
				for j = 0, 2 do
					table.insert(
						list,
						(cf * CFrame.new((i / 4 - 0.5) * size.X * 0.9, (j / 2 - 0.5) * size.Y * 0.8, 0)).Position
					)
				end
			end
			return list
		end
		-- a player just inside the door (first person) and the third-person
		-- camera behind a player in the doorway
		for _, eye in { Vector3.new(0, 6.5, -78), Vector3.new(0, 10, -70) } do
			for id, sign in signs do
				local hidden = {}
				for _, p in samples(sign) do
					local hit = Geometry.raycast(grid, eye, (p - eye) * 1.02)
					if hit and hit ~= sign and isSign[hit] then
						hidden[isSign[hit]] = true
					elseif hit and fixtures[hit.Name] then
						hidden["light " .. hit.Name] = true
					end
				end
				local list = {}
				for other in hidden do
					table.insert(list, other)
				end
				t.eq(
					#list,
					0,
					("%s sign clear of the other signs from %s%s"):format(
						id,
						tostring(eye),
						if #list > 0 then " (behind " .. table.concat(list, ", ") .. ")" else ""
					)
				)
			end
			-- the command wall's display panels are not hidden by a sign
			local covered = 0
			for _, panel in wall:GetDescendants() do
				if panel:IsA("BasePart") and panel:FindFirstChildOfClass("SurfaceGui") then
					for _, p in samples(panel) do
						local hit = Geometry.raycast(grid, eye, (p - eye) * 1.02)
						if hit and isSign[hit] then
							covered += 1
						end
					end
				end
			end
			t.eq(covered, 0, "command wall display clear of the signs from " .. tostring(eye))
		end
	end)

	test("support: every visible part rests on the ground or on another part", function(t)
		-- chains of touching visible parts (gaps up to 0.08) from the ground;
		-- a tree counts as one piece (its crowns stand on the trunk)
		local islands = Audit.islands(root, BASE, 0.08)
		for i = 1, math.min(#islands, 10) do
			local g = islands[i]
			t.ok(
				false,
				("floating: %s (%d parts: %s) at %.0f, %.1f, %.0f"):format(
					g.path,
					#g.parts,
					table.concat(g.parts, ", "):sub(1, 80),
					g.at.X,
					g.at.Y,
					g.at.Z
				)
			)
		end
		t.eq(#islands, 0, "floating groups")
	end)

	test("surface text: no part stands within 3 studs in front of any label", function(t)
		-- rays leave a grid of points on every label (and on the event
		-- surfaces filled at runtime); the strings run from pin to pin
		-- across the pinned papers by design
		local findings = Audit.coveredText(root, BASE, 3, function(hit, part)
			return hit.Name == "String" and hit.Parent == part.Parent
		end)
		for i = 1, math.min(#findings, 10) do
			local f = findings[i]
			t.ok(
				false,
				("covered: %s [%s] %d/%d rays by %s"):format(
					Audit.path(root, f.part),
					f.face,
					f.covered,
					f.total,
					table.concat(f.blockers, "; ")
				)
			)
		end
		t.eq(#findings, 0, "labels with a part in front")
	end)

	test("trees: no tree grows into a building, vehicle or prop", function(t)
		local clashes = Audit.treeClashes(root, BASE, 0.3)
		for i = 1, math.min(#clashes, 10) do
			t.ok(false, "clash: " .. clashes[i])
		end
		t.eq(#clashes, 0, "trees cutting into other parts")
	end)

	-- two rects overlap or share an edge of positive length
	local function joins(a, b)
		local ox = math.min(a.MaxX, b.MaxX) - math.max(a.MinX, b.MinX)
		local oz = math.min(a.MaxZ, b.MaxZ) - math.max(a.MinZ, b.MinZ)
		return ox >= -0.01 and oz >= -0.01 and math.max(ox, oz) > 0.5
	end

	test("roads: both ends of every road run into another road or out of the base", function(t)
		for _, road in Layout.Roads do
			local alongX = road.MaxX - road.MinX > road.MaxZ - road.MinZ
			local w = if alongX then road.MaxZ - road.MinZ else road.MaxX - road.MinX
			-- the last road width at each end
			local ends = if alongX
				then {
					{ MinX = road.MinX, MaxX = road.MinX + w, MinZ = road.MinZ, MaxZ = road.MaxZ, At = road.MinX },
					{ MinX = road.MaxX - w, MaxX = road.MaxX, MinZ = road.MinZ, MaxZ = road.MaxZ, At = road.MaxX },
				}
				else {
					{ MinX = road.MinX, MaxX = road.MaxX, MinZ = road.MinZ, MaxZ = road.MinZ + w, At = road.MinZ },
					{ MinX = road.MinX, MaxX = road.MaxX, MinZ = road.MaxZ - w, MaxZ = road.MaxZ, At = road.MaxZ },
				}
			for _, e in ends do
				local joined = if alongX
					then e.At < BASE.MinX or e.At > BASE.MaxX
					else e.At < BASE.MinZ or e.At > BASE.MaxZ
				for _, other in Layout.Roads do
					if other ~= road and joins(e, other) then
						joined = true
					end
				end
				t.ok(
					joined,
					("%s end at %s = %.1f joins the network"):format(road.Name, if alongX then "x" else "z", e.At)
				)
			end
		end
	end)

	test("barracks: every door opens onto a footpath that leads to a road", function(t)
		local walks = {}
		for _, r in Layout.Roads do
			table.insert(walks, { rect = r, road = true })
		end
		for _, r in Layout.Paths do
			table.insert(walks, { rect = r, path = true })
		end
		local sidewalks = root:FindFirstChild("Sidewalks", true)
		t.ok(sidewalks ~= nil, "sidewalks found")
		for _, d in sidewalks:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Sidewalk" then
				local p, size = d.CFrame.Position, d.Size
				table.insert(walks, {
					rect = {
						MinX = p.X - size.X / 2,
						MaxX = p.X + size.X / 2,
						MinZ = p.Z - size.Z / 2,
						MaxZ = p.Z + size.Z / 2,
					},
				})
			end
		end
		-- flood from the roads through touching walks
		local reached, queue = {}, {}
		for _, w in walks do
			if w.road then
				reached[w] = true
				table.insert(queue, w)
			end
		end
		local head = 1
		while head <= #queue do
			local w = queue[head]
			head += 1
			for _, other in walks do
				if not reached[other] and joins(w.rect, other.rect) then
					reached[other] = true
					table.insert(queue, other)
				end
			end
		end
		for i, w in walks do
			if w.path then
				t.ok(reached[w], ("footpath %d joins the road network"):format(i - #Layout.Roads))
			end
		end
		for _, b in Layout.Barracks do
			local frame = CFrame.lookAt(b.Facade, b.Facade + b.Inward)
			for _, x in { -b.Length / 4, 0, b.Length / 4 } do
				-- just past the 2.6-deep door step
				local p = (frame * CFrame.new(x, 0, 3)).Position
				local onPath = false
				for _, r in Layout.Paths do
					if p.X >= r.MinX and p.X <= r.MaxX and p.Z >= r.MinZ and p.Z <= r.MaxZ then
						onPath = true
					end
				end
				t.ok(onPath, ("%s door at %.0f, %.0f opens onto a footpath"):format(b.Number, p.X, p.Z))
			end
		end
	end)

	test("sightlines: every zone's sign is in view from the spawn pads", function(t)
		-- the default camera 12 studs behind a player on the pad who has
		-- turned toward the sign, 9 up; it pops in front of anything between
		-- it and the head, so the rays start 12.5 studs out. A sign is in
		-- view when at most 3 of 15 rays to its face are blocked (a lamp post
		-- may cross it). Each zone's own sign must be in view from at least
		-- 6 of the 8 pads, and from every pad either it or a signpost plate
		-- naming the zone.
		local NAMES = { EntranceSign = true, TowerSign = true, Header = true, EventBanner = true, ZoneName = true }
		local pads = {}
		for _, d in root:GetDescendants() do
			if d:IsA("SpawnLocation") then
				table.insert(pads, d)
			end
		end
		t.eq(#pads, Layout.Spawn.Count, "spawn pads")
		local function blocked(sign, pad)
			local pos = sign.CFrame.Position
			local flat = pos - pad.CFrame.Position
			local eye = pad.CFrame.Position - Vector3.new(flat.X, 0, flat.Z).Unit * 12 + Vector3.new(0, 9, 0)
			if sign.CFrame.LookVector:Dot((eye - pos).Unit) < 0.2 then
				return 15 -- edge-on or from behind
			end
			local n = 0
			for _, p in faceSamples(sign, 0.02) do
				local from = eye + (p - eye).Unit * 12.5
				local hit = Geometry.raycast(grid, from, p - from)
				if hit and hit ~= sign then
					n += 1
				end
			end
			return n
		end
		local plates = {}
		for _, d in root:GetDescendants() do
			local zoneId = d:IsA("BasePart") and d.Name == "Plate" and d:GetAttribute("Destination")
			if zoneId then
				plates[zoneId] = plates[zoneId] or {}
				table.insert(plates[zoneId], d)
			end
		end
		for _, zoneId in Layout.ZoneOrder do
			local signs = {}
			for _, d in root.Zones[zoneId]:GetDescendants() do
				if d:IsA("BasePart") and NAMES[d.Name] and d:FindFirstChildOfClass("SurfaceGui") then
					table.insert(signs, d)
				end
			end
			t.ok(#signs > 0, zoneId .. " has an exterior sign")
			local own, unnamed = 0, {}
			for _, pad in pads do
				local seen = false
				for _, sign in signs do
					if blocked(sign, pad) <= 3 then
						seen = true
						break
					end
				end
				if seen then
					own += 1
				else
					local named = false
					for _, plate in plates[zoneId] or {} do
						if
							(plate.CFrame.Position - pad.CFrame.Position).Magnitude < 60
							and blocked(plate, pad) <= 3
						then
							named = true
							break
						end
					end
					if not named then
						table.insert(unnamed, ("%.0f"):format(pad.CFrame.Position.X))
					end
				end
			end
			t.metric("sign in view: " .. zoneId, ("%d/%d pads"):format(own, #pads))
			t.ge(own, 6, zoneId .. " sign in view from 6+ spawn pads")
			t.eq(
				#unnamed,
				0,
				zoneId
					.. " named in view from every pad"
					.. (if #unnamed > 0 then " (pads at x " .. table.concat(unnamed, ", ") .. ")" else "")
			)
		end
	end)

	test("hall of commanders: nothing stands between a reader and any board", function(t)
		local boards = {}
		for _, d in root.Zones.Leaderboards:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "BoardScreen" then
				table.insert(boards, d)
			end
		end
		t.eq(#boards, 5, "boards")
		-- a player's eye 5.5 above the ground at eight reading spots:
		-- straight out at 6 to 24 studs and to the sides at 30 and 40 degrees
		local spots = { { 6, 0 }, { 10, 0 }, { 16, 0 }, { 24, 0 }, { 10, 30 }, { 10, -30 }, { 18, 40 }, { 18, -40 } }
		for _, board in boards do
			local cf = board.CFrame
			local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
			local side = Vector3.new(-flat.Z, 0, flat.X)
			local blocked, blockers = 0, {}
			for _, spot in spots do
				local a = math.rad(spot[2])
				local base = cf.Position + (flat * math.cos(a) + side * math.sin(a)) * spot[1]
				local floorHit, ft =
					Geometry.raycast(grid, Vector3.new(base.X, cf.Position.Y, base.Z), Vector3.new(0, -30, 0))
				local eye = Vector3.new(base.X, (if floorHit then cf.Position.Y - 30 * ft else 0) + 5.5, base.Z)
				for _, p in faceSamples(board, 0.02) do
					local hit = Geometry.raycast(grid, eye, p - eye)
					if hit and hit ~= board then
						blocked += 1
						blockers[hit.Name] = true
					end
				end
			end
			local names = listed(blockers)
			t.eq(
				blocked,
				0,
				board.Parent.Name
					.. " clear from 8 reading spots"
					.. (if #names > 0 then " (" .. table.concat(names, ", ") .. ")" else "")
			)
		end
	end)

	test("operations hall: nothing hides the command wall from the doorway", function(t)
		local wall = root.Zones.OperationsCenter.Stations.CommandWall
		-- the third-person camera behind a player in the doorway sees all of
		-- both panels
		local camera = Vector3.new(0, 10, -70)
		local covered, by = 0, {}
		for _, panel in wall:GetDescendants() do
			if panel:IsA("BasePart") and panel:FindFirstChildOfClass("SurfaceGui") then
				for _, p in faceSamples(panel, 0.02) do
					local hit = Geometry.raycast(grid, camera, p - camera)
					if hit and hit ~= panel and not hit:IsDescendantOf(wall) then
						covered += 1
						by[Audit.path(root, hit)] = true
					end
				end
			end
		end
		local names = listed(by)
		t.eq(
			covered,
			0,
			"display in full view of the doorway camera"
				.. (if #names > 0 then " (" .. table.concat(names, "; ") .. ")" else "")
		)
		-- a first-person eye just inside the door reads every line of the
		-- deployment board over the desks' CRTs
		local eye = Vector3.new(0, 6.5, -78)
		local board = wall:FindFirstChild("DeploymentBoard")
		local gui = board and board:FindFirstChildOfClass("SurfaceGui")
		t.ok(gui ~= nil, "deployment board found")
		local lines, hidden = 0, {}
		for _, label in gui:GetDescendants() do
			if label:IsA("TextLabel") then
				lines += 1
				local x0, y0, w, h = Audit.labelRect(label, gui)
				for i = 0, 4 do
					for j = 0, 2 do
						local p = Audit.facePoint(
							board,
							"Front",
							x0 + w * (0.1 + 0.8 * i / 4),
							y0 + h * (0.2 + 0.6 * j / 2),
							0.02
						)
						local hit = Geometry.raycast(grid, eye, p - eye)
						if hit and hit ~= board then
							hidden[label.Name] = true
						end
					end
				end
			end
		end
		t.ge(lines, 12, "board lines")
		local list = listed(hidden)
		t.eq(
			#list,
			0,
			"board lines in view at the door" .. (if #list > 0 then " (" .. table.concat(list, ", ") .. ")" else "")
		)
	end)

	test("mounted signs: plates, boards and signs on a surface sit flush on it", function(t)
		-- every sign (front-face text, at most 0.4 deep) whose back is fully
		-- covered by a surface (all 15 rays from it meet one within 0.4) must
		-- touch it: gap at most 0.03. Pinned papers stand off the cork by
		-- design, and a flat sign on a curved tank stands off at its edges.
		local mounted, loose = 0, {}
		for _, gui in root:GetDescendants() do
			local part = gui.Parent
			if
				gui:IsA("SurfaceGui")
				and gui.Face.Name == "Front"
				and part
				and part:IsA("BasePart")
				and part.Size.Z <= 0.4
				and part.Parent.Name ~= "Documents"
			then
				local cf, size = part.CFrame, part.Size
				local worst, backed, curved = -1, 0, false
				for i = 0, 4 do
					for j = 0, 2 do
						local from = (cf * CFrame.new(
							(i / 4 - 0.5) * size.X * 0.9,
							(j / 2 - 0.5) * size.Y * 0.8,
							size.Z / 2 - 0.05
						)).Position
						local hit, ft = Geometry.raycast(grid, from, -cf.LookVector * 0.4, function(q)
							return q == part
						end)
						if hit then
							backed += 1
							worst = math.max(worst, ft * 0.4 - 0.05)
							local shape = Geometry.shape(hit)
							curved = curved or shape == "Cylinder" or shape == "Ball"
						end
					end
				end
				if backed == 15 and not curved then
					mounted += 1
					if worst > 0.03 then
						table.insert(loose, ("%s (gap %.3f)"):format(Audit.path(root, part), worst))
					end
				end
			end
		end
		t.metric("wall-mounted signs", mounted)
		t.ge(mounted, 40, "wall-mounted signs checked")
		for i = 1, math.min(#loose, 10) do
			t.ok(false, "stands off its wall: " .. loose[i])
		end
		t.eq(#loose, 0, "signs standing off their surface")
	end)
end
