--!nocheck
-- VISUAL REVIEW — regressions for the review list: no z-fighting anywhere,
-- signs and plates readable (not covered, not cut by columns or windows,
-- text large enough), flags built from enough segments, the winter yard's
-- effects in place, and the landscape closing the view on every side.

local roblox = require("@lune/roblox")

local Geometry = require("../lib/Geometry")
local WorldChecks = require("../lib/WorldChecks")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

return function(test)
	local runtime, root = WorldChecks.build("Full")
	local grid = Geometry.index(root, function(p)
		return p.Transparency < 0.1
	end, 8)

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
		local Layout = runtime:requirePath("ReplicatedStorage.Lobby.Config.Layout")
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
end
