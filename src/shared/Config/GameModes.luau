--!strict
-- Matchmaking modes offered by the physical terminals in the Operations Center.

export type Mode = {
	Id: string,
	Title: string,
	Subtitle: string,
	SignText: string,
	TeamSize: number?, -- nil = flexible (Quick Match)
	PlayersLabel: string,
	ColorKey: string,
	Description: string,
	TerminalLabel: string,
	Rules: { string }, -- rules of engagement on the terminal panel (one short line each)
	MatchLength: string,
}

local GameModes = {}

GameModes.Order = { "PRIVATE", "1V1", "QUICK", "2V2", "4V4" }

GameModes.Modes = {
	QUICK = {
		Id = "QUICK",
		Title = "QUICK MATCH",
		Subtitle = "FASTEST AVAILABLE BATTLE",
		SignText = "QUICK MATCH",
		TeamSize = nil,
		PlayersLabel = "2–8 PLAYERS",
		ColorKey = "QUICK",
		Description = "Joins the first battle that can start: fills open 4v4, 2v2 or 1v1 queues, otherwise pairs you with other quick-match commanders.",
		TerminalLabel = "QUICK MATCH TERMINAL",
		Rules = {
			"Joins the first battle ready",
			"Capture and hold sectors",
			"Preferred map when it fits",
		},
		MatchLength = "15–35 MIN",
	},
	["1V1"] = {
		Id = "1V1",
		Title = "1v1 DUEL",
		Subtitle = "COMMANDER VS COMMANDER",
		SignText = "1 v 1",
		TeamSize = 1,
		PlayersLabel = "2 PLAYERS",
		ColorKey = "DUEL",
		Description = "Head-to-head battle on small and medium maps. You control the whole battlegroup.",
		TerminalLabel = "1v1 DUEL TERMINAL",
		Rules = {
			"You command the battlegroup",
			"Capture and hold sectors",
			"Small and medium maps",
		},
		MatchLength = "15–20 MIN",
	},
	["2V2"] = {
		Id = "2V2",
		Title = "2v2 TEAM MATCH",
		Subtitle = "TWO-COMMANDER TEAMS",
		SignText = "2 v 2",
		TeamSize = 2,
		PlayersLabel = "4 PLAYERS",
		ColorKey = "TEAM",
		Description = "Coordinate with an allied commander to hold the line across a shared front.",
		TerminalLabel = "2v2 TEAM MATCH TERMINAL",
		Rules = {
			"Two commanders, one front",
			"Capture and hold sectors",
			"Medium and large maps",
		},
		MatchLength = "20–25 MIN",
	},
	["4V4"] = {
		Id = "4V4",
		Title = "4v4 LARGE BATTLE",
		Subtitle = "FULL DIVISION ENGAGEMENT",
		SignText = "4 v 4",
		TeamSize = 4,
		PlayersLabel = "8 PLAYERS",
		ColorKey = "LARGE",
		Description = "Large-scale combined arms battle on the biggest maps of the Fulda sector.",
		TerminalLabel = "4v4 LARGE BATTLE TERMINAL",
		Rules = {
			"Each commander holds a sector",
			"Capture and hold sectors",
			"The largest maps",
		},
		MatchLength = "25–35 MIN",
	},
	PRIVATE = {
		Id = "PRIVATE",
		Title = "PRIVATE MATCH",
		Subtitle = "INVITE-ONLY OPERATION",
		SignText = "PRIVATE",
		TeamSize = nil,
		PlayersLabel = "2–8 PLAYERS",
		ColorKey = "PRIVATE",
		Description = "Create a sealed operation with an access code, choose size and map, and deploy when your group is ready.",
		TerminalLabel = "PRIVATE MATCH TERMINAL",
		Rules = {
			"Share the access code",
			"The host picks size and map",
			"Deploy when everyone is ready",
		},
		MatchLength = "HOST'S CHOICE",
	},
} :: { [string]: Mode }

-- Fixed-size modes that queues can form directly, largest first.
GameModes.QueueModes = { "4V4", "2V2", "1V1" }

-- Sizes a private match host can pick.
GameModes.PrivateSizes = { "1V1", "2V2", "4V4" }

GameModes.Settings = {
	-- Place that hosts the actual RTS battle. 0 = no teleport; the lobby
	-- simulates deployment instead (used in Studio and until configured).
	TargetPlaceId = 0,
	TickInterval = 1,
	DeployCountdown = 5,
	-- Players must stand near a matching terminal to queue (anti-exploit and
	-- keeps matchmaking physical). Distance in studs from the terminal.
	RequireProximity = true,
	ProximityRange = 20,
	PrivateCodeLength = 5,
	MaxPrivateLobbies = 50,
}

function GameModes.playersNeeded(modeId: string): number?
	local mode = GameModes.Modes[modeId]
	if mode and mode.TeamSize then
		return mode.TeamSize * 2
	end
	return nil
end

return GameModes
