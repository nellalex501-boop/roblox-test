--!nocheck
-- Headless Roblox runtime for tests.
--
-- Loads the Rojo-built place with Lune's `roblox` library and runs the real
-- game scripts against it. Engine behaviour that Lune does not provide
-- (events, services, remotes, DataStores, tweens, time) is emulated here
-- with deterministic mocks. Everything that is emulated is listed in
-- docs/TESTING.md so results are never mistaken for in-engine runs.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Scheduler = require("./Scheduler")
local Signal = require("./Signal")
local Geometry = require("../lib/Geometry")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame
local Enum = roblox.Enum
local UDim = roblox.UDim
local UDim2 = roblox.UDim2

local Runtime = {}
Runtime.__index = Runtime

Runtime.Scheduler = Scheduler
Runtime.Signal = Signal
Runtime.DEFAULT_EPOCH = 1790251200 -- 2026-09-24 12:00:00 UTC

local runtimes = setmetatable({}, { __mode = "k" }) -- [DataModel] = runtime
-- Strong keys on purpose: Lune hands out one userdata per instance only
-- while that userdata is alive, so weak keys would silently drop signal
-- connections / callbacks / emulated properties when the GC runs.
local signals = {} -- [Instance] = { [name] = Signal }
local callbacks = {} -- [Instance] = { [name] = fn }
local extra = {} -- [Instance] = { [prop] = value }

local function rootOf(inst)
	if inst.ClassName == "DataModel" then
		return inst
	end
	return inst:FindFirstAncestorOfClass("DataModel")
end

local function runtimeOf(inst)
	local root = rootOf(inst)
	return root and runtimes[root]
end
Runtime.runtimeOf = runtimeOf

local function signalFor(inst, name: string)
	local bucket = signals[inst]
	if not bucket then
		bucket = {}
		signals[inst] = bucket
	end
	local signal = bucket[name]
	if not signal then
		signal = Signal.new(name)
		bucket[name] = signal
	end
	return signal
end
Runtime.signalFor = signalFor

local function extraGet(inst, key, default)
	local bucket = extra[inst]
	if bucket and bucket[key] ~= nil then
		return bucket[key]
	end
	return default
end

local function extraSet(inst, key, value)
	local bucket = extra[inst]
	if not bucket then
		bucket = {}
		extra[inst] = bucket
	end
	bucket[key] = value
end
Runtime.extraGet = extraGet
Runtime.extraSet = extraSet

--------------------------------------------------------------------------
-- Remote payload copy with Roblox serialisation rules. Mixed or sparse
-- tables, functions and non-string dictionary keys are errors here because
-- Roblox would silently mangle them.
--------------------------------------------------------------------------
local function remoteCopy(value, path: string, mapInstance)
	local kind = typeof(value)
	if kind == "table" then
		local count, n = 0, #value
		local hasString, hasNumber = false, false
		for key in value do
			count += 1
			local keyType = type(key)
			if keyType == "string" then
				hasString = true
			elseif keyType == "number" then
				hasNumber = true
			else
				error(("remote payload: invalid key type %s at %s"):format(keyType, path))
			end
		end
		if hasString and hasNumber then
			error("remote payload: mixed array/dictionary table at " .. path)
		end
		if hasNumber and count ~= n then
			error("remote payload: sparse array at " .. path)
		end
		if getmetatable(value) ~= nil then
			error("remote payload: table with metatable at " .. path)
		end
		local copy = {}
		for key, item in value do
			copy[key] = remoteCopy(item, path .. "." .. tostring(key), mapInstance)
		end
		return copy
	elseif kind == "function" or kind == "thread" then
		error("remote payload: cannot send " .. kind .. " at " .. path)
	elseif kind == "Instance" then
		return if mapInstance then mapInstance(value) else value
	end
	return value
end
Runtime.remoteCopy = remoteCopy

local function copyArgs(args, mapInstance)
	local out = { n = args.n }
	for i = 1, args.n do
		out[i] = remoteCopy(args[i], "arg" .. i, mapInstance)
	end
	return out
end

--------------------------------------------------------------------------
-- Data model helpers
--------------------------------------------------------------------------
local function pathOf(inst): { string }
	local names = {}
	local node = inst
	while node and node.ClassName ~= "DataModel" do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return names
end

local function findPath(game, names: { string })
	local node = game
	for i, name in names do
		if i == 1 then
			node = game:FindFirstChild(name)
		else
			node = node and node:FindFirstChild(name)
		end
	end
	return node
end
Runtime.findPath = findPath

local function descendantsWithTag(root, tag)
	local out = {}
	for _, inst in root:GetDescendants() do
		if inst:HasTag(tag) then
			table.insert(out, inst)
		end
	end
	return out
end

local function partsOf(model)
	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function boundingBox(model)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, part in partsOf(model) do
		local cf, size = part.CFrame, part.Size
		local half = size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
					minV = minV:Min(p)
					maxV = maxV:Max(p)
				end
			end
		end
	end
	if minV.X == math.huge then
		return CFrame.new(), Vector3.zero
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end
Runtime.boundingBox = boundingBox

--------------------------------------------------------------------------
-- Mock services that return plain Lua objects
--------------------------------------------------------------------------
local function jsonRoundTrip(value, what)
	local ok, encoded = pcall(serde.encode, "json", value)
	if not ok then
		error(("DataStore %s: value is not serialisable (%s)"):format(what, tostring(encoded)))
	end
	return encoded
end

