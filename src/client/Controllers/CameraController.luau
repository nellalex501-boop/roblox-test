--!strict
-- Vehicle focus camera, used by the Garage showroom (vehicle on the
-- turntable, full-screen viewer) and by the vehicle inspection sheet (the
-- event's limited unit):
-- * the camera orbits the vehicle; drag with the mouse (either button) or a
--   finger to turn it, mouse wheel or pinch to zoom, gamepad right stick;
-- * a ray from the vehicle to the camera shortens the distance whenever
--   something (a wall, a pillar, a prop) would come between them, so the
--   camera never ends up behind a wall looking at it;
-- * idle, it can drift slowly around the vehicle (inspection sheet).
-- Also caps the normal zoom distance so the camera stays inside buildings.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WindowManager = require(script.Parent.Parent.UI.WindowManager)

local CameraController = {}

-- same as StarterPlayer in default.project.json; applied here as well
-- because StarterPlayer settings stay behind when the lobby's scripts are
-- copied into another place
CameraController.MaxZoom = 55
CameraController.DragSpeed = math.rad(0.35) -- radians per pixel
CameraController.ZoomStep = 0.12 -- fraction of the distance per wheel notch
CameraController.StickSpeed = math.rad(110) -- radians per second at full tilt
CameraController.WallMargin = 1.2 -- studs kept between the camera and a hit
CameraController.MinPitch = math.rad(-4)
CameraController.MaxPitch = math.rad(62)

export type OrbitOptions = {
	shift: number?, -- horizontal framing: > 0 puts the vehicle left of centre
	autoSpin: number?, -- radians per second while idle
	pitch: number?,
	minDistance: number?,
	maxDistance: number?, -- zoom cap (e.g. keeps the camera inside a hall)
	maxPitch: number?,
	distance: number?,
}

type Orbit = {
	model: Model,
	center: Vector3,
	yaw: number,
	pitch: number,
	distance: number, -- wanted distance (zoom)
	actual: number, -- distance after the wall clamp (smoothed)
	minDistance: number,
	maxDistance: number,
	maxCap: number,
	maxPitch: number,
	shift: number,
	autoSpin: number,
	idle: number,
}

local orbit: Orbit? = nil
local connection: RBXScriptConnection? = nil
local dragging = false
local stick = Vector2.zero

-- Camera CFrame for an eye on the orbit (pure; used by tests).
function CameraController.orbitCFrame(
	center: Vector3,
	distance: number,
	yaw: number,
	pitch: number,
	shift: number
): CFrame
	local direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	local eye = center + direction * distance
	return CFrame.lookAt(eye, center) * CFrame.new(distance * shift, 0, 0)
end

-- Longest distance (<= wanted) at which nothing blocks the view from the
-- centre along `direction`. `ignore` lists instances the ray passes through.
function CameraController.clampDistance(
	center: Vector3,
	direction: Vector3,
	wanted: number,
	ignore: { Instance }
): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(center, direction.Unit * (wanted + CameraController.WallMargin), params)
	if hit then
		return math.max(hit.Distance - CameraController.WallMargin, 2)
	end
	return wanted
end

local function ignoreList(model: Model): { Instance }
	local list: { Instance } = { model }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(list, character)
	end
	for _, player in Players:GetPlayers() do
		if player.Character and player ~= Players.LocalPlayer then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function update(dt: number)
	local o = orbit
	local camera = workspace.CurrentCamera
	if not o or not camera then
		return
	end
	if stick.Magnitude > 0.15 then
		o.yaw -= stick.X * CameraController.StickSpeed * dt
		o.pitch = math.clamp(
			o.pitch - stick.Y * CameraController.StickSpeed * 0.6 * dt,
			CameraController.MinPitch,
			o.maxPitch
		)
		o.idle = 0
	elseif not dragging then
		o.idle += dt
		if o.autoSpin ~= 0 and o.idle > 2 then
			o.yaw += o.autoSpin * dt
		end
	end
	local direction =
		Vector3.new(math.sin(o.yaw) * math.cos(o.pitch), math.sin(o.pitch), math.cos(o.yaw) * math.cos(o.pitch))
	local allowed = CameraController.clampDistance(o.center, direction, o.distance, ignoreList(o.model))
	if allowed < o.actual then
		-- something moved in the way: jump in front of it at once
		o.actual = allowed
	else
		o.actual += (allowed - o.actual) * math.min(1, dt * 6)
	end
	camera.CFrame = CameraController.orbitCFrame(o.center, o.actual, o.yaw, o.pitch, o.shift)
end

-- Starts orbiting `model`. The orbit starts on the side the camera is on.
function CameraController.startOrbit(model: Model, options: OrbitOptions?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local opts: OrbitOptions = options or {}
	local boxCf, size = model:GetBoundingBox()
	local center = boxCf.Position
	local reach = math.max(size.X, size.Z)
	local maxCap = opts.maxDistance or math.huge
	local minDistance = opts.minDistance or math.max(reach * 0.7, 8)
	local maxDistance = math.min(reach * 1.6 + 10, maxCap)
	local fromCamera = camera.CFrame.Position - center
	local distance = math.clamp(opts.distance or reach * 1.15 + 6, minDistance, maxDistance)
	orbit = {
		model = model,
		center = center,
		yaw = math.atan2(fromCamera.X, fromCamera.Z),
		pitch = opts.pitch or math.rad(16),
		distance = distance,
		actual = distance,
		minDistance = minDistance,
		maxDistance = maxDistance,
		maxCap = maxCap,
		maxPitch = opts.maxPitch or CameraController.MaxPitch,
		shift = opts.shift or 0,
		autoSpin = opts.autoSpin or 0,
		idle = 0,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	if connection then
		connection:Disconnect()
	end
	connection = RunService.RenderStepped:Connect(update)
	update(1)
end

-- Keeps the orbit but looks at another model (the showroom swapped the
-- vehicle on the turntable).
function CameraController.retarget(model: Model)
	local o = orbit
	if not o then
		return
	end
	local boxCf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Z)
	o.model = model
	o.center = boxCf.Position
	o.minDistance = math.max(reach * 0.7, 8)
	o.maxDistance = math.min(reach * 1.6 + 10, o.maxCap)
	o.distance = math.clamp(reach * 1.15 + 6, o.minDistance, o.maxDistance)
end

function CameraController.zoom(notches: number)
	local o = orbit
	if o then
		o.distance = math.clamp(o.distance * (1 - notches * CameraController.ZoomStep), o.minDistance, o.maxDistance)
		o.idle = 0
	end
end

function CameraController.turn(deltaPixels: Vector2)
	local o = orbit
	if o then
		o.yaw -= deltaPixels.X * CameraController.DragSpeed
		o.pitch =
			math.clamp(o.pitch + deltaPixels.Y * CameraController.DragSpeed, CameraController.MinPitch, o.maxPitch)
		o.idle = 0
	end
end

function CameraController.isOrbiting(): boolean
	return orbit ~= nil
end

-- Orbit state for tests and the showroom UI.
function CameraController.state(): { [string]: any }?
	local o = orbit
	if not o then
		return nil
	end
	return {
		model = o.model,
		center = o.center,
		yaw = o.yaw,
		pitch = o.pitch,
		distance = o.distance,
		actual = o.actual,
	}
end

function CameraController.stopOrbit()
	if not orbit then
		return
	end
	orbit = nil
	dragging = false
	stick = Vector2.zero
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function inspectedModel(part: BasePart): Model?
	local showcase = part.Parent
	if not showcase then
		return nil
	end
	for _, child in showcase:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("UnitId") then
			return child
		end
	end
	return if showcase:IsA("Model") then showcase else nil
end

function CameraController.start()
	local player = Players.LocalPlayer
	player.CameraMaxZoomDistance = math.min(player.CameraMaxZoomDistance, CameraController.MaxZoom)
	WindowManager.opened:Connect(function(name, context)
		local part = context.part
		if name == "Inspect" and part then
			local model = inspectedModel(part)
			if model then
				-- vehicle left of centre, clear of the sheet docked on the right
				CameraController.startOrbit(model, { shift = 0.28, autoSpin = math.rad(7) })
			end
		end
	end)
	WindowManager.closed:Connect(function(name)
		if name == "Inspect" or name == "Showroom" then
			CameraController.stopOrbit()
		end
	end)
	player.CharacterAdded:Connect(function()
		CameraController.stopOrbit()
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if orbit and not processed then
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 then
				dragging = true
			elseif kind == Enum.UserInputType.Touch then
				dragging = true
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.MouseButton2
			or kind == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if not orbit then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			if dragging then
				CameraController.turn(Vector2.new(input.Delta.X, input.Delta.Y))
			end
		elseif kind == Enum.UserInputType.MouseWheel and not processed then
			CameraController.zoom(input.Position.Z)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale: number, _, state: Enum.UserInputState)
		if orbit and state == Enum.UserInputState.Change then
			CameraController.zoom((scale - 1) * 2)
		end
	end)
end

return CameraController
