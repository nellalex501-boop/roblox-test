--!strict
-- Occasional helicopter pass over the base (every few minutes): a local
-- copy of the helicopter parked on the helipad crosses the sky at altitude
-- with a spinning rotor and the flyby sound. Purely cosmetic and local.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Sounds = require(Lobby:WaitForChild("Config"):WaitForChild("Sounds"))

local Flyby = {}

Flyby.MinInterval = 180
Flyby.MaxInterval = 330
Flyby.Duration = 26
Flyby.Altitude = 115
Flyby.RotorSpeed = math.pi * 2 * 5 -- 5 turns / second

local rng = Random.new()
local active: Model? = nil

local function source(): Model?
	-- the helicopter parked on the helipad (Details pass)
	local root = workspace:FindFirstChild("ColdWarLobby")
	local heli = root and root:FindFirstChild("HELICOPTER", true)
	return if heli and heli:IsA("Model") then heli else nil
end

-- Flies one pass; returns the flying model (nil when no helicopter exists).
function Flyby.run(): Model?
	if active then
		return nil
	end
	local template = source()
	if not template then
		return nil
	end
	local heli = template:Clone()
	heli.Name = "FlybyHelicopter"
	for _, d in heli:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local rotor = heli:FindFirstChild("Rotor", true)
	local hub = rotor and rotor:FindFirstChild("RotorHub")
	local blade = rotor and rotor:FindFirstChild("Blade")
	local tail = rotor and rotor:FindFirstChild("TailRotor")
	local pivot = heli:GetPivot()
	local bladeOffset = if hub
			and blade
			and hub:IsA("BasePart")
			and blade:IsA("BasePart")
		then hub.CFrame:ToObjectSpace(blade.CFrame)
		else nil
	local tailOffset = if tail and tail:IsA("BasePart") then pivot:ToObjectSpace(tail.CFrame) else nil
	local hubOffset = if hub and hub:IsA("BasePart") then pivot:ToObjectSpace(hub.CFrame) else nil
	-- straight pass across the base on a random heading
	local heading = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
	local offset = Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-60, 60)
	local from = offset - dir * 650 + Vector3.new(0, Flyby.Altitude, 0)
	local to = offset + dir * 650 + Vector3.new(0, Flyby.Altitude + 10, 0)
	local facing = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(math.rad(-6), 0, 0) -- nose down in cruise
	heli:PivotTo(CFrame.new(from) * facing)
	heli.Parent = workspace
	active = heli
	local soundDef = Sounds.Flyby
	if hub and hub:IsA("BasePart") then
		local sound = Instance.new("Sound")
		sound.Name = "Flyby"
		sound.SoundId = soundDef.Id
		sound.Volume = soundDef.Volume
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = soundDef.RollOffMin or 60
		sound.RollOffMaxDistance = soundDef.RollOffMax or 600
		sound.Looped = true
		sound.Parent = hub
		sound:Play()
	end
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local t = math.clamp(elapsed / Flyby.Duration, 0, 1)
		local cf = CFrame.new(from:Lerp(to, t)) * facing
		heli:PivotTo(cf)
		if hubOffset and bladeOffset and blade and blade:IsA("BasePart") then
			blade.CFrame = cf * hubOffset * CFrame.Angles(0, elapsed * Flyby.RotorSpeed, 0) * bladeOffset
		end
		if tailOffset and tail and tail:IsA("BasePart") then
			tail.CFrame = cf * tailOffset * CFrame.Angles(elapsed * Flyby.RotorSpeed * 1.5, 0, 0)
		end
		if t >= 1 then
			connection:Disconnect()
			heli:Destroy()
			active = nil
		end
	end)
	return heli
end

function Flyby.start()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(Flyby.MinInterval, Flyby.MaxInterval))
			Flyby.run()
		end
	end)
end

return Flyby
