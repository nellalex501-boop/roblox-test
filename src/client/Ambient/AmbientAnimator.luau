--!strict
-- Subtle ambient animation on the world anchors the server tags with
-- LobbyAmbient / AmbientRole (see World/Kit.anchor):
--   RadarSpin   rotating surveillance radar
--   Flag        segmented flags waving in the wind (every frame)
--   BlinkRed    aviation obstruction lights (slow red blink)
--   BlinkSlow / BlinkFast   equipment lamps on racks and consoles
--   CrtFlicker  the occasional CRT brightness dip (back to the screen's
--               own brightness afterwards)
--   Fire        smooth fire-light flicker (layered noise, no strobing)
--   NightLamp   street, bollard and flood lamps: lit after dusk, dark by day
-- Everything runs locally from one Heartbeat connection and skips anchors
-- far from the camera. Streaming-safe: anchors are tracked with
-- CollectionService added/removed signals.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local AmbientAnimator = {}

AmbientAnimator.Tag = "LobbyAmbient"
AmbientAnimator.FlagRange = 700
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
type FireLight = { light: PointLight, base: number, range: number, seed: number }
type Screen = { gui: SurfaceGui, base: number, dimmed: boolean }
type NightLamp = { lens: BasePart, light: Light?, dayColor: Color3, nightColor: Color3, dayMaterial: Enum.Material }

local radars: { [BasePart]: Radar } = {}
local flags: { [BasePart]: Flag } = {}
local blinkers: { [BasePart]: Blinker } = {}
local screens: { [BasePart]: Screen } = {}
local fires: { [BasePart]: FireLight } = {}
local lamps: { [BasePart]: NightLamp } = {}
local lampsLit: boolean? = nil
local connection: RBXScriptConnection? = nil
local rng = Random.new(1984)

local function dim(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Lamps burn between dusk and dawn (Lighting.ClockTime, hours).
function AmbientAnimator.isNight(clockTime: number): boolean
	return clockTime < 6.4 or clockTime > 18.1
end

local function light(lamp: NightLamp, on: boolean)
	lamp.lens.Color = if on then lamp.nightColor else lamp.dayColor
	lamp.lens.Material = if on then Enum.Material.Neon else lamp.dayMaterial
	local l = lamp.light
	if l then
		l.Enabled = on
	end
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
			screens[part] = { gui = gui, base = gui.Brightness, dimmed = false }
		end
	elseif role == "NightLamp" then
		local night = part:GetAttribute("NightColor")
		local lamp: NightLamp = {
			lens = part,
			light = part:FindFirstChildWhichIsA("Light"),
			dayColor = part.Color,
			nightColor = if typeof(night) == "Color3" then night else part.Color,
			dayMaterial = part.Material,
		}
		lamps[part] = lamp
		if lampsLit ~= nil then
			light(lamp, lampsLit)
		end
	elseif role == "Fire" then
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			fires[part] = {
				light = light,
				base = light.Brightness,
				range = light.Range,
				seed = rng:NextNumber(0, 100),
			}
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
		lamps[part] = nil
	end
end

-- Positions a flag's segments along a travelling wave: each joint bends a
-- little more toward the fly end, with a slow gust that swells and fades.
function AmbientAnimator.waveFlag(flag: Flag, t: number)
	local edge = flag.pole
	local n = #flag.segments
	local gust = 0.75 + 0.5 * math.noise(t * 0.25, flag.phase)
	for i, segment in flag.segments do
		local u = i / n
		local amplitude = (0.03 + 0.22 * u) * (4 / n) * gust
		local angle = math.sin(t * 2.4 - u * 4.5 + flag.phase) * amplitude
		local turn = CFrame.Angles(0, angle, 0)
		segment.CFrame = edge * turn * CFrame.new(flag.width / 2, -flag.height / 2, 0)
		edge = edge * turn * CFrame.new(flag.width, 0, 0)
	end
end

-- Fire light at time t as (brightness, range) factors: two layers of
-- noise, so it breathes and licks instead of jumping at random.
function AmbientAnimator.fireLevel(seed: number, t: number): (number, number)
	local slow = math.noise(t * 1.6, seed)
	local fast = math.noise(t * 5.3, seed + 17.3)
	local brightness = math.clamp(0.9 + 0.35 * slow + 0.12 * fast, 0.55, 1.3)
	local range = math.clamp(1 + 0.08 * math.noise(t * 1.1, seed + 41.7), 0.9, 1.1)
	return brightness, range
end

local clock = 0
local slowTimer = 0
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
	-- flags: every frame within sight
	for _, flag in flags do
		if (flag.pole.Position - eye).Magnitude < AmbientAnimator.FlagRange then
			AmbientAnimator.waveFlag(flag, clock)
		end
	end
	-- fire light: every frame, smooth
	for _, f in fires do
		local brightness, range = AmbientAnimator.fireLevel(f.seed, clock)
		f.light.Brightness = f.base * brightness
		f.light.Range = f.range * range
	end
	-- lamps: 12 Hz is plenty for on/off blinking; lamps follow the clock
	slowTimer += dt
	if slowTimer >= 1 / 12 then
		slowTimer = 0
		local night = AmbientAnimator.isNight(Lighting.ClockTime)
		if night ~= lampsLit then
			lampsLit = night
			for _, lamp in lamps do
				light(lamp, night)
			end
		end
		for _, b in blinkers do
			local lit = ((clock + b.phase) % b.period) < b.period * b.duty
			if lit ~= b.lit then
				b.lit = lit
				b.part.Color = if lit then b.onColor else b.offColor
				b.part.Material = if lit then b.onMaterial else Enum.Material.SmoothPlastic
			end
		end
	end
	-- a random CRT dips briefly every few seconds, then returns to its own
	-- brightness (the screens are not all at 1)
	if clock >= flickerAt then
		flickerAt = clock + rng:NextNumber(2.5, 6)
		local list: { Screen } = {}
		for _, screen in screens do
			if not screen.dimmed then
				table.insert(list, screen)
			end
		end
		if #list > 0 then
			local screen = list[rng:NextInteger(1, #list)]
			screen.dimmed = true
			screen.gui.Brightness = screen.base * 0.8
			task.delay(0.08, function()
				screen.gui.Brightness = screen.base
				screen.dimmed = false
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
		lamps = size(lamps),
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
