--!nocheck
-- Bridged server + client runtimes for UI / client integration specs: a
-- real LobbyServer and a LobbyClient connected through the remotes. The
-- client world is built with the same deterministic builder (standing in
-- for replication). `ctx` exposes helpers to walk, press prompts, click
-- buttons, press keys and capture screens for the preview renderer.

local roblox = require("@lune/roblox")

local GuiExport = require("./GuiExport")
local Runtime = require("../harness/Runtime")

local Scheduler = Runtime.Scheduler
local Vector2 = roblox.Vector2
local Enum = roblox.Enum

local Bridge = {}

-- Screens captured by ctx.capture (exported by the spec that owns them).
Bridge.screens = {}

function Bridge.run(fn, maxSeconds)
	local done, result = false, nil
	Scheduler.spawn(function()
		result = table.pack(fn())
		done = true
	end)
	local waited = 0
	while not done and waited < (maxSeconds or 30) do
		Scheduler.advance(0.1)
		waited += 0.1
	end
	assert(done, "call did not complete")
	return table.unpack(result, 1, result.n)
end

local function bootServer(options)
	local server = Runtime.new({ place = options.place or "build/lobby.rbxl", studio = true, epoch = options.epoch })
	server:runScript(server:find("ServerScriptService.LobbyServer"))
	Scheduler.advance(0.5)
	return server
end

-- Server + one bridged client. Returns a context table.
function Bridge.boot(options)
	options = options or {}
	local server = bootServer(options)
	local name = options.name or "Pilot"
	local userId = options.userId or 5001
	local serverPlayer = server:addPlayer(name, userId)
	server:spawnCharacter(serverPlayer)
	Scheduler.advance(1)
	local client = Runtime.new({
		place = options.place or "build/lobby.rbxl",
		context = "client",
		touch = options.touch,
		viewport = options.viewport or Vector2.new(1280, 720),
		epoch = options.epoch,
	})
	-- "replicate" the world, remotes and preview models
	if not client.workspace:FindFirstChild("ColdWarLobby") then
		local Builder = client:requirePath("ServerScriptService.LobbyServer.World.Builder")
		Builder.Build({ Parent = client.workspace, SkipLighting = true })
	end
	local lobby = client:find("ReplicatedStorage.Lobby")
	local remotes = roblox.Instance.new("Folder")
	remotes.Name = "Remotes"
	for _, remote in server:find("ReplicatedStorage.Lobby.Remotes"):GetChildren() do
		local copy = roblox.Instance.new(remote.ClassName)
		copy.Name = remote.Name
		copy.Parent = remotes
	end
	remotes.Parent = lobby
	client:requirePath("ServerScriptService.LobbyServer.Services.GarageService").buildPreviews()
	local clientPlayer = client:setLocalPlayer(name, userId)
	client:spawnCharacter(clientPlayer, serverPlayer.Character.HumanoidRootPart.CFrame)
	server:bridgeClient(client, serverPlayer)
	client:runScript(client:find("StarterPlayer.StarterPlayerScripts.LobbyClient"))
	Scheduler.advance(2)
	local ctx = { server = server, client = client, serverPlayer = serverPlayer, player = clientPlayer }
	function ctx.module(path)
		return client:requirePath("StarterPlayer.StarterPlayerScripts.LobbyClient." .. path)
	end
	function ctx.serverModule(path)
		return server:requirePath("ServerScriptService.LobbyServer." .. path)
	end
	function ctx.profile()
		return ctx.serverModule("Services.CommanderService").get(serverPlayer)
	end
	function ctx.move(position)
		client:moveCharacter(clientPlayer, position)
		server:moveCharacter(serverPlayer, position)
	end
	function ctx.gui()
		return clientPlayer.PlayerGui:FindFirstChild("LobbyUI")
	end
	function ctx.find(name, root)
		local found = (root or ctx.gui()):FindFirstChild(name, true)
		return found
	end
	function ctx.findVisible(name)
		for _, d in ctx.gui():GetDescendants() do
			if d.Name == name then
				local visible = true
				local node = d
				while node and node:IsA("GuiObject") do
					if not node.Visible then
						visible = false
					end
					node = node.Parent
				end
				if visible then
					return d
				end
			end
		end
		return nil
	end
	function ctx.click(name)
		local button = ctx.findVisible(name)
		assert(button, "no visible button " .. name)
		Bridge.run(function()
			Runtime.signalFor(button, "Activated"):Fire()
		end)
		Scheduler.advance(0.5)
		return button
	end
	function ctx.key(keyCode)
		local uis = client.game:GetService("UserInputService")
		Runtime.signalFor(uis, "InputBegan")
			:Fire({ KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard }, false)
		Scheduler.advance(0.4)
	end
	function ctx.prompt(kind, id)
		for _, d in client.workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "LobbyPrompt" then
				local part = d.Parent
				if
					part:GetAttribute("InteractionKind") == kind
					and (id == nil or part:GetAttribute("InteractionId") == id)
				then
					return d
				end
			end
		end
		error(("no client prompt %s %s"):format(kind, tostring(id)))
	end
	-- walk to a station and press its prompt
	function ctx.use(kind, id)
		local prompt = ctx.prompt(kind, id)
		ctx.move(prompt.Parent.CFrame.Position)
		client:triggerPrompt(prompt, clientPlayer)
		Scheduler.advance(1)
		return prompt
	end
	function ctx.current()
		return ctx.module("UI.WindowManager").current()
	end
	function ctx.capture(screenName, background)
		table.insert(Bridge.screens, {
			name = screenName,
			w = math.floor(client.viewport.X),
			h = math.floor(client.viewport.Y),
			background = background,
			tree = GuiExport.node(ctx.gui()),
		})
	end
	function ctx.text(name)
		local label = ctx.findVisible(name)
		return label and label.Text
	end
	return ctx
end

return Bridge
