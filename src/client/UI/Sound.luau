--!strict
-- 2D interface sounds (PlayLocalSound: local only, never replicated).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Sounds = require(Lobby:WaitForChild("Config"):WaitForChild("Sounds"))

local Sound = {}

Sound.Enabled = true

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

local function get(name: string): Sound?
	local existing = cache[name]
	if existing then
		return existing
	end
	local def = Sounds.UI[name]
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "LobbyUI_" .. name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.Parent = SoundService
	cache[name] = sound
	return sound
end

function Sound.play(name: string)
	if not Sound.Enabled then
		return
	end
	-- the same cue at most every 60 ms (lists firing many clicks at once)
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.06 then
		return
	end
	lastPlayed[name] = now
	local sound = get(name)
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

function Sound.preload()
	for name in Sounds.UI do
		get(name)
	end
end

return Sound
