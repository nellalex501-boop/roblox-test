--!strict
-- Mission definitions for the physical mission board.
--
-- Tracker kinds:
--   Stat        progress = profile stat now - stat at the start of the period
--   Distinct    progress = number of new distinct entries in a stat set
--   Interaction progress = number of lobby interactions of a kind (optionally
--               counting distinct interaction ids only)
-- Match stats are written by the RTS match servers; interaction missions are
-- completed inside the lobby and double as a no-tutorial orientation.

local EventTypes = require(script.Parent.EventTypes)

export type Tracker = EventTypes.Tracker

export type Mission = {
	Id: string,
	Group: string, -- "DAILY" | "ORIENTATION"
	Text: string,
	Target: number,
	Tracker: Tracker,
	Reward: { Credits: number, XP: number },
}

local Missions = {}

Missions.Groups = {
	DAILY = { Title = "CURRENT OPERATIONS", Subtitle = "RESETS DAILY 00:00 UTC" },
	ORIENTATION = { Title = "ORIENTATION ORDERS", Subtitle = "ONE-TIME · NEW COMMANDERS" },
}

Missions.Order = {
	"CAPTURE_10",
	"WIN_3",
	"MAPS_5",
	"TEAM_1",
	"ORI_TERMINAL",
	"ORI_MAP",
	"ORI_INSPECT",
	"ORI_PROFILE",
	"ORI_LEADERBOARD",
	"ORI_EVENT",
}

Missions.List = {
	CAPTURE_10 = {
		Id = "CAPTURE_10",
		Group = "DAILY",
		Text = "Capture 10 sectors",
		Target = 10,
		Tracker = { Type = "Stat", Stat = "sectorsCaptured" },
		Reward = { Credits = 150, XP = 200 },
	},
	WIN_3 = {
		Id = "WIN_3",
		Group = "DAILY",
		Text = "Win 3 matches",
		Target = 3,
		Tracker = { Type = "Stat", Stat = "victories" },
		Reward = { Credits = 200, XP = 300 },
	},
	MAPS_5 = {
		Id = "MAPS_5",
		Group = "DAILY",
		Text = "Play 5 different maps",
		Target = 5,
		Tracker = { Type = "Distinct", Stat = "mapsPlayed" },
		Reward = { Credits = 150, XP = 250 },
	},
	TEAM_1 = {
		Id = "TEAM_1",
		Group = "DAILY",
		Text = "Complete a team battle",
		Target = 1,
		Tracker = { Type = "Stat", Stat = "teamBattles" },
		Reward = { Credits = 100, XP = 150 },
	},
	ORI_TERMINAL = {
		Id = "ORI_TERMINAL",
		Group = "ORIENTATION",
		Text = "Use a matchmaking terminal in the Operations Center",
		Target = 1,
		Tracker = { Type = "Interaction", Kind = "Matchmaking" },
		Reward = { Credits = 50, XP = 50 },
	},
	ORI_MAP = {
		Id = "ORI_MAP",
		Group = "ORIENTATION",
		Text = "Study a battle map in the Map Room",
		Target = 1,
		Tracker = { Type = "Interaction", Kind = "MapInfo" },
		Reward = { Credits = 50, XP = 50 },
	},
	ORI_INSPECT = {
		Id = "ORI_INSPECT",
		Group = "ORIENTATION",
		Text = "Inspect 3 different vehicles in the Garage",
		Target = 3,
		Tracker = { Type = "Interaction", Kind = "UnitInspect", DistinctIds = true },
		Reward = { Credits = 75, XP = 75 },
	},
	ORI_PROFILE = {
		Id = "ORI_PROFILE",
		Group = "ORIENTATION",
		Text = "Review your Commander Profile at Command HQ",
		Target = 1,
		Tracker = { Type = "Interaction", Kind = "Profile" },
		Reward = { Credits = 50, XP = 50 },
	},
	ORI_LEADERBOARD = {
		Id = "ORI_LEADERBOARD",
		Group = "ORIENTATION",
		Text = "Check the Hall of Commanders",
		Target = 1,
		Tracker = { Type = "Interaction", Kind = "Leaderboard" },
		Reward = { Credits = 50, XP = 50 },
	},
	ORI_EVENT = {
		Id = "ORI_EVENT",
		Group = "ORIENTATION",
		Text = "Read the current operation briefing",
		Target = 1,
		Tracker = { Type = "Interaction", Kind = "Event" },
		Reward = { Credits = 50, XP = 50 },
	},
} :: { [string]: Mission }

return Missions
