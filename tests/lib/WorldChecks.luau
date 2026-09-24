--!nocheck
-- Reusable world analysis: build the lobby headlessly, measure navigation,
-- sightlines, spawn safety, scale and render cost, and export geometry for
-- the preview renderer. Used by the blockout, architecture and detailing
-- specs so every phase is regression-tested with the same measurements.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local GuiExport = require("./GuiExport")
local Nav = require("./Nav")
local Runtime = require("../harness/Runtime")

local Vector3 = roblox.Vector3

local WorldChecks = {}

function WorldChecks.build(mode: string)
	local runtime = Runtime.new({ place = "build/lobby.rbxl", context = "server" })
	local Builder = runtime:requirePath("ServerScriptService.LobbyServer.World.Builder")
	local root = Builder.Build({ Mode = mode, Parent = runtime.workspace })
	return runtime, root
end

function WorldChecks.config(runtime)
	return {
		Layout = runtime:requirePath("ReplicatedStorage.Lobby.Config.Layout"),
		Interactions = runtime:requirePath("ReplicatedStorage.Lobby.Interactions"),
	}
end

function WorldChecks.spawns(root)
	local spawns = {}
	for _, d in root:GetDescendants() do
		if d:IsA("SpawnLocation") then
			table.insert(spawns, d)
		end
	end
	return spawns
end

function WorldChecks.prompts(root)
	local prompts = {}
	for _, d in root:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			table.insert(prompts, d)
		end
	end
	return prompts
end

