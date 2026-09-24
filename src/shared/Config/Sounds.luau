--!strict
-- Audio used by the lobby. All ids are public Roblox Creator Store sound
-- effects from the "ProSoundEffects" library (verified with
-- tools/verify_sounds.py). Volumes are deliberately low: the lobby should
-- feel alive, never loud.

export type SoundDef = {
	Id: string,
	Volume: number,
	Looped: boolean?,
	RollOffMin: number?,
	RollOffMax: number?,
	Speed: number?,
}

local function asset(id: number): string
	return "rbxassetid://" .. tostring(id)
end

local Sounds = {}

-- Positional loops, attached to world anchors named in the world builder.
Sounds.Ambient = {
	Wind = { Id = asset(9113286969), Volume = 0.18, Looped = true },
	CommandRoom = { Id = asset(9125446564), Volume = 0.35, Looped = true, RollOffMin = 20, RollOffMax = 70 },
	RadioChatter = { Id = asset(9125774208), Volume = 0.22, Looped = true, RollOffMin = 8, RollOffMax = 45 },
	Teletype = { Id = asset(9119382296), Volume = 0.2, Looped = true, RollOffMin = 8, RollOffMax = 40 },
	RadarBleeps = { Id = asset(9112776779), Volume = 0.14, Looped = true, RollOffMin = 6, RollOffMax = 30 },
	Transformer = { Id = asset(9112889082), Volume = 0.3, Looped = true, RollOffMin = 6, RollOffMax = 40 },
	TruckIdle = { Id = asset(9112988114), Volume = 0.25, Looped = true, RollOffMin = 6, RollOffMax = 45, Speed = 0.8 },
	FireBarrel = { Id = asset(9112780193), Volume = 0.35, Looped = true, RollOffMin = 4, RollOffMax = 30 },
	Canteen = { Id = asset(9112862413), Volume = 0.22, Looped = true, RollOffMin = 12, RollOffMax = 50 },
	DistantTraffic = { Id = asset(9112771906), Volume = 0.3, Looped = true, RollOffMin = 30, RollOffMax = 160 },
	Flags = { Id = asset(9114461215), Volume = 0.16, Looped = true, RollOffMin = 8, RollOffMax = 50 },
} :: { [string]: SoundDef }

-- Occasional distant helicopter pass over the base.
Sounds.Flyby = { Id = asset(9113416405), Volume = 0.4, RollOffMin = 60, RollOffMax = 600 } :: SoundDef

-- Short interface sounds (played on the client, 2D).
Sounds.UI = {
	Click = { Id = asset(9119717523), Volume = 0.35 },
	Open = { Id = asset(9113880475), Volume = 0.3 },
	Close = { Id = asset(9119717529), Volume = 0.3 },
	Confirm = { Id = asset(9113867159), Volume = 0.35 },
	Error = { Id = asset(9113880642), Volume = 0.35 },
	Paper = { Id = asset(9125723307), Volume = 0.45 },
	Map = { Id = asset(9125654187), Volume = 0.45 },
	Typing = { Id = asset(9116158128), Volume = 0.2 },
	MatchFound = { Id = asset(9126073011), Volume = 0.45 },
	Reward = { Id = asset(9113867249), Volume = 0.4 },
} :: { [string]: SoundDef }

return Sounds
