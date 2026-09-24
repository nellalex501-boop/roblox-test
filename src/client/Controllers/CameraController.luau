--!strict
-- Cinematic camera for vehicle inspection: while the inspection sheet is
-- open the camera eases into a slow orbit around the vehicle on display
-- (framed to the left of the docked sheet), then hands control back.
-- Also caps the zoom distance so the camera stays inside the buildings.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WindowManager = require(script.Parent.Parent.UI.WindowManager)

local CameraController = {}

CameraController.OrbitSpeed = math.rad(7) -- radians per second
CameraController.EaseTime = 0.7
-- same as StarterPlayer in default.project.json; applied here as well
-- because StarterPlayer settings stay behind when the lobby's scripts are
-- copied into another place
CameraController.MaxZoom = 55

local orbiting = false
local connection: RBXScriptConnection? = nil

local function vehicleFor(part: BasePart): Model?
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

-- Camera CFrame on the orbit at `angle` around the vehicle.
function CameraController.orbitCFrame(center: Vector3, radius: number, angle: number, height: number): CFrame
	local eye = center + Vector3.new(math.sin(angle) * radius, height, math.cos(angle) * radius)
	local look = CFrame.lookAt(eye, center)
	-- shift the view so the vehicle sits left of centre, clear of the sheet
	return look * CFrame.new(radius * 0.28, 0, 0)
end

function CameraController.startOrbit(part: BasePart)
	local camera = workspace.CurrentCamera
	local model = vehicleFor(part)
	if not camera or not model then
		return
	end
	local boxCf, size = model:GetBoundingBox()
	local center = boxCf.Position
	local radius = math.max(size.X, size.Z) * 1.25 + 6
	local height = size.Y * 0.55 + 3
	-- start the orbit on the side the player is looking from
	local fromCamera = camera.CFrame.Position - center
	local angle = math.atan2(fromCamera.X, fromCamera.Z)
	orbiting = true
	camera.CameraType = Enum.CameraType.Scriptable
	local target = CameraController.orbitCFrame(center, radius, angle, height)
	local ease = TweenService:Create(
		camera,
		TweenInfo.new(CameraController.EaseTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = target }
	)
	ease:Play()
	local started = os.clock()
	if connection then
		connection:Disconnect()
	end
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if not orbiting then
			return
		end
		if os.clock() - started < CameraController.EaseTime then
			return
		end
		angle += dt * CameraController.OrbitSpeed
		camera.CFrame = CameraController.orbitCFrame(center, radius, angle, height)
	end)
end

function CameraController.stopOrbit()
	if not orbiting then
		return
	end
	orbiting = false
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

function CameraController.start()
	local player = Players.LocalPlayer
	player.CameraMaxZoomDistance = math.min(player.CameraMaxZoomDistance, CameraController.MaxZoom)
	WindowManager.opened:Connect(function(name, context)
		local part = context.part
		if name == "Inspect" and part then
			CameraController.startOrbit(part)
		end
	end)
	WindowManager.closed:Connect(function(name)
		if name == "Inspect" then
			CameraController.stopOrbit()
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		CameraController.stopOrbit()
	end)
end

return CameraController
