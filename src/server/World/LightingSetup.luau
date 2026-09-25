--!strict
-- Late-afternoon, slightly hazy central-European light with muted colour
-- grading. Existing singleton effects (Atmosphere, Sky) are reused and
-- re-tuned rather than duplicated; depth of field is disabled because it
-- blurs distant signage.

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

function LightingSetup.apply()
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 50.5
	Lighting.Brightness = 2.3
	-- Ambient lights only what the sky cannot reach: the interiors
	Lighting.Ambient = Color3.fromRGB(112, 112, 106)
	Lighting.OutdoorAmbient = Color3.fromRGB(126, 128, 120)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.ExposureCompensation = 0

	local atmosphere: Atmosphere = ensure("Atmosphere", "LobbyAtmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(198, 196, 184)
	atmosphere.Decay = Color3.fromRGB(104, 104, 92)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.6

	local sky: Sky = ensure("Sky", "LobbySky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 1200
	sky.CelestialBodiesShown = true

	local grading: ColorCorrectionEffect = ensure("ColorCorrectionEffect", "LobbyGrading")
	grading.Saturation = -0.12
	grading.Contrast = 0.08
	grading.Brightness = 0.01
	grading.TintColor = Color3.fromRGB(255, 250, 240)
	grading.Enabled = true

	local bloom: BloomEffect = ensure("BloomEffect", "LobbyBloom")
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.4
	bloom.Enabled = true

	local rays: SunRaysEffect = ensure("SunRaysEffect", "LobbySunRays")
	rays.Intensity = 0.035
	rays.Spread = 0.6
	rays.Enabled = true

	for _, child in Lighting:GetChildren() do
		if child:IsA("DepthOfFieldEffect") then
			child.Enabled = false
		end
	end
end

return LightingSetup
