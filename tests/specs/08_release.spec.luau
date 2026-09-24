--!nocheck
-- RELEASE: the baked place (dist/ColdWarLobby.rbxl, `lune run
-- tools/bake.luau`) must match the current source and boot cleanly: the
-- server reuses the baked lobby instead of rebuilding it and a client
-- starts its UI on it.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Bridge = require("../lib/Bridge")
local Runtime = require("../harness/Runtime")

local Scheduler = Runtime.Scheduler
local DIST = "dist/ColdWarLobby.rbxl"

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

return function(test)
	test("baked place exists and matches the current source", function(t)
		t.ok(fs.isFile(DIST), DIST .. " exists")
		local built = roblox.deserializePlace(fs.readFile("build/lobby.rbxl"))
		local baked = roblox.deserializePlace(fs.readFile(DIST))
		local a, b = scripts(built), scripts(baked)
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
		t.noRuntimeErrors()
	end)
end
