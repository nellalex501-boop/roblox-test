--!nocheck
-- RELEASE: the baked place (dist/ColdWarLobby.rbxl, `lune run
-- tools/bake.luau`) must match the current source and boot cleanly: the
-- server reuses the baked lobby instead of rebuilding it and a client
-- starts its UI on it. The insert kit (dist/InsertKit, one model file per
-- service) must do the same when it is inserted into an existing place
-- such as a fresh Baseplate place, even if Studio drops the lobby at an
-- offset.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Bridge = require("../lib/Bridge")
local Runtime = require("../harness/Runtime")
local Kit = require("../../tools/kit")

local Scheduler = Runtime.Scheduler
local DIST = "dist/ColdWarLobby.rbxl"
local KIT_PLACE = "build/kit-place.rbxl"
-- how far Studio might lift or move a pasted/inserted lobby
local SHIFT = roblox.CFrame.new(37.5, 4, -12.25)

local function scripts(game)
	local out = {}
	for _, service in { "ServerScriptService", "ReplicatedStorage", "StarterPlayer" } do
		for _, d in game:GetService(service):GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				out[d:GetFullName()] = d.Source
			end
		end
	end
	return out
end

-- Scripts that differ between two places (by full name).
local function staleScripts(expected, actual)
	local a, b = scripts(expected), scripts(actual)
	local stale = {}
	for name, source in a do
		if b[name] ~= source then
			table.insert(stale, name)
		end
	end
	for name in b do
		if a[name] == nil then
			table.insert(stale, name .. " (removed)")
		end
	end
	return stale
end

