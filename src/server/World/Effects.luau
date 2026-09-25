--!strict
-- Static ambient effects: chimney / stove smoke, particle wood fire with
-- embers, snowfall and the snow gun's plume. Emission rates are kept low;
-- the client ambient pass adds light flicker and sound on the same anchors.

local Effects = {}

Effects.SmokeTexture = "rbxasset://textures/particles/smoke_main.dds"

export type SmokeStyle = { Rate: number?, Size: number?, Rise: number?, Color: Color3?, Opacity: number? }

-- Soft grey smoke rising from `part`, drifting east with the flags' wind.
function Effects.smoke(part: BasePart, style: SmokeStyle?): ParticleEmitter
	local s: SmokeStyle = style or {}
	local size = s.Size or 2
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Texture = Effects.SmokeTexture
	emitter.Rate = s.Rate or 2
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(s.Rise or 2.2, (s.Rise or 2.2) * 1.4)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0.7, 0.15, 0)
	emitter.Drag = 0.4
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-12, 12)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.5),
		NumberSequenceKeypoint.new(1, size * 2.6),
	})
	local opacity = s.Opacity or 0.45
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 1 - opacity),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(s.Color or Color3.fromRGB(150, 148, 142))
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Parent = part
	return emitter
end

Effects.FlameTexture = "rbxasset://textures/particles/fire_main.dds"
Effects.SparkTexture = "rbxasset://textures/particles/fire_sparks_main.dds"

-- Wood fire as particles, anchored on `part` (the top of the fuel): licking
-- flames (additive, bright core fading to deep orange), a few embers that
-- drift up with the wind, thin dark smoke, and a warm non-shadowed light
-- whose flicker the client drives with smooth noise (AmbientAnimator
-- "Fire"). `size` is roughly the flame height in studs.
function Effects.fire(part: BasePart, size: number?): { ParticleEmitter }
	local s = size or 2.5
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "Flames"
	flames.Texture = Effects.FlameTexture
	flames.Rate = 16
	flames.Lifetime = NumberRange.new(0.45, 0.8)
	flames.Speed = NumberRange.new(s * 0.9, s * 1.5)
	flames.SpreadAngle = Vector2.new(9, 9)
	flames.EmissionDirection = Enum.NormalId.Top
	flames.Acceleration = Vector3.new(0.4, s * 0.8, 0)
	flames.Drag = 1.2
	flames.Rotation = NumberRange.new(-20, 20)
	flames.RotSpeed = NumberRange.new(-40, 40)
	flames.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s * 0.42),
		NumberSequenceKeypoint.new(0.35, s * 0.55),
		NumberSequenceKeypoint.new(1, s * 0.08),
	})
	flames.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.18, 0.12),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 150)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 150, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 44, 20)),
	})
	flames.LightEmission = 1
	flames.LightInfluence = 0
	flames.ZOffset = 0.2
	flames.Parent = part

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = Effects.SparkTexture
	embers.Rate = 2.5
	embers.Lifetime = NumberRange.new(1.4, 2.6)
	embers.Speed = NumberRange.new(s * 1.2, s * 2.4)
	embers.SpreadAngle = Vector2.new(22, 22)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Acceleration = Vector3.new(0.9, 0.6, 0.3)
	embers.Drag = 0.8
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(230, 90, 30))
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Parent = part

	local smoke = Effects.smoke(part, { Rate = 1.5, Size = s * 0.45, Rise = s * 0.9, Opacity = 0.3 })
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 66, 62), Color3.fromRGB(140, 138, 134))

	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = Color3.fromRGB(255, 160, 90)
	light.Brightness = 1.2
	light.Range = 14
	light.Shadows = false
	light.Parent = part
	return { flames, embers, smoke }
end

-- Light snowfall over an area: `part` is an invisible slab above the area;
-- flakes fall from its bottom face, turning and drifting with the wind.
function Effects.snowfall(part: BasePart, rate: number?): ParticleEmitter
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "Snowfall"
	snow.Texture = Effects.SmokeTexture
	snow.Rate = rate or 10
	snow.Lifetime = NumberRange.new(8, 10)
	snow.Speed = NumberRange.new(2.4, 3.4)
	snow.SpreadAngle = Vector2.new(18, 18)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Acceleration = Vector3.new(0.35, 0, 0.15)
	snow.Drag = 0.3
	snow.Rotation = NumberRange.new(0, 360)
	snow.RotSpeed = NumberRange.new(-60, 60)
	snow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.16),
	})
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0.15),
		NumberSequenceKeypoint.new(0.9, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	snow.Color = ColorSequence.new(Color3.fromRGB(246, 248, 250))
	snow.LightEmission = 0.2
	snow.LightInfluence = 1
	snow.Parent = part
	return snow
end

-- The plume of a fan snow gun: fine mist and flakes blown out of the
-- barrel mouth (`part`'s front face), arcing down with the wind.
function Effects.snowPlume(part: BasePart, rate: number?): ParticleEmitter
	local plume = Instance.new("ParticleEmitter")
	plume.Name = "SnowPlume"
	plume.Texture = Effects.SmokeTexture
	plume.Rate = rate or 9
	plume.Lifetime = NumberRange.new(2.6, 3.6)
	plume.Speed = NumberRange.new(16, 22)
	plume.SpreadAngle = Vector2.new(10, 10)
	plume.EmissionDirection = Enum.NormalId.Front
	plume.Acceleration = Vector3.new(0.6, -3.2, 0.2)
	plume.Drag = 1.1
	plume.Rotation = NumberRange.new(0, 360)
	plume.RotSpeed = NumberRange.new(-30, 30)
	plume.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 3.4),
	})
	plume.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	plume.Color = ColorSequence.new(Color3.fromRGB(240, 244, 248))
	plume.LightInfluence = 1
	plume.Parent = part
	return plume
end

return Effects
