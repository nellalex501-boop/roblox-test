--!strict
-- Positional ambience: every "Sound" anchor gets its looped sound (command
-- room tone, radio chatter, teletype, radar bleeps, transformer hum, idling
-- truck, canteen chatter, distant traffic), fire anchors crackle, a couple
-- of plaza flags snap in the wind, and a quiet 2D wind bed plays
-- everywhere. Sources far from the camera are paused (checked once a
-- second) so only nearby loops cost anything.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Sounds = require(Lobby:WaitForChild("Config"):WaitForChild("Sounds"))

local AmbientSound = {}

AmbientSound.Tag = "LobbyAmbient"
AmbientSound.Margin = 25 -- extra studs beyond RollOffMax before pausing
AmbientSound.MaxFlagSounds = 2

type Source = { part: BasePart, sound: Sound, range: number }

local sources: { [BasePart]: Source } = {}
local flagSources = 0
local wind: Sound? = nil
local rng = Random.new(1986)

local function create(parent: Instance, name: string, def: Sounds.SoundDef): Sound
	local sound = Instance.new("Sound")
	sound.Name = "Ambient_" .. name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.Looped = def.Looped ~= false
	sound.PlaybackSpeed = def.Speed or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = def.RollOffMin or 10
	sound.RollOffMaxDistance = def.RollOffMax or 60
	sound.Parent = parent
	return sound
end

local function soundFor(part: BasePart): string?
	local role = part:GetAttribute("AmbientRole")
	local value = part:GetAttribute("AmbientValue")
	if role == "Sound" and type(value) == "string" then
		return value
	elseif role == "Fire" then
		return "FireBarrel"
	elseif role == "Flag" and flagSources < AmbientSound.MaxFlagSounds then
		-- only flags on the parade square (the landmark semicircle)
		local pos = part.CFrame.Position
		if math.abs(pos.X) < 40 and math.abs(pos.Z + 4) < 40 then
			flagSources += 1
			return "Flags"
		end
	end
	return nil
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or sources[instance] then
		return
	end
	local name = soundFor(instance)
	local def = name and Sounds.Ambient[name]
	if not name or not def then
		return
	end
	local sound = create(instance, name, def)
	sources[instance] = { part = instance, sound = sound, range = (def.RollOffMax or 60) + AmbientSound.Margin }
end

local function untrack(instance: Instance)
	if instance:IsA("BasePart") then
		local source = sources[instance]
		if source then
			source.sound:Destroy()
			sources[instance] = nil
		end
	end
end

-- Plays sources in range of `eye`, pauses the rest. Returns how many play.
function AmbientSound.update(eye: Vector3): number
	local playing = 0
	for _, source in sources do
		local near = (source.part.CFrame.Position - eye).Magnitude <= source.range
		local sound = source.sound
		if near then
			playing += 1
			if not sound.IsPlaying then
				-- start loops at different points so repeats never line up
				sound.TimePosition = rng:NextNumber(0, 8)
				sound:Play()
			end
		elseif sound.IsPlaying then
			sound:Pause()
		end
	end
	return playing
end

function AmbientSound.sourceCount(): number
	local n = 0
	for _ in sources do
		n += 1
	end
	return n
end

function AmbientSound.start()
	local windDef = Sounds.Ambient.Wind
	if windDef then
		local bed = create(SoundService, "Wind", windDef)
		wind = bed
		bed:Play()
	end
	for _, part in CollectionService:GetTagged(AmbientSound.Tag) do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal(AmbientSound.Tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(AmbientSound.Tag):Connect(untrack)
	task.spawn(function()
		while true do
			local camera = workspace.CurrentCamera
			if camera then
				AmbientSound.update(camera.CFrame.Position)
			end
			task.wait(1)
		end
	end)
end

function AmbientSound.wind(): Sound?
	return wind
end

return AmbientSound