-- A new place from Studio's Baseplate template: baseplate (top at y = 0),
-- a spawn at the origin and the default StarterPlayer settings.
local function templatePlace()
	local game = roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local camera = roblox.Instance.new("Camera")
	camera.Parent = workspace
	workspace.CurrentCamera = camera
	local baseplate = roblox.Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Size = roblox.Vector3.new(2048, 16, 2048)
	baseplate.CFrame = roblox.CFrame.new(0, -8, 0)
	baseplate.Anchored = true
	baseplate.Locked = true
	baseplate.Parent = workspace
	local spawn = roblox.Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = roblox.Vector3.new(12, 1, 12)
	spawn.CFrame = roblox.CFrame.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.Parent = workspace
	for _, service in
		{ "Players", "Lighting", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui" }
	do
		game:GetService(service)
	end
	local starter = game:GetService("StarterPlayer")
	for _, class in { "StarterPlayerScripts", "StarterCharacterScripts" } do
		local folder = roblox.Instance.new(class)
		folder.Name = class
		folder.Parent = starter
	end
	return game
end

-- Emulates Insert from File for every kit file; the world lands moved by
-- `shift` (as Studio may do when the lobby overlaps existing parts).
local function installKit(game, shift)
	for _, entry in Kit.Files do
		local roots = roblox.deserializeModel(fs.readFile(Kit.Dir .. "/" .. entry.file))
		local parent = Kit.resolve(game, entry.into)
		for _, root in roots do
			if shift and root.Name == "ColdWarLobby" then
				for _, d in root:GetDescendants() do
					if d:IsA("BasePart") then
						d.CFrame = shift * d.CFrame
					end
				end
			end
			root.Parent = parent
		end
	end
end

local kitPlaceWritten = false
local function kitPlace()
	if not kitPlaceWritten then
		local game = templatePlace()
		installKit(game, SHIFT)
		fs.writeFile(KIT_PLACE, roblox.serializePlace(game))
		kitPlaceWritten = true
	end
	return KIT_PLACE
end

local function firstSpawnPad(lobby)
	for _, d in lobby:GetDescendants() do
		if d:IsA("SpawnLocation") then
			return d
		end
	end
	return nil
end

return function(test)
	test("baked place exists and matches the current source", function(t)
		t.ok(fs.isFile(DIST), DIST .. " exists")
		local built = roblox.deserializePlace(fs.readFile("build/lobby.rbxl"))
		local baked = roblox.deserializePlace(fs.readFile(DIST))
		local stale = staleScripts(built, baked)
		t.ok(
			#stale == 0,
			("scripts up to date — run `lune run tools/bake.luau` (%d stale)"):format(#stale)
				.. (stale[1] and ": " .. stale[1] or "")
		)
		local lobby = baked.Workspace:FindFirstChild("ColdWarLobby")
		local rt = Runtime.new({ place = "build/lobby.rbxl" })
		local Builder = rt:requirePath("ServerScriptService.LobbyServer.World.Builder")
		t.eq(lobby and lobby:GetAttribute("LobbyVersion"), Builder.Version, "baked lobby version")
		t.ok(lobby and lobby:FindFirstChild("Details") ~= nil, "detailing baked in")
		local origin = lobby and lobby:FindFirstChild(Builder.OriginName)
		t.ok(origin and origin.CFrame.Position.Magnitude < 0.001, "origin marker at the world origin")
		t.ok(origin and origin.Transparency == 1 and not origin.CanCollide, "origin marker invisible, no collision")
		t.le(#fs.readFile(DIST), 20 * 1024 * 1024, "place file size")
		t.ok(baked.Workspace:FindFirstChild("Baseplate") == nil, "no template baseplate")
		local starter = baked:GetService("StarterPlayer")
		t.eq(starter.CameraMaxZoomDistance, 55, "camera zoom limit")
		t.eq(starter.CharacterWalkSpeed, 16, "walk speed")
		local lighting = baked:GetService("Lighting")
		t.eq(lighting.Technology, roblox.Enum.Technology.ShadowMap, "lighting technology")
		t.ok(math.abs(lighting.ClockTime - 15.6) < 0.01, "lobby time of day applied")
	end)

	test("server boots on the baked place and reuses its lobby", function(t)
		local rt = Runtime.new({ place = DIST, studio = true })
		local before = rt.workspace:FindFirstChild("ColdWarLobby")
		before:SetAttribute("BakedMarker", true)
		rt:runScript(rt:find("ServerScriptService.LobbyServer"))
		Scheduler.advance(1)
		local lobby = rt.workspace:FindFirstChild("ColdWarLobby")
		t.eq(lobby and lobby:GetAttribute("BakedMarker"), true, "baked lobby reused (not rebuilt)")
		t.eq(lobby and lobby:GetAttribute("LobbyReady"), true, "services started")
		local player = rt:addPlayer("Tester")
		rt:spawnCharacter(player)
		Scheduler.advance(1)
		t.ok(rt:lastClientMessage(player, "ProfileChanged") ~= nil, "a commander can join")
		t.noRuntimeErrors()
	end)

	test("client starts its UI on the baked place", function(t)
		local ctx = Bridge.boot({ place = DIST })
		t.ok(ctx.gui() ~= nil, "LobbyUI on the client")
		ctx.use("Missions")
		t.eq(ctx.current(), "Missions", "mission board opens")
		t.eq(ctx.player.CameraMaxZoomDistance, 55, "camera zoom limit")
		t.noRuntimeErrors()
	end)

	test("insert kit files match the baked place and the source", function(t)
		local baked = roblox.deserializePlace(fs.readFile(DIST))
		local installed = templatePlace()
		for _, entry in Kit.Files do
			local path = Kit.Dir .. "/" .. entry.file
			t.ok(fs.isFile(path), path .. " exists")
			local roots = fs.isFile(path) and roblox.deserializeModel(fs.readFile(path)) or {}
			t.eq(#roots, 1, entry.file .. ": one root instance")
			local root = roots[1]
			local parent = Kit.resolve(baked, entry.into)
			local original = parent and parent:FindFirstChild(entry.name)
			t.eq(root and root.Name, entry.name, entry.file .. ": root name")
			t.eq(root and root.ClassName, original and original.ClassName, entry.file .. ": root class")
			t.eq(
				root and #root:GetDescendants(),
				original and #original:GetDescendants(),
				entry.file .. ": same contents as the baked place"
			)
			if root then
				root.Parent = Kit.resolve(installed, entry.into)
			end
		end
		local built = roblox.deserializePlace(fs.readFile("build/lobby.rbxl"))
		local stale = staleScripts(built, installed)
		t.ok(
			#stale == 0,
			("kit scripts up to date — run `lune run tools/bake.luau` (%d stale)"):format(#stale)
				.. (stale[1] and ": " .. stale[1] or "")
		)
		t.eq(
			installed.Workspace.ColdWarLobby:GetAttribute("LobbyVersion"),
			baked.Workspace.ColdWarLobby:GetAttribute("LobbyVersion"),
			"kit lobby version"
		)
	end)

	test("insert kit boots in a Baseplate place, even when the lobby lands shifted", function(t)
		local rt = Runtime.new({ place = kitPlace(), studio = true })
		local before = rt.workspace:FindFirstChild("ColdWarLobby")
		before:SetAttribute("BakedMarker", true)
		local baked = roblox.deserializePlace(fs.readFile(DIST))
		local expectedPad = firstSpawnPad(baked.Workspace.ColdWarLobby)
		local shiftedPad = firstSpawnPad(before)
		t.ok(
			(shiftedPad.CFrame.Position - expectedPad.CFrame.Position).Magnitude > 10,
			"inserted lobby starts shifted (as Studio may place it)"
		)
		rt:runScript(rt:find("ServerScriptService.LobbyServer"))
		Scheduler.advance(1)
		local lobby = rt.workspace:FindFirstChild("ColdWarLobby")
		t.eq(lobby and lobby:GetAttribute("BakedMarker"), true, "inserted lobby reused (not rebuilt)")
		t.eq(lobby and lobby:GetAttribute("LobbyReady"), true, "services started")
		local displaced = rt.game:GetService("ServerStorage"):FindFirstChild("LobbyDisplacedTemplate")
		t.ok(
			displaced ~= nil
				and displaced:FindFirstChild("Baseplate") ~= nil
				and displaced:FindFirstChild("SpawnLocation") ~= nil,
			"template Baseplate and SpawnLocation moved aside"
		)
		local origin = lobby and lobby:FindFirstChild("LobbyOrigin")
		t.ok(origin and origin.CFrame.Position.Magnitude < 0.01, "lobby moved back to the world origin")
		local pad = lobby and firstSpawnPad(lobby)
		t.ok(
			pad and (pad.CFrame.Position - expectedPad.CFrame.Position).Magnitude < 0.01,
			"spawn pads back at their baked position"
		)
		local player = rt:addPlayer("Tester")
		rt:spawnCharacter(player)
		Scheduler.advance(1)
		t.ok(rt:lastClientMessage(player, "ProfileChanged") ~= nil, "a commander can join")
		t.noRuntimeErrors()
	end)

	test("client starts on the insert kit with the lobby's camera limit", function(t)
		local place = kitPlace()
		t.eq(
			roblox.deserializePlace(fs.readFile(place)).StarterPlayer.CameraMaxZoomDistance,
			400,
			"place keeps the default zoom limit"
		)
		local ctx = Bridge.boot({ place = place })
		t.ok(ctx.gui() ~= nil, "LobbyUI on the client")
		t.eq(ctx.player.CameraMaxZoomDistance, 55, "camera zoom capped by the lobby client")
		ctx.use("Missions")
		t.eq(ctx.current(), "Missions", "mission board opens")
		t.noRuntimeErrors()
	end)
end