-- Navigation from the spawn centre to every zone entrance and prompt.
function WorldChecks.navigation(runtime, root)
	local cfg = WorldChecks.config(runtime)
	local Layout = cfg.Layout
	local bounds = {
		MinX = Layout.Perimeter.MinX - 6,
		MaxX = Layout.Perimeter.MaxX + 6,
		MinZ = Layout.Perimeter.MinZ - 6,
		MaxZ = Layout.Perimeter.MaxZ + 6,
	}
	local grid = Nav.build(root, bounds)
	local spawns = WorldChecks.spawns(root)
	assert(#spawns > 0, "no spawns")
	local start = spawns[math.ceil(#spawns / 2)].CFrame.Position + Vector3.new(0, 0.3, 0)
	local dist, _, prev = Nav.distances(grid, start)

	local destinations = {}
	for _, zoneId in Layout.ZoneOrder do
		local zone = Layout.Zones[zoneId]
		local point = Layout.entrancePoint(zone)
		local d, idx = Nav.distanceTo(grid, dist, point, 4)
		table.insert(destinations, {
			kind = "Entrance",
			id = zoneId,
			label = zone.DisplayName,
			point = { point.X, point.Z },
			studs = d,
			seconds = d and d / Nav.WALK_SPEED,
			path = idx and Nav.path(grid, prev, idx) or nil,
		})
	end
	for _, prompt in WorldChecks.prompts(root) do
		local part = prompt.Parent
		local kind, id = cfg.Interactions.describe(prompt)
		local pos = part.CFrame.Position
		-- Must be usable from a standable cell within activation range
		-- (minus a small margin for character radius).
		local reach = math.max(prompt.MaxActivationDistance - 1.5, 1)
		local d, idx = Nav.distanceTo(grid, dist, pos, reach)
		table.insert(destinations, {
			kind = kind,
			id = id,
			label = prompt.ObjectText,
			point = { pos.X, pos.Z },
			studs = d,
			seconds = d and d / Nav.WALK_SPEED,
			path = idx and Nav.path(grid, prev, idx) or nil,
		})
	end
	return {
		start = { start.X, start.Z },
		destinations = destinations,
		grid = grid,
		dist = dist,
	}
end

-- Line of sight from a third-person camera behind the spawn toward each
-- building's facade sign height.
function WorldChecks.sightlines(runtime, root)
	local Layout = WorldChecks.config(runtime).Layout
	local spawn = Layout.Spawn.Center
	local results = {}
	-- default Roblox camera: ~12 studs behind, ~4 above the head
	local eyes = {
		spawnCamera = spawn + Vector3.new(0, 9, 12),
		plazaCenter = Vector3.new(0, 9, -4),
	}
	for eyeName, eye in eyes do
		for _, zoneId in Layout.ZoneOrder do
			local zone = Layout.Zones[zoneId]
			local frame = Layout.frame(zone)
			local targetY = if zone.Kind == "Building" then math.min(zone.Height - 3, 16) else 7
			local target = (frame * roblox.CFrame.new(0, targetY, 1)).Position
			local occluders = Nav.occluders(root, eye, target, function(part)
				-- the zone's own facade/sign is the target, not an occluder
				return part:IsDescendantOf(root) and part:FindFirstAncestor(zoneId) ~= nil
			end)
			table.insert(results, {
				eye = eyeName,
				zone = zoneId,
				visible = #occluders == 0,
				occluders = #occluders,
				distance = (target - eye).Magnitude,
			})
		end
	end
	return results
end

-- Render-cost inventory.
function WorldChecks.stats(root)
	local stats = {
		parts = 0,
		collidable = 0,
		shadowCasters = 0,
		transparentParts = 0,
		touchEnabled = 0,
		unanchored = 0,
		surfaceGuis = 0,
		textLabels = 0,
		lights = 0,
		shadowLights = 0,
		particles = 0,
		sounds = 0,
		prompts = 0,
		seats = 0,
		spawns = 0,
		decals = 0,
		meshParts = 0,
	}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			stats.parts += 1
			if d.CanCollide then
				stats.collidable += 1
			end
			if d.CastShadow then
				stats.shadowCasters += 1
			end
			if d.Transparency > 0 and d.Transparency < 1 then
				stats.transparentParts += 1
			end
			if d.CanTouch then
				stats.touchEnabled += 1
			end
			if not d.Anchored then
				stats.unanchored += 1
			end
			if d:IsA("Seat") then
				stats.seats += 1
			end
			if d:IsA("SpawnLocation") then
				stats.spawns += 1
			end
			if d:IsA("MeshPart") then
				stats.meshParts += 1
			end
		elseif d:IsA("SurfaceGui") then
			stats.surfaceGuis += 1
		elseif d:IsA("TextLabel") then
			stats.textLabels += 1
		elseif d:IsA("Light") then
			stats.lights += 1
			if d.Shadows then
				stats.shadowLights += 1
			end
		elseif d:IsA("ParticleEmitter") then
			stats.particles += 1
		elseif d:IsA("Sound") then
			stats.sounds += 1
		elseif d:IsA("ProximityPrompt") then
			stats.prompts += 1
		elseif d:IsA("Decal") or d:IsA("Texture") then
			stats.decals += 1
		end
	end
	return stats
end

-- Spawn safety: each spawn has headroom and is not inside geometry.
function WorldChecks.spawnClearance(root, spawn)
	local top = spawn.CFrame.Position.Y + spawn.Size.Y / 2
	local center = spawn.CFrame.Position
	local blockers = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d ~= spawn then
			local minX, maxX, minY, maxY, minZ, maxZ = Nav.worldBounds(d)
			local overlapXZ = maxX > center.X - 1.5
				and minX < center.X + 1.5
				and maxZ > center.Z - 1.5
				and minZ < center.Z + 1.5
			local overlapY = minY < top + 5.5 and maxY > top + 0.05
			if overlapXZ and overlapY then
				table.insert(blockers, d:GetFullName())
			end
		end
	end
	return blockers
end

-- Geometry export for tools/render (three.js preview).
function WorldChecks.export(root, path: string, extra)
	local parts = {}
	local guis = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local shape = "Block"
			if d:IsA("WedgePart") then
				shape = "Wedge"
			elseif d:IsA("CornerWedgePart") then
				shape = "CornerWedge"
			elseif d:IsA("Part") then
				shape = d.Shape.Name
			end
			local cf = d.CFrame
			local c = { cf:GetComponents() }
			local col = d.Color
			table.insert(parts, {
				s = shape,
				z = { d.Size.X, d.Size.Y, d.Size.Z },
				c = c,
				k = { math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5) },
				m = d.Material.Name,
				t = d.Transparency,
				r = d.Reflectance,
				n = d.Name,
			})
		elseif d:IsA("SurfaceGui") then
			local part = d.Parent
			if part and part:IsA("BasePart") then
				table.insert(guis, { part = part:GetFullName(), face = d.Face.Name })
			end
		end
	end
	local payload = { parts = parts, extra = extra }
	fs.writeFile(path, serde.encode("json", payload))
	-- SurfaceGui trees for the renderer's texture pass
	local guiPath = path:gsub("%.json$", "-guis.json")
	fs.writeFile(guiPath, serde.encode("json", GuiExport.surfaces(root)))
	return #parts
end

return WorldChecks
