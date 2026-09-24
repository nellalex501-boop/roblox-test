--!strict
-- Subtle ambient animation on the world anchors the server tags with
-- LobbyAmbient / AmbientRole (see World/Kit.anchor):
--   RadarSpin   rotating surveillance radar
--   Flag        three-segment flags waving in the wind
--   BlinkRed    aviation obstruction lights (slow red blink)
--   BlinkSlow / BlinkFast   equipment lamps on racks and consoles
--   CrtFlicker  the occasional CRT brightness dip
--   Fire        brazier light flicker
-- Everything runs locally from one Heartbeat connection, updates at modest
-- rates and skips anchors far from the camera. Streaming-safe: anchors are
-- tracked with CollectionService added/removed signals.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local AmbientAnimator = {}

AmbientAnimator.Tag = "LobbyAmbient"
AmbientAnimator.FlagRange = 220
AmbientAnimator.RadarRange = 400
AmbientAnimator.RadarSpeed = math.pi * 2 / 5 -- one turn every 5 s

type Radar = { model: Model, base: CFrame }
type Flag = { segments: { BasePart }, pole: CFrame, width: number, height: number, phase: number }
type Blinker = {
	part: BasePart,
	onColor: Color3,
	offColor: Color3,
	onMaterial: Enum.Material,
	period: number,
	duty: number,
	phase: number,
	lit: boolean,
}
type FireLight = { light: PointLight, base: number, range: number }

local radars: { [BasePart]: Radar } = {}
local flags: { [BasePart]: Flag } = {}
local blinkers: { [BasePart]: Blinker } = {}
local screens: { [BasePart]: SurfaceGui } = {}
local fires: { [BasePart]: FireLight } = {}
local connection: RBXScriptConnection? = nil
local rng = Random.new(1984)

local function dim(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function track(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local role = part:GetAttribute("AmbientRole")
	if role == "RadarSpin" then
		local model = part.Parent
		if model and model:IsA("Model") then
			radars[part] = { model = model, base = model:GetPivot() }
		end
	elseif role == "Flag" then
		local model = part.Parent
		if not model then
			return
		end
		local segments: { BasePart } = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("FlagIndex") then
				segments[child:GetAttribute("FlagIndex") :: number] = child
			end
		end
		local first = segments[1]
		if first then
			local width, height = first.Size.X, first.Size.Y
			-- the hoist edge at the top of the pole
			local pole = first.CFrame * CFrame.new(-width / 2, height / 2, 0)
			flags[part] =
				{ segments = segments, pole = pole, width = width, height = height, phase = rng:NextNumber(0, 6) }
		end
	elseif role == "BlinkRed" or role == "BlinkSlow" or role == "BlinkFast" then
		local period = if role == "BlinkFast" then 0.6 elseif role == "BlinkRed" then 1.6 else 2.2
		blinkers[part] = {
			part = part,
			onColor = part.Color,
			offColor = dim(part.Color, 0.25),
			onMaterial = part.Material,
			period = period,
			duty = if role == "BlinkRed" then 0.3 else 0.55,
			phase = rng:NextNumber(0, period),
			lit = true,
		}
	elseif role == "CrtFlicker" then
		local gui = part:FindFirstChildOfClass("SurfaceGui")
		if gui then
			screens[part] = gui
		end
	elseif role == "Fire" then
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			fires[part] = { light = light, base = light.Brightness, range = light.Range }
		end
	end
end

local function untrack(part: Instance)
	if part:IsA("BasePart") then
		radars[part] = nil
		flags[part] = nil
		blinkers[part] = nil
		screens[part] = nil
		fires[part] = nil
	end
end

-- Positions a flag's segments along a travelling wave.
function AmbientAnimator.waveFlag(flag: Flag, t: number)
	local edge = flag.pole
	for i, segment in flag.segments do
		local angle = math.sin(t * 2.6 - i * 1.1 + flag.phase) * (0.1 + i * 0.07)
		local turn = CFrame.Angles(0, angle, 0)
		segment.CFrame = edge * turn * CFrame.new(flag.width / 2, -flag.height / 2, 0)
		edge = edge * turn * CFrame.new(flag.width, 0, 0)
	end
end

local clock = 0
local slowTimer = 0
local flagTimer = 0
local flickerAt = 3

function AmbientAnimator.step(dt: number)
	clock += dt
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	-- radar: every frame when in view range
	for _, radar in radars do
		if (radar.base.Position - eye).Magnitude < AmbientAnimator.RadarRange then
			radar.model:PivotTo(radar.base * CFrame.Angles(0, clock * AmbientAnimator.RadarSpeed, 0))
		end
	end
	-- flags: 30 Hz, only near the camera
	flagTimer += dt
	if flagTimer >= 1 / 30 then
		flagTimer = 0
		for _, flag in flags do
			if (flag.pole.Position - eye).Magnitude < AmbientAnimator.FlagRange then
				AmbientAnimator.waveFlag(flag, clock)
			end
		end
	end
	-- lamps and fire light: 12 Hz
	slowTimer += dt
	if slowTimer >= 1 / 12 then
		slowTimer = 0
		for _, b in blinkers do
			local lit = ((clock + b.phase) % b.period) < b.period * b.duty
			if lit ~= b.lit then
				b.lit = lit
				b.part.Color = if lit then b.onColor else b.offColor
				b.part.Material = if lit then b.onMaterial else Enum.Material.SmoothPlastic
			end
		end
		for _, f in fires do
			f.light.Brightness = f.base * rng:NextNumber(0.75, 1.15)
			f.light.Range = f.range * rng:NextNumber(0.9, 1.05)
		end
	end
	-- a random CRT dips briefly every few seconds
	if clock >= flickerAt then
		flickerAt = clock + rng:NextNumber(2.5, 6)
		local list = {}
		for _, gui in screens do
			table.insert(list, gui)
		end
		if #list > 0 then
			local gui = list[rng:NextInteger(1, #list)]
			gui.Brightness = 0.8
			task.delay(0.08, function()
				gui.Brightness = 1
			end)
		end
	end
end

function AmbientAnimator.counts(): { [string]: number }
	local function size(t: { [any]: any }): number
		local n = 0
		for _ in t do
			n += 1
		end
		return n
	end
	return {
		radars = size(radars),
		flags = size(flags),
		blinkers = size(blinkers),
		screens = size(screens),
		fires = size(fires),
	}
end

function AmbientAnimator.start()
	for _, part in CollectionService:GetTagged(AmbientAnimator.Tag) do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal(AmbientAnimator.Tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(AmbientAnimator.Tag):Connect(untrack)
	if connection then
		connection:Disconnect()
	end
	connection = RunService.Heartbeat:Connect(AmbientAnimator.step)
end

return AmbientAnimator
