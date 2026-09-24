--!strict
-- Static ambient effects (Phase 4): chimney / stove smoke and brazier fire.
-- Emission rates are deliberately low; the client ambient pass (Phase 5)
-- adds light flicker and sound on the same anchors.

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

-- Small wood fire with a warm, non-shadowed light.
function Effects.fire(part: BasePart, size: number?): Fire
	local fire = Instance.new("Fire")
	fire.Name = "Flames"
	fire.Size = size or 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(236, 132, 60)
	fire.SecondaryColor = Color3.fromRGB(120, 60, 30)
	fire.Parent = part
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = Color3.fromRGB(255, 160, 90)
	light.Brightness = 1.2
	light.Range = 14
	light.Shadows = false
	light.Parent = part
	return fire
end

return Effects
