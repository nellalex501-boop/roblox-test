--!strict
-- Leaderboard definitions shared by the physical boards (server) and the
-- leaderboard UI (client). Stat = profile stat path ("xp" = total XP).

export type Board = { Id: string, Title: string, Subtitle: string, Stat: string, Unit: string }

local Leaderboards = {}

Leaderboards.Boards = {
	{ Id = "TOP_COMMANDERS", Title = "TOP COMMANDERS", Subtitle = "BY EXPERIENCE", Stat = "xp", Unit = "XP" },
	{ Id = "MOST_VICTORIES", Title = "MOST VICTORIES", Subtitle = "ALL TIME", Stat = "victories", Unit = "WINS" },
	{ Id = "MOST_MATCHES", Title = "MOST MATCHES", Subtitle = "ALL TIME", Stat = "matches", Unit = "MATCHES" },
	{
		Id = "MOST_TERRITORY",
		Title = "MOST TERRITORY CAPTURED",
		Subtitle = "SECTORS HELD",
		Stat = "sectorsCaptured",
		Unit = "SECTORS",
	},
	{
		Id = "CURRENT_SEASON",
		Title = "CURRENT SEASON",
		Subtitle = "SEASON 1 · RATING",
		Stat = "rating",
		Unit = "RATING",
	},
} :: { Board }

Leaderboards.Rows = 10
Leaderboards.RefreshInterval = 90
Leaderboards.StorePrefix = "ColdWarLobby_LB_v1_"

return Leaderboards