local function newDataStoreBackend()
	local backend = { stores = {}, ordered = {}, unavailable = false, failNext = 0, calls = 0 }

	local function gate(what)
		backend.calls += 1
		Scheduler.wait(Scheduler.frame)
		if backend.unavailable then
			error("StudioAccessToApisNotAllowed: DataStore " .. what .. " (emulated Studio without API access)")
		end
		if backend.failNext > 0 then
			backend.failNext -= 1
			error("502: API Services rejected request (emulated transient failure)")
		end
	end

	function backend.dataStore(name, scope)
		local id = name .. "/" .. (scope or "global")
		local data = backend.stores[id]
		if not data then
			data = {}
			backend.stores[id] = data
		end
		local store = {}
		function store:GetAsync(key)
			gate("GetAsync")
			local raw = data[key]
			return if raw then serde.decode("json", raw) else nil
		end
		function store:SetAsync(key, value)
			gate("SetAsync")
			data[key] = jsonRoundTrip(value, "SetAsync")
		end
		function store:UpdateAsync(key, transform)
			gate("UpdateAsync")
			local raw = data[key]
			local old = if raw then serde.decode("json", raw) else nil
			local new = transform(old, nil)
			if new ~= nil then
				data[key] = jsonRoundTrip(new, "UpdateAsync")
			end
			return new
		end
		function store:RemoveAsync(key)
			gate("RemoveAsync")
			local raw = data[key]
			data[key] = nil
			return if raw then serde.decode("json", raw) else nil
		end
		function store:IncrementAsync(key, delta)
			gate("IncrementAsync")
			local raw = data[key]
			local value = (if raw then serde.decode("json", raw) else 0) + (delta or 1)
			data[key] = jsonRoundTrip(value, "IncrementAsync")
			return value
		end
		return store
	end

	function backend.orderedStore(name, scope)
		local id = name .. "/" .. (scope or "global")
		local data = backend.ordered[id]
		if not data then
			data = {}
			backend.ordered[id] = data
		end
		local store = {}
		function store:SetAsync(key, value)
			gate("Ordered.SetAsync")
			assert(type(value) == "number" and value == math.floor(value), "OrderedDataStore values must be integers")
			data[tostring(key)] = value
		end
		function store:GetAsync(key)
			gate("Ordered.GetAsync")
			return data[tostring(key)]
		end
		function store:UpdateAsync(key, transform)
			gate("Ordered.UpdateAsync")
			local new = transform(data[tostring(key)], nil)
			if new ~= nil then
				data[tostring(key)] = new
			end
			return new
		end
		function store:GetSortedAsync(ascending, pageSize)
			gate("Ordered.GetSortedAsync")
			local entries = {}
			for key, value in data do
				table.insert(entries, { key = key, value = value })
			end
			table.sort(entries, function(a, b)
				if a.value == b.value then
					return a.key < b.key
				end
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local pageIndex = 0
			local pages = { IsFinished = false }
			function pages:GetCurrentPage()
				local out = {}
				for i = pageIndex * pageSize + 1, math.min(#entries, (pageIndex + 1) * pageSize) do
					table.insert(out, { key = entries[i].key, value = entries[i].value })
				end
				return out
			end
			function pages:AdvanceToNextPageAsync()
				pageIndex += 1
				pages.IsFinished = pageIndex * pageSize >= #entries
			end
			pages.IsFinished = pageSize >= #entries
			return pages
		end
		return store
	end

	return backend
end
Runtime.newDataStoreBackend = newDataStoreBackend

local TweenInfo = {}
TweenInfo.__index = TweenInfo
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return setmetatable({
		Time = time or 1,
		EasingStyle = style or Enum.EasingStyle.Quad,
		EasingDirection = direction or Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}, TweenInfo)
end

-- Easing (subset of Enum.EasingStyle) for the emulated tweens.
local EASE = {
	Linear = function(t)
		return t
	end,
	Quad = function(t)
		return t * t
	end,
	Cubic = function(t)
		return t * t * t
	end,
	Sine = function(t)
		return 1 - math.cos(t * math.pi / 2)
	end,
	Back = function(t)
		local s = 1.70158
		return t * t * ((s + 1) * t - s)
	end,
}

local function eased(info, alpha)
	local style = EASE[info.EasingStyle and info.EasingStyle.Name] or EASE.Quad
	local direction = info.EasingDirection and info.EasingDirection.Name or "Out"
	if direction == "In" then
		return style(alpha)
	elseif direction == "InOut" then
		if alpha < 0.5 then
			return style(alpha * 2) / 2
		end
		return 1 - style((1 - alpha) * 2) / 2
	end
	return 1 - style(1 - alpha)
end

local function lerp(a, b, t)
	local kind = typeof(b)
	if kind == "number" then
		return a + (b - a) * t
	elseif kind == "UDim2" then
		return UDim2.new(
			a.X.Scale + (b.X.Scale - a.X.Scale) * t,
			a.X.Offset + (b.X.Offset - a.X.Offset) * t,
			a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
			a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
		)
	elseif kind == "UDim" then
		return UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t)
	elseif kind == "Color3" or kind == "Vector3" or kind == "Vector2" or kind == "CFrame" then
		return a:Lerp(b, t)
	end
	return if t >= 1 then b else a
end

-- Tweens interpolate on the virtual clock (one step per frame) so specs can
-- observe transitions; Completed fires when the goal is reached.
local function newTween(instance, info, goals)
	local tween = { Instance = instance, TweenInfo = info, PlaybackState = Enum.PlaybackState.Begin }
	tween.Completed = Signal.new("Completed")
	local token = 0
	function tween:Play()
		token += 1
		local mine = token
		tween.PlaybackState = Enum.PlaybackState.Playing
		local starts = {}
		for key in goals do
			starts[key] = instance[key]
		end
		local duration = math.max(info.Time or 0, 0)
		Scheduler.spawn(function()
			if (info.DelayTime or 0) > 0 then
				Scheduler.wait(info.DelayTime)
			end
			local elapsed = 0
			while elapsed < duration do
				if token ~= mine then
					return
				end
				elapsed += Scheduler.wait(Scheduler.frame)
				local alpha = eased(info, math.clamp(elapsed / duration, 0, 1))
				for key, goal in goals do
					pcall(function()
						instance[key] = lerp(starts[key], goal, alpha)
					end)
				end
			end
			if token ~= mine then
				return
			end
			for key, goal in goals do
				pcall(function()
					instance[key] = goal
				end)
			end
			tween.PlaybackState = Enum.PlaybackState.Completed
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween:Cancel()
		token += 1
		tween.PlaybackState = Enum.PlaybackState.Cancelled
	end
	function tween:Pause()
		token += 1
		tween.PlaybackState = Enum.PlaybackState.Paused
	end
	function tween:Destroy() end
	return tween
end

local Random = {}
Random.__index = Random
function Random.new(seed)
	local self = setmetatable({ state = math.floor(seed or 1234567) % 2147483647 }, Random)
	if self.state <= 0 then
		self.state += 2147483646
	end
	return self
end
function Random:_next()
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(min, max)
	min = min or 0
	max = max or 1
	return min + (max - min) * self:_next()
end
function Random:NextInteger(min, max)
	return math.floor(min + (max - min + 1) * self:_next())
end
function Random:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function Random:Clone()
	return setmetatable({ state = self.state }, Random)
end

-- Roblox semantics: LookVector points at target, RightVector = Look x Up.
function Runtime.lookAt(at, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = target - at
	if look.Magnitude < 1e-9 then
		return CFrame.new(at)
	end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.new(0, 0, if look.Y > 0 then 1 else -1))
	end
	right = right.Unit
	local realUp = right:Cross(look).Unit
	return CFrame.fromMatrix(at, right, realUp, -look)
end

--------------------------------------------------------------------------
-- Global engine shims (installed once per process)
--------------------------------------------------------------------------
local installed = false

local EVENTS = {
	Instance = {
		"ChildAdded",
		"ChildRemoved",
		"DescendantAdded",
		"DescendantRemoving",
		"AncestryChanged",
		"Destroying",
		"Changed",
		"AttributeChanged",
	},
	Players = { "PlayerAdded", "PlayerRemoving", "PlayerMembershipChanged" },
	Player = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled" },
	Humanoid = { "Died", "Running", "StateChanged", "HealthChanged", "Seated", "MoveToFinished" },
	RunService = {
		"Heartbeat",
		"RenderStepped",
		"Stepped",
		"PreRender",
		"PreSimulation",
		"PostSimulation",
		"PreAnimation",
	},
	ProximityPromptService = {
		"PromptTriggered",
		"PromptTriggerEnded",
		"PromptShown",
		"PromptHidden",
		"PromptButtonHoldBegan",
		"PromptButtonHoldEnded",
	},
	ProximityPrompt = {
		"Triggered",
		"TriggerEnded",
		"PromptShown",
		"PromptHidden",
		"PromptButtonHoldBegan",
		"PromptButtonHoldEnded",
	},
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	UnreliableRemoteEvent = { "OnServerEvent", "OnClientEvent" },
	BindableEvent = { "Event" },
	GuiButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click" },
	GuiObject = {
		"MouseEnter",
		"MouseLeave",
		"MouseMoved",
		"InputBegan",
		"InputEnded",
		"InputChanged",
		"SelectionGained",
		"SelectionLost",
		"TouchTap",
	},
	TextBox = { "FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard" },
	UserInputService = {
		"InputBegan",
		"InputEnded",
		"InputChanged",
		"LastInputTypeChanged",
		"TouchStarted",
		"TouchEnded",
		"TouchMoved",
		"TouchTap",
		"TouchPinch",
		"TouchPan",
		"JumpRequest",
		"WindowFocused",
		"WindowFocusReleased",
	},
	GuiService = { "MenuOpened", "MenuClosed" },
	Sound = { "Ended", "Played", "Paused", "Resumed", "Stopped", "Loaded", "DidLoop" },
	BasePart = { "Touched", "TouchEnded" },
	TeleportService = { "TeleportInitFailed", "LocalPlayerArrivedFromTeleport" },
	CollectionService = { "TagAdded", "TagRemoved" },
	Lighting = { "LightingChanged" },
}

local function install()
	if installed then
		return
	end
	installed = true

	for className, names in EVENTS do
		for _, name in names do
			roblox.implementProperty(className, name, function(self)
				return signalFor(self, name)
			end)
		end
	end

	-- Callback members
	for _, spec in
		{
			{ "RemoteFunction", "OnServerInvoke" },
			{ "RemoteFunction", "OnClientInvoke" },
			{ "BindableFunction", "OnInvoke" },
		}
	do
		local className, name = spec[1], spec[2]
		roblox.implementProperty(className, name, function(self)
			return callbacks[self] and callbacks[self][name]
		end, function(self, fn)
			callbacks[self] = callbacks[self] or {}
			callbacks[self][name] = fn
		end)
	end

	-- NOTE: Lune only consults implementProperty for members it has no
	-- stored/default value for, so DB-backed properties such as
	-- BasePart.Position or Humanoid.Health cannot be emulated. Game code
	-- reads CFrame.Position instead (documented in docs/TESTING.md).
	roblox.implementProperty("BasePart", "AssemblyLinearVelocity", function(self)
		return extraGet(self, "AssemblyLinearVelocity", Vector3.zero)
	end, function(self, value)
		extraSet(self, "AssemblyLinearVelocity", value)
	end)
	roblox.implementProperty("Attachment", "WorldPosition", function(self)
		local parent = self.Parent
		local base = if parent and parent:IsA("BasePart") then parent.CFrame else CFrame.new()
		return (base * self.CFrame).Position
	end)
	roblox.implementProperty("Attachment", "WorldCFrame", function(self)
		local parent = self.Parent
		local base = if parent and parent:IsA("BasePart") then parent.CFrame else CFrame.new()
		return base * self.CFrame
	end)
	roblox.implementProperty("Humanoid", "Health", function(self)
		return extraGet(self, "Health", 100)
	end, function(self, value)
		extraSet(self, "Health", value)
	end)
	roblox.implementProperty("Humanoid", "MaxHealth", function(self)
		return extraGet(self, "MaxHealth", 100)
	end, function(self, value)
		extraSet(self, "MaxHealth", value)
	end)
	roblox.implementProperty("Humanoid", "RootPart", function(self)
		local character = self.Parent
		return character and character:FindFirstChild("HumanoidRootPart")
	end)
	roblox.implementProperty("Humanoid", "SeatPart", function(self)
		return extraGet(self, "SeatPart", nil)
	end)
	roblox.implementProperty("Seat", "Occupant", function(self)
		return extraGet(self, "Occupant", nil)
	end)
	roblox.implementProperty("WeldConstraint", "Enabled", function(self)
		return extraGet(self, "Enabled", true)
	end, function(self, value)
		extraSet(self, "Enabled", value)
	end)
	roblox.implementProperty("Sound", "IsPlaying", function(self)
		return extraGet(self, "IsPlaying", false)
	end)
	roblox.implementProperty("Sound", "IsLoaded", function()
		return true
	end)
	roblox.implementProperty("Sound", "TimeLength", function()
		return 30
	end)
	for _, name in { "TouchEnabled", "KeyboardEnabled", "MouseEnabled", "GamepadEnabled" } do
		roblox.implementProperty("UserInputService", name, function(self)
			local rt = runtimeOf(self)
			return rt and rt.input[name] or false
		end)
	end
	roblox.implementProperty("UserInputService", "MouseBehavior", function(self)
		return extraGet(self, "MouseBehavior", Enum.MouseBehavior.Default)
	end, function(self, value)
		extraSet(self, "MouseBehavior", value)
	end)
	roblox.implementProperty("GuiService", "MenuIsOpen", function()
		return false
	end)
	roblox.implementProperty("Camera", "ViewportSize", function(self)
		local rt = runtimeOf(self)
		return rt and rt.viewport or Vector2.new(1280, 720)
	end)
	roblox.implementProperty("GuiBase2d", "AbsoluteSize", function(self)
		local rt = runtimeOf(self)
		return rt and rt.viewport or Vector2.new(1280, 720)
	end)
	roblox.implementProperty("GuiBase2d", "AbsolutePosition", function()
		return Vector2.zero
	end)
	roblox.implementProperty("Player", "Character", function(self)
		return extraGet(self, "Character", nil)
	end, function(self, value)
		extraSet(self, "Character", value)
	end)
	roblox.implementProperty("Player", "AccountAge", function()
		return 365
	end)
	roblox.implementProperty("Players", "LocalPlayer", function(self)
		return extraGet(self, "LocalPlayer", nil)
	end, function(self, value)
		extraSet(self, "LocalPlayer", value)
	end)
	roblox.implementProperty("Workspace", "CurrentCamera", function(self)
		return extraGet(self, "CurrentCamera", nil)
	end, function(self, value)
		extraSet(self, "CurrentCamera", value)
	end)
	roblox.implementProperty("Workspace", "DistributedGameTime", function()
		return Scheduler.now
	end)

	-- Instance methods
	roblox.implementMethod("Instance", "WaitForChild", function(self, name, timeout)
		local child = self:FindFirstChild(name)
		local waited = 0
		local limit = timeout or 30
		while not child do
			if waited >= limit then
				if timeout then
					return nil
				end
				error(("Infinite yield: %s:WaitForChild(%q) (emulated 30 s limit)"):format(self:GetFullName(), name))
			end
			waited += Scheduler.wait(0.05)
			child = self:FindFirstChild(name)
		end
		return child
	end)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, property)
		return signalFor(self, "Changed:" .. property)
	end)
	roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, attribute)
		return signalFor(self, "AttributeChanged:" .. attribute)
	end)
	local debugIds = {}
	local nextId = 0
	roblox.implementMethod("Instance", "GetDebugId", function(self)
		if not debugIds[self] then
			nextId += 1
			debugIds[self] = "RBX" .. tostring(nextId)
		end
		return debugIds[self]
	end)

	-- Pivots and bounding boxes
	local function getPivot(self)
		if self:IsA("BasePart") then
			return self.CFrame
		end
		local primary = self.PrimaryPart
		if primary then
			return primary.CFrame
		end
		local stored = extraGet(self, "WorldPivot", nil)
		if stored then
			return stored
		end
		local cf = boundingBox(self)
		return cf
	end
	local function pivotTo(self, target)
		local current = getPivot(self)
		local delta = target * current:Inverse()
		for _, part in partsOf(self) do
			part.CFrame = delta * part.CFrame
		end
		if not self:IsA("BasePart") and extraGet(self, "WorldPivot", nil) then
			extraSet(self, "WorldPivot", target)
		end
	end
	roblox.implementMethod("PVInstance", "GetPivot", getPivot)
	roblox.implementMethod("PVInstance", "PivotTo", pivotTo)
	roblox.implementMethod("Model", "GetBoundingBox", function(self)
		return boundingBox(self)
	end)
	roblox.implementMethod("Model", "GetExtentsSize", function(self)
		local _, size = boundingBox(self)
		return size
	end)
	roblox.implementMethod("Model", "GetScale", function(self)
		return extraGet(self, "Scale", 1)
	end)
	roblox.implementMethod("Model", "ScaleTo", function(self, scale)
		local current = extraGet(self, "Scale", 1)
		local factor = scale / current
		local pivot = getPivot(self)
		for _, part in partsOf(self) do
			local offset = pivot:ToObjectSpace(part.CFrame)
			part.Size = part.Size * factor
			part.CFrame = pivot * (CFrame.new(offset.Position * factor) * offset.Rotation)
		end
		extraSet(self, "Scale", scale)
	end)
	roblox.implementMethod("Model", "MoveTo", function(self, position)
		pivotTo(self, CFrame.new(position) * getPivot(self).Rotation)
	end)
	roblox.implementMethod("BasePart", "GetMass", function(self)
		return self.Size.X * self.Size.Y * self.Size.Z * 0.7
	end)
	roblox.implementMethod("BasePart", "GetTouchingParts", function()
		return {}
	end)
	roblox.implementMethod("BasePart", "ApplyImpulse", function() end)

	-- DataModel
	roblox.implementMethod("DataModel", "BindToClose", function(self, fn)
		local rt = runtimeOf(self)
		table.insert(rt.closeHandlers, fn)
	end)
	roblox.implementProperty("DataModel", "PlaceId", function(self)
		local rt = runtimeOf(self)
		return rt and rt.placeId or 0
	end)
	roblox.implementProperty("DataModel", "JobId", function()
		return "00000000-test-job"
	end)
	roblox.implementProperty("DataModel", "PrivateServerId", function()
		return ""
	end)
	roblox.implementProperty("DataModel", "CreatorId", function()
		return 0
	end)

	-- RunService
	roblox.implementMethod("RunService", "IsServer", function(self)
		return runtimeOf(self).context == "server"
	end)
	roblox.implementMethod("RunService", "IsClient", function(self)
		return runtimeOf(self).context == "client"
	end)
	roblox.implementMethod("RunService", "IsStudio", function(self)
		return runtimeOf(self).studio
	end)
	roblox.implementMethod("RunService", "IsRunning", function()
		return true
	end)
	roblox.implementMethod("RunService", "IsRunMode", function()
		return false
	end)
	roblox.implementMethod("RunService", "IsEdit", function()
		return false
	end)
	roblox.implementMethod("RunService", "BindToRenderStep", function(self, name, _priority, fn)
		local rt = runtimeOf(self)
		rt.renderSteps[name] = fn
	end)
	roblox.implementMethod("RunService", "UnbindFromRenderStep", function(self, name)
		local rt = runtimeOf(self)
		rt.renderSteps[name] = nil
	end)

	-- Players
	roblox.implementMethod("Players", "GetPlayers", function(self)
		local out = {}
		for _, child in self:GetChildren() do
			if child:IsA("Player") then
				table.insert(out, child)
			end
		end
		return out
	end)
	roblox.implementMethod("Players", "GetPlayerByUserId", function(self, userId)
		for _, child in self:GetChildren() do
			if child:IsA("Player") and child.UserId == userId then
				return child
			end
		end
		return nil
	end)
	roblox.implementMethod("Players", "GetPlayerFromCharacter", function(self, character)
		for _, child in self:GetChildren() do
			if child:IsA("Player") and child.Character == character then
				return child
			end
		end
		return nil
	end)
	roblox.implementMethod("Players", "GetNameFromUserIdAsync", function(self, userId)
		Scheduler.wait(Scheduler.frame)
		for _, child in self:GetChildren() do
			if child:IsA("Player") and child.UserId == userId then
				return child.Name
			end
		end
		return "Commander" .. tostring(userId)
	end)
	roblox.implementMethod("Players", "GetUserThumbnailAsync", function(_, userId)
		return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150", true
	end)
	roblox.implementMethod("Player", "LoadCharacter", function(self)
		local rt = runtimeOf(self)
		rt:spawnCharacter(self)
	end)
	roblox.implementMethod("Player", "Kick", function(self, message)
		local rt = runtimeOf(self)
		table.insert(rt.kicked, { player = self.Name, message = message })
		rt:removePlayer(self)
	end)
	roblox.implementMethod("Player", "IsFriendsWith", function()
		return false
	end)
	roblox.implementMethod("Player", "GetJoinData", function()
		return {}
	end)
	roblox.implementMethod("Player", "DistanceFromCharacter", function(self, point)
		local character = self.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return 0
		end
		return (root.CFrame.Position - point).Magnitude
	end)
	roblox.implementMethod("Player", "GetMouse", function()
		return { Hit = CFrame.new(), Target = nil, X = 0, Y = 0 }
	end)

	-- Humanoid
	roblox.implementMethod("Humanoid", "MoveTo", function() end)
	roblox.implementMethod("Humanoid", "ChangeState", function() end)
	roblox.implementMethod("Humanoid", "GetState", function()
		return Enum.HumanoidStateType.Running
	end)
	roblox.implementMethod("Humanoid", "TakeDamage", function(self, amount)
		extraSet(self, "Health", math.max(0, extraGet(self, "Health", 100) - amount))
	end)
	roblox.implementMethod("Humanoid", "GetAppliedDescription", function()
		return Instance.new("HumanoidDescription")
	end)

	-- CollectionService
	roblox.implementMethod("CollectionService", "GetTagged", function(self, tag)
		return descendantsWithTag(rootOf(self), tag)
	end)
	roblox.implementMethod("CollectionService", "GetInstanceAddedSignal", function(self, tag)
		return signalFor(self, "Added:" .. tag)
	end)
	roblox.implementMethod("CollectionService", "GetInstanceRemovedSignal", function(self, tag)
		return signalFor(self, "Removed:" .. tag)
	end)
	roblox.implementMethod("CollectionService", "AddTag", function(_, inst, tag)
		inst:AddTag(tag)
	end)
	roblox.implementMethod("CollectionService", "RemoveTag", function(_, inst, tag)
		inst:RemoveTag(tag)
	end)
	roblox.implementMethod("CollectionService", "HasTag", function(_, inst, tag)
		return inst:HasTag(tag)
	end)
	roblox.implementMethod("CollectionService", "GetTags", function(_, inst)
		return inst:GetTags()
	end)

	-- TweenService
	roblox.implementMethod("TweenService", "Create", function(_, instance, info, goals)
		return newTween(instance, info, goals)
	end)
	roblox.implementMethod("TweenService", "GetValue", function(_, alpha)
		return alpha
	end)

	-- DataStoreService
	roblox.implementMethod("DataStoreService", "GetDataStore", function(self, name, scope)
		return runtimeOf(self).datastores.dataStore(name, scope)
	end)
	roblox.implementMethod("DataStoreService", "GetOrderedDataStore", function(self, name, scope)
		return runtimeOf(self).datastores.orderedStore(name, scope)
	end)
	roblox.implementMethod("DataStoreService", "GetRequestBudgetForRequestType", function()
		return 100
	end)

	-- TeleportService
	roblox.implementMethod("TeleportService", "TeleportAsync", function(self, placeId, players, options)
		local rt = runtimeOf(self)
		Scheduler.wait(Scheduler.frame)
		if rt.studio then
			error("TeleportService:TeleportAsync is not supported in Studio (emulated)")
		end
		local names = {}
		for _, player in players do
			table.insert(names, player.Name)
		end
		table.insert(rt.teleports, {
			placeId = placeId,
			players = names,
			data = options and extraGet(options, "TeleportData", nil),
		})
		return { PrivateServerId = "reserved-" .. tostring(#rt.teleports), ReservedServerAccessCode = "code" }
	end)
	roblox.implementMethod("TeleportService", "ReserveServer", function(self)
		local rt = runtimeOf(self)
		if rt.studio then
			error("ReserveServer is not supported in Studio (emulated)")
		end
		return "reserved-code", "private-id"
	end)
	roblox.implementMethod("TeleportService", "GetLocalPlayerTeleportData", function()
		return nil
	end)
	roblox.implementMethod("TeleportService", "SetTeleportGui", function() end)
	roblox.implementMethod("TeleportOptions", "SetTeleportData", function(self, data)
		extraSet(self, "TeleportData", data)
	end)
	roblox.implementMethod("TeleportOptions", "GetTeleportData", function(self)
		return extraGet(self, "TeleportData", nil)
	end)

	-- HttpService
	roblox.implementMethod("HttpService", "JSONEncode", function(_, value)
		return serde.encode("json", value)
	end)
	roblox.implementMethod("HttpService", "JSONDecode", function(_, text)
		return serde.decode("json", text)
	end)
	local guidCounter = 0
	roblox.implementMethod("HttpService", "GenerateGUID", function(_, braces)
		guidCounter += 1
		local id = string.format("00000000-0000-4000-8000-%012d", guidCounter)
		return if braces == false then id else "{" .. id .. "}"
	end)

	-- MessagingService (no cross-server traffic in tests)
	roblox.implementMethod("MessagingService", "PublishAsync", function() end)
	roblox.implementMethod("MessagingService", "SubscribeAsync", function()
		return { Disconnect = function() end }
	end)

	-- Remotes
	roblox.implementMethod("RemoteFunction", "InvokeServer", function(self, ...)
		local rt = runtimeOf(self)
		return rt:_invokeServer(self, table.pack(...))
	end)
	roblox.implementMethod("RemoteFunction", "InvokeClient", function(self, player, ...)
		local rt = runtimeOf(self)
		return rt:_invokeClient(self, player, table.pack(...))
	end)
	roblox.implementMethod("RemoteEvent", "FireServer", function(self, ...)
		local rt = runtimeOf(self)
		rt:_fireServer(self, table.pack(...))
	end)
	roblox.implementMethod("RemoteEvent", "FireClient", function(self, player, ...)
		local rt = runtimeOf(self)
		rt:_fireClient(self, player, table.pack(...))
	end)
	roblox.implementMethod("RemoteEvent", "FireAllClients", function(self, ...)
		local rt = runtimeOf(self)
		local args = table.pack(...)
		for _, player in rt.game:GetService("Players"):GetPlayers() do
			rt:_fireClient(self, player, args)
		end
	end)
	roblox.implementMethod("BindableEvent", "Fire", function(self, ...)
		signalFor(self, "Event"):Fire(...)
	end)
	roblox.implementMethod("BindableFunction", "Invoke", function(self, ...)
		local fn = callbacks[self] and callbacks[self].OnInvoke
		assert(fn, "BindableFunction has no OnInvoke")
		return fn(...)
	end)

	-- Sound
	-- IsPlaying is a reflection-DB property without a default in Lune, so
	-- it is written directly (Instance.new in the runtime globals seeds it).
	local function setPlaying(sound, playing)
		extraSet(sound, "IsPlaying", playing)
		pcall(function()
			sound.IsPlaying = playing
		end)
	end
	roblox.implementMethod("Sound", "Play", function(self)
		setPlaying(self, true)
		local rt = runtimeOf(self)
		if rt then
			table.insert(rt.soundsPlayed, self.SoundId)
		end
		signalFor(self, "Played"):Fire(self.SoundId)
	end)
	roblox.implementMethod("Sound", "Stop", function(self)
		setPlaying(self, false)
	end)
	roblox.implementMethod("Sound", "Pause", function(self)
		setPlaying(self, false)
	end)
	roblox.implementMethod("Sound", "Resume", function(self)
		setPlaying(self, true)
	end)
	roblox.implementMethod("SoundService", "PlayLocalSound", function(self, sound)
		local rt = runtimeOf(self)
		table.insert(rt.soundsPlayed, sound.SoundId)
	end)

	-- Input / GUI services
	roblox.implementMethod("ContextActionService", "BindAction", function(self, name, fn)
		runtimeOf(self).actions[name] = fn
	end)
	roblox.implementMethod("ContextActionService", "BindActionAtPriority", function(self, name, fn)
		runtimeOf(self).actions[name] = fn
	end)
	roblox.implementMethod("ContextActionService", "UnbindAction", function(self, name)
		runtimeOf(self).actions[name] = nil
	end)
	roblox.implementMethod("ContextActionService", "GetButton", function()
		return nil
	end)
	roblox.implementMethod("UserInputService", "GetLastInputType", function(self)
		return runtimeOf(self).input.LastInputType
	end)
	roblox.implementMethod("UserInputService", "IsKeyDown", function()
		return false
	end)
	roblox.implementMethod("UserInputService", "GetMouseLocation", function()
		return Vector2.new(640, 360)
	end)
	roblox.implementMethod("UserInputService", "GetFocusedTextBox", function()
		return nil
	end)
	roblox.implementMethod("UserInputService", "GetConnectedGamepads", function()
		return {}
	end)
	roblox.implementMethod("GuiService", "GetGuiInset", function()
		return Vector2.new(0, 58), Vector2.zero
	end)
	roblox.implementMethod("GuiService", "IsTenFootInterface", function()
		return false
	end)
	roblox.implementMethod("StarterGui", "SetCoreGuiEnabled", function() end)
	roblox.implementMethod("StarterGui", "GetCoreGuiEnabled", function()
		return true
	end)
	roblox.implementMethod("StarterGui", "SetCore", function() end)
	roblox.implementMethod("StarterGui", "GetCore", function()
		return nil
	end)
	roblox.implementMethod("Debris", "AddItem", function(_, inst, lifetime)
		Scheduler.delay(lifetime or 10, function()
			if inst.Parent then
				inst:Destroy()
			end
		end)
	end)
	roblox.implementMethod("TextService", "GetTextSize", function(_, text, size, _font, frame)
		local width = #text * size * 0.52
		if frame and frame.X > 0 and width > frame.X then
			local lines = math.ceil(width / frame.X)
			return Vector2.new(frame.X, lines * size * 1.2)
		end
		return Vector2.new(width, size * 1.2)
	end)
	roblox.implementMethod("ProximityPrompt", "InputHoldBegin", function(self)
		local rt = runtimeOf(self)
		rt:triggerPrompt(self, rt.localPlayer)
	end)
	roblox.implementMethod("ProximityPrompt", "InputHoldEnd", function() end)

	-- Workspace: ray casts against the real part geometry (blocks, wedges,
	-- cylinders, balls) through a cached grid, honouring CanQuery and the
	-- RaycastParams filter.
	local function raycast(self, origin, direction, params)
		local rt = runtimeOf(self)
		local world = rt.workspace
		local count = #world:GetDescendants()
		if not rt.rayGrid or rt.rayGridCount ~= count then
			rt.rayGrid = Geometry.index(world, function(part)
				return part.CanQuery
			end, 8)
			rt.rayGridCount = count
		end
		local filter = params and params.FilterDescendantsInstances or {}
		local include = params and params.FilterType == Enum.RaycastFilterType.Include
		local function listed(part)
			for _, root in filter do
				if part == root or part:IsDescendantOf(root) then
					return true
				end
			end
			return false
		end
		local part, t = Geometry.raycast(rt.rayGrid, origin, direction, function(candidate)
			if not candidate:IsDescendantOf(world) or not candidate.CanQuery then
				return true
			end
			if include then
				return not listed(candidate)
			end
			return listed(candidate)
		end)
		if not part then
			return nil
		end
		return {
			Instance = part,
			Position = origin + direction * t,
			Distance = direction.Magnitude * t,
			Normal = -direction.Unit,
			Material = part.Material,
		}
	end
	roblox.implementMethod("Workspace", "Raycast", raycast)
	roblox.implementMethod("WorldRoot", "Raycast", raycast)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function(self)
		return runtimeOf(self).epoch + Scheduler.now
	end)
	roblox.implementMethod("WorldRoot", "BulkMoveTo", function(_, parts, cframes)
		for i, part in parts do
			part.CFrame = cframes[i]
		end
	end)
	roblox.implementMethod("WorldRoot", "GetPartBoundsInRadius", function()
		return {}
	end)
	roblox.implementMethod("WorldRoot", "GetPartsInPart", function()
		return {}
	end)
	roblox.implementMethod("Camera", "WorldToViewportPoint", function(self, point)
		local rt = runtimeOf(self)
		local viewport = rt and rt.viewport or Vector2.new(1280, 720)
		local rel = self.CFrame:PointToObjectSpace(point)
		local depth = -rel.Z
		local fov = math.rad(self.FieldOfView)
		local scale = (viewport.Y / 2) / math.tan(fov / 2)
		local x = viewport.X / 2 + (rel.X / math.max(math.abs(depth), 1e-3)) * scale
		local y = viewport.Y / 2 - (rel.Y / math.max(math.abs(depth), 1e-3)) * scale
		local onScreen = depth > 0 and x >= 0 and x <= viewport.X and y >= 0 and y <= viewport.Y
		return Vector3.new(x, y, depth), onScreen
	end)
	roblox.implementMethod("Camera", "WorldToScreenPoint", function(self, point)
		return self:WorldToViewportPoint(point)
	end)
	roblox.implementProperty("Camera", "FieldOfView", function(self)
		return extraGet(self, "FieldOfView", 70)
	end, function(self, value)
		extraSet(self, "FieldOfView", value)
	end)
end

--------------------------------------------------------------------------
-- Runtime
--------------------------------------------------------------------------
function Runtime.new(options)
	install()
	options = options or {}
	local game
	if options.place then
		game = roblox.deserializePlace(fs.readFile(options.place))
	else
		game = Instance.new("DataModel")
	end
	local self = setmetatable({}, Runtime)
	self.game = game
	self.context = options.context or "server"
	self.studio = if options.studio == nil then true else options.studio
	self.epoch = options.epoch or Runtime.DEFAULT_EPOCH
	self.placeId = options.placeId or 0
	self.viewport = options.viewport or Vector2.new(1280, 720)
	self.datastores = options.datastores or newDataStoreBackend()
	self.moduleCache = {}
	self.closeHandlers = {}
	self.renderSteps = {}
	self.actions = {}
	self.teleports = {}
	self.kicked = {}
	self.soundsPlayed = {}
	self.clientLog = {} -- [playerName] = { { remote, args } }
	self.clientRuntimes = {} -- [playerName] = runtime (for bridged tests)
	self.serverRuntime = nil
	self.mockServer = {} -- client-only tests: [remoteName] = handler(...)
	self.input = {
		TouchEnabled = options.touch or false,
		KeyboardEnabled = not options.touch,
		MouseEnabled = not options.touch,
		GamepadEnabled = false,
		LastInputType = if options.touch then Enum.UserInputType.Touch else Enum.UserInputType.Keyboard,
	}
	self.nextUserId = 1000
	runtimes[game] = self
	-- Input capability properties are reflection-DB properties without a
	-- default in Lune (implementProperty cannot override them), so they
	-- are assigned directly on the service.
	-- Lighting.ClockTime has no default in Lune; the engine always has one
	local lighting = game:GetService("Lighting")
	if not pcall(function()
		return lighting.ClockTime
	end) then
		lighting.ClockTime = 14
	end
	local uis = game:GetService("UserInputService")
	for _, name in { "TouchEnabled", "KeyboardEnabled", "MouseEnabled", "GamepadEnabled" } do
		pcall(function()
			uis[name] = self.input[name]
		end)
	end

	self.workspace = game:GetService("Workspace")
	if not self.workspace:FindFirstChildOfClass("Camera") then
		local camera = Instance.new("Camera")
		camera.Name = "Camera"
		camera.CFrame = CFrame.new(0, 20, 40)
		camera.Parent = self.workspace
	end
	self.workspace.CurrentCamera = self.workspace:FindFirstChildOfClass("Camera")
	self.workspace.CurrentCamera.ViewportSize = self.viewport

	self.shared = {}
	self.globals = self:_makeGlobals()
	return self
end

function Runtime:_makeGlobals()
	local rt = self
	local g = {
		assert = assert,
		error = error,
		getmetatable = getmetatable,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		print = print,
		rawequal = rawequal,
		rawget = rawget,
		rawlen = rawlen,
		rawset = rawset,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		typeof = typeof,
		unpack = table.unpack,
		xpcall = xpcall,
		gcinfo = gcinfo,
		newproxy = newproxy,
		coroutine = coroutine,
		math = math,
		string = string,
		table = table,
		utf8 = utf8,
		bit32 = bit32,
		buffer = buffer,
		debug = debug,
		vector = vector,
	}
	g.os = {
		time = function(t)
			if t then
				return os.time(t)
			end
			return math.floor(rt.epoch + Scheduler.now)
		end,
		clock = function()
			return Scheduler.now
		end,
		date = function(format, t)
			return os.date(format, t or math.floor(rt.epoch + Scheduler.now))
		end,
		difftime = function(a, b)
			return a - (b or 0)
		end,
	}
	g.tick = function()
		return rt.epoch + Scheduler.now
	end
	g.time = function()
		return Scheduler.now
	end
	g.elapsedTime = g.time
	g.warn = function(...)
		print("\27[33m[warn]\27[0m", ...)
	end
	g.task = Scheduler.task
	g.wait = Scheduler.wait
	g.delay = Scheduler.delay
	g.spawn = Scheduler.defer
	g.game = self.game
	g.Game = self.game
	g.workspace = self.workspace
	g.Workspace = self.workspace
	g.shared = self.shared
	g._G = {}
	g.require = function(target)
		return rt:require(target)
	end
	for _, name in
		{
			"Vector3",
			"Vector2",
			"Vector3int16",
			"Vector2int16",
			"CFrame",
			"Color3",
			"BrickColor",
			"UDim",
			"UDim2",
			"Enum",
			"Font",
			"NumberRange",
			"NumberSequence",
			"NumberSequenceKeypoint",
			"ColorSequence",
			"ColorSequenceKeypoint",
			"Rect",
			"Ray",
			"Region3",
			"Region3int16",
			"PhysicalProperties",
			"Faces",
			"Axes",
		}
	do
		g[name] = roblox[name]
	end
	-- Lune 0.10's CFrame.lookAt mirrors the Z component of the look direction
	-- (verified in tests/specs/00_harness.spec.luau); use a Roblox-correct one.
	g.CFrame = setmetatable({ lookAt = Runtime.lookAt }, { __index = roblox.CFrame })
	-- Instance.new seeds properties Lune cannot default (see Sound).
	g.Instance = setmetatable({
		new = function(className, parent)
			local inst = roblox.Instance.new(className)
			if className == "Sound" then
				pcall(function()
					inst.IsPlaying = false
				end)
			end
			if parent then
				inst.Parent = parent
			end
			return inst
		end,
	}, { __index = roblox.Instance })
	g.TweenInfo = TweenInfo
	g.Random = Random
	g.RaycastParams = {
		new = function()
			return {
				FilterType = Enum.RaycastFilterType.Exclude,
				FilterDescendantsInstances = {},
				IgnoreWater = false,
				RespectCanCollide = false,
				CollisionGroup = "Default",
			}
		end,
	}
	g.DateTime = {
		now = function()
			local ts = rt.epoch + Scheduler.now
			return { UnixTimestamp = math.floor(ts), UnixTimestampMillis = math.floor(ts * 1000) }
		end,
		fromUnixTimestamp = function(ts)
			return { UnixTimestamp = math.floor(ts), UnixTimestampMillis = math.floor(ts * 1000) }
		end,
	}
	g.settings = function()
		return { Rendering = { QualityLevel = 10 } }
	end
	g.UserSettings = function()
		return {
			GetService = function()
				return { SavedQualityLevel = Enum.SavedQualitySetting.Automatic }
			end,
		}
	end
	return g
end

function Runtime:env(scriptInstance)
	return setmetatable({ script = scriptInstance }, { __index = self.globals })
end

local LOADING = {}

function Runtime:require(module)
	if typeof(module) ~= "Instance" or not module:IsA("ModuleScript") then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local cached = self.moduleCache[module]
	if cached == LOADING then
		error("Requested module was required recursively: " .. module:GetFullName(), 2)
	elseif cached then
		return cached.value
	end
	self.moduleCache[module] = LOADING
	local chunk = luau.load(module.Source, {
		debugName = module:GetFullName(),
		environment = self:env(module),
		injectGlobals = false,
	})
	local results = table.pack(xpcall(chunk, debug.traceback))
	if not results[1] then
		self.moduleCache[module] = nil
		error("Requested module experienced an error while loading: " .. tostring(results[2]), 2)
	end
	if results.n ~= 2 then
		self.moduleCache[module] = nil
		error("Module code did not return exactly one value: " .. module:GetFullName(), 2)
	end
	self.moduleCache[module] = { value = results[2] }
	return results[2]
end

function Runtime:find(path: string)
	local names = string.split(path, ".")
	local node = findPath(self.game, names)
	assert(node, "Runtime:find could not resolve " .. path)
	return node
end

function Runtime:requirePath(path: string)
	return self:require(self:find(path))
end

-- Runs a Script/LocalScript's source as its own thread (like the engine).
function Runtime:runScript(scriptInstance)
	local chunk = luau.load(scriptInstance.Source, {
		debugName = scriptInstance:GetFullName(),
		environment = self:env(scriptInstance),
		injectGlobals = false,
	})
	return Scheduler.spawn(chunk)
end

function Runtime:runSource(source: string, name: string?, scriptInstance)
	local chunk = luau.load(source, {
		debugName = name or "source",
		environment = self:env(scriptInstance),
		injectGlobals = false,
	})
	return Scheduler.spawn(chunk)
end

function Runtime:step(seconds: number)
	local rt = self
	local previous = Scheduler.onFrame
	Scheduler.onFrame = function(dt)
		if previous then
			previous(dt)
		end
		rt:_frame(dt)
	end
	Scheduler.advance(seconds)
	Scheduler.onFrame = previous
end

function Runtime:_frame(dt)
	local runService = self.game:GetService("RunService")
	if self.context == "client" then
		for _, fn in self.renderSteps do
			Scheduler.spawn(fn, dt)
		end
		signalFor(runService, "RenderStepped"):Fire(dt)
		signalFor(runService, "PreRender"):Fire(dt)
	end
	signalFor(runService, "Stepped"):Fire(Scheduler.now, dt)
	signalFor(runService, "Heartbeat"):Fire(dt)
	signalFor(runService, "PostSimulation"):Fire(dt)
end

--------------------------------------------------------------------------
-- Players & characters
--------------------------------------------------------------------------
-- The engine copies these StarterPlayer settings onto each joining Player.
local function copyStarterSettings(game, player)
	local starter = game:GetService("StarterPlayer")
	player.CameraMaxZoomDistance = starter.CameraMaxZoomDistance
	player.CameraMinZoomDistance = starter.CameraMinZoomDistance
end

function Runtime:addPlayer(name: string, userId: number?)
	local players = self.game:GetService("Players")
	local player = Instance.new("Player")
	player.Name = name
	self.nextUserId += 1
	player.UserId = userId or self.nextUserId
	player.DisplayName = name
	copyStarterSettings(self.game, player)
	local gui = Instance.new("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = player
	local scripts = Instance.new("PlayerScripts")
	scripts.Name = "PlayerScripts"
	scripts.Parent = player
	local backpack = Instance.new("Backpack")
	backpack.Name = "Backpack"
	backpack.Parent = player
	player.Parent = players
	signalFor(players, "PlayerAdded"):Fire(player)
	return player
end

function Runtime:setLocalPlayer(name: string, userId: number?)
	local players = self.game:GetService("Players")
	local player = Instance.new("Player")
	player.Name = name
	player.UserId = userId or 1
	player.DisplayName = name
	copyStarterSettings(self.game, player)
	local gui = Instance.new("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = player
	local scripts = Instance.new("PlayerScripts")
	scripts.Name = "PlayerScripts"
	scripts.Parent = player
	player.Parent = players
	players.LocalPlayer = player
	self.localPlayer = player
	return player
end

function Runtime:spawnCharacter(player, cframe)
	local old = player.Character
	if old then
		signalFor(player, "CharacterRemoving"):Fire(old)
		old:Destroy()
	end
	local character = Instance.new("Model")
	character.Name = player.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = false
	root.Parent = character
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	local spawnCf = cframe or self:_spawnCFrame()
	root.CFrame = spawnCf
	head.CFrame = spawnCf * CFrame.new(0, 1.5, 0)
	character.Parent = self.workspace
	player.Character = character
	signalFor(player, "CharacterAdded"):Fire(character)
	return character
end

function Runtime:_spawnCFrame()
	local spawns = {}
	for _, d in self.workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d.Enabled then
			table.insert(spawns, d)
		end
	end
	if #spawns == 0 then
		return CFrame.new(0, 100, 0)
	end
	local spawn = spawns[(#self.game:GetService("Players"):GetPlayers() % #spawns) + 1]
	return spawn.CFrame * CFrame.new(0, spawn.Size.Y / 2 + 3, 0)
end

function Runtime:removePlayer(player)
	local players = self.game:GetService("Players")
	signalFor(players, "PlayerRemoving"):Fire(player)
	Scheduler.advance(0)
	if player.Character then
		player.Character:Destroy()
	end
	player.Parent = nil
end

function Runtime:moveCharacter(player, position)
	local character = player.Character
	assert(character, "player has no character")
	character:PivotTo(CFrame.new(position))
end

-- Emulates the engine firing a prompt for `player` (server-side
-- ProximityPromptService.PromptTriggered + prompt.Triggered).
function Runtime:triggerPrompt(prompt, player)
	signalFor(prompt, "Triggered"):Fire(player)
	local service = self.game:GetService("ProximityPromptService")
	signalFor(service, "PromptTriggered"):Fire(prompt, player)
	if self.serverRuntime and self.context == "client" then
		local serverPrompt = findPath(self.serverRuntime.game, pathOf(prompt))
		local serverPlayer = self.serverRuntime.game:GetService("Players"):FindFirstChild(player.Name)
		if serverPrompt and serverPlayer then
			self.serverRuntime:triggerPrompt(serverPrompt, serverPlayer)
		end
	end
end

--------------------------------------------------------------------------
-- Remote plumbing
--------------------------------------------------------------------------
function Runtime:_remoteByPath(otherRuntime, remote)
	local found = findPath(otherRuntime.game, pathOf(remote))
	assert(found, "remote not found in peer runtime: " .. remote:GetFullName())
	return found
end

function Runtime:_mapInstanceTo(otherRuntime)
	return function(inst)
		local found = findPath(otherRuntime.game, pathOf(inst))
		return found
	end
end

function Runtime:_invokeServer(remote, args)
	assert(self.context == "client", "InvokeServer called from the server")
	local server = self.serverRuntime
	if server then
		local target = self:_remoteByPath(server, remote)
		local fn = callbacks[target] and callbacks[target].OnServerInvoke
		assert(fn, "No OnServerInvoke for " .. target:GetFullName())
		local serverPlayer = server.game:GetService("Players"):FindFirstChild(self.localPlayer.Name)
		local copied = copyArgs(args, self:_mapInstanceTo(server))
		local results = table.pack(fn(serverPlayer, table.unpack(copied, 1, copied.n)))
		local back = copyArgs(results, self:_mapInstanceTo(self))
		return table.unpack(back, 1, back.n)
	end
	local handler = self.mockServer[remote.Name]
	assert(handler, "No mock server handler for " .. remote.Name)
	local copied = copyArgs(args)
	local results = table.pack(handler(table.unpack(copied, 1, copied.n)))
	local back = copyArgs(results)
	return table.unpack(back, 1, back.n)
end

function Runtime:_invokeClient(remote, player, args)
	local client = self.clientRuntimes[player.Name]
	assert(client, "InvokeClient without a bridged client for " .. player.Name)
	local target = self:_remoteByPath(client, remote)
	local fn = callbacks[target] and callbacks[target].OnClientInvoke
	assert(fn, "No OnClientInvoke")
	local copied = copyArgs(args, self:_mapInstanceTo(client))
	return fn(table.unpack(copied, 1, copied.n))
end

function Runtime:_fireServer(remote, args)
	assert(self.context == "client", "FireServer called from the server")
	local server = self.serverRuntime
	if not server then
		table.insert(self.clientLog, { remote = remote.Name, args = copyArgs(args) })
		return
	end
	local target = self:_remoteByPath(server, remote)
	local serverPlayer = server.game:GetService("Players"):FindFirstChild(self.localPlayer.Name)
	local copied = copyArgs(args, self:_mapInstanceTo(server))
	signalFor(target, "OnServerEvent"):Fire(serverPlayer, table.unpack(copied, 1, copied.n))
end

function Runtime:_fireClient(remote, player, args)
	assert(self.context == "server", "FireClient called from a client")
	local copied = copyArgs(args)
	local log = self.clientLog[player.Name]
	if not log then
		log = {}
		self.clientLog[player.Name] = log
	end
	table.insert(log, { remote = remote.Name, args = copied, at = Scheduler.now })
	local client = self.clientRuntimes[player.Name]
	if client then
		local target = self:_remoteByPath(client, remote)
		local mapped = copyArgs(args, self:_mapInstanceTo(client))
		signalFor(target, "OnClientEvent"):Fire(table.unpack(mapped, 1, mapped.n))
	end
end

-- Server-side test helpers: call a player's remote directly.
function Runtime:invoke(player, remoteName: string, ...)
	local remote = self:find("ReplicatedStorage.Lobby.Remotes." .. remoteName)
	local fn = callbacks[remote] and callbacks[remote].OnServerInvoke
	assert(fn, "No OnServerInvoke for " .. remoteName)
	local copied = copyArgs(table.pack(...))
	local results = table.pack(fn(player, table.unpack(copied, 1, copied.n)))
	local back = copyArgs(results)
	return table.unpack(back, 1, back.n)
end

function Runtime:fireServer(player, remoteName: string, ...)
	local remote = self:find("ReplicatedStorage.Lobby.Remotes." .. remoteName)
	local copied = copyArgs(table.pack(...))
	signalFor(remote, "OnServerEvent"):Fire(player, table.unpack(copied, 1, copied.n))
end

function Runtime:lastClientMessage(player, remoteName: string)
	local log = self.clientLog[player.Name] or {}
	for i = #log, 1, -1 do
		if log[i].remote == remoteName then
			return log[i].args
		end
	end
	return nil
end

-- Bridge a client runtime to this server runtime for a player.
function Runtime:bridgeClient(client, player)
	self.clientRuntimes[player.Name] = client
	client.serverRuntime = self
end

function Runtime:close()
	for _, fn in self.closeHandlers do
		Scheduler.spawn(fn)
	end
	Scheduler.advance(1)
end

function Runtime:save(path: string)
	fs.writeFile(path, roblox.serializePlace(self.game))
end

return Runtime
