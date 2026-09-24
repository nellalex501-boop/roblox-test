--!nocheck
-- Bakes a ready-to-open place: Rojo-builds the project, runs the lobby
-- builder headlessly (the same code the server runs) and writes
-- dist/ColdWarLobby.rbxl with the whole base already in Workspace, so it
-- can be opened, inspected and edited in Studio without pressing Play.
-- The server reuses a baked lobby when its LobbyVersion matches.
--
--   lune run tools/bake.luau [output.rbxl]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Runtime = require("../tests/harness/Runtime")

local output = process.args[1] or "dist/ColdWarLobby.rbxl"

local build = process.exec("rojo", { "build", "default.project.json", "-o", "build/lobby.rbxl" })
if not build.ok then
	print(build.stderr)
	process.exit(1)
end

local rt = Runtime.new({ place = "build/lobby.rbxl", context = "server" })
local Builder = rt:requirePath("ServerScriptService.LobbyServer.World.Builder")
local root = Builder.Build({ Parent = rt.workspace })
Runtime.Scheduler.advance(0)
if #Runtime.Scheduler.errors > 0 then
	print("build errors:", Runtime.Scheduler.errors[1])
	process.exit(1)
end

-- empty slot for real game models (copies of Fulda Gap vehicles named by
-- unit id); Vehicles.spawn uses them instead of the procedural models
local serverStorage = rt.game:GetService("ServerStorage")
if not serverStorage:FindFirstChild("LobbyAssets") then
	local assets = roblox.Instance.new("Folder")
	assets.Name = "LobbyAssets"
	local units = roblox.Instance.new("Folder")
	units.Name = "Units"
	units.Parent = assets
	assets.Parent = serverStorage
end

-- open Studio looking at the parade square from behind the spawn pads
local camera = rt.workspace.CurrentCamera
camera.CFrame = roblox.CFrame.lookAt(roblox.Vector3.new(0, 24, 70), roblox.Vector3.new(0, 6, -20))

local parts = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end

local dir = output:match("^(.*)/[^/]+$")
if dir then
	fs.writeDir(dir)
end
local bytes = roblox.serializePlace(rt.game)
fs.writeFile(output, bytes)
print(("baked %s: lobby v%d, %d parts, %.1f MB"):format(output, Builder.Version, parts, #bytes / 1048576))
