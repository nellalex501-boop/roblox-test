--!strict
-- Commander progression: XP curve, rank ladder per faction, titles and
-- insignia used by the Commander Profile.

local Progression = {}

-- Total XP needed to reach a level: 50 * L * (L - 1).
-- L2 = 100 XP, L10 = 4 500 XP, L30 = 43 500 XP, L50 = 122 500 XP.
Progression.MaxLevel = 100

function Progression.xpForLevel(level: number): number
	return 50 * level * (level - 1)
end

function Progression.levelForXp(xp: number): number
	-- Solve 50L(L-1) <= xp for the largest integer L.
	local level = math.floor((1 + math.sqrt(1 + 4 * math.max(xp, 0) / 50)) / 2)
	return math.clamp(level, 1, Progression.MaxLevel)
end

-- Returns level, xp into the level, xp needed for the next level.
function Progression.levelProgress(xp: number): (number, number, number)
	local level = Progression.levelForXp(xp)
	local base = Progression.xpForLevel(level)
	local nextXp = Progression.xpForLevel(level + 1)
	return level, xp - base, nextXp - base
end

export type Rank = { Level: number, Short: string, NATO: string, PACT: string }

Progression.Ranks = {
	{ Level = 1, Short = "PVT", NATO = "PRIVATE", PACT = "RYADOVOY" },
	{ Level = 3, Short = "PFC", NATO = "PRIVATE FIRST CLASS", PACT = "YEFREYTOR" },
	{ Level = 5, Short = "CPL", NATO = "CORPORAL", PACT = "MLADSHIY SERZHANT" },
	{ Level = 8, Short = "SGT", NATO = "SERGEANT", PACT = "SERZHANT" },
	{ Level = 12, Short = "SSG", NATO = "STAFF SERGEANT", PACT = "STARSHIY SERZHANT" },
	{ Level = 16, Short = "2LT", NATO = "SECOND LIEUTENANT", PACT = "MLADSHIY LEYTENANT" },
	{ Level = 20, Short = "1LT", NATO = "FIRST LIEUTENANT", PACT = "LEYTENANT" },
	{ Level = 25, Short = "CPT", NATO = "CAPTAIN", PACT = "KAPITAN" },
	{ Level = 30, Short = "MAJ", NATO = "MAJOR", PACT = "MAYOR" },
	{ Level = 36, Short = "LTC", NATO = "LIEUTENANT COLONEL", PACT = "PODPOLKOVNIK" },
	{ Level = 42, Short = "COL", NATO = "COLONEL", PACT = "POLKOVNIK" },
	{ Level = 50, Short = "BG", NATO = "BRIGADIER GENERAL", PACT = "GENERAL-MAYOR" },
	{ Level = 60, Short = "MG", NATO = "MAJOR GENERAL", PACT = "GENERAL-LEYTENANT" },
	{ Level = 75, Short = "GEN", NATO = "GENERAL", PACT = "GENERAL ARMII" },
} :: { Rank }

function Progression.rankFor(level: number): Rank
	local current = Progression.Ranks[1]
	for _, rank in Progression.Ranks do
		if level >= rank.Level then
			current = rank
		end
	end
	return current
end

function Progression.rankName(level: number, faction: string): string
	local rank = Progression.rankFor(level)
	return if faction == "PACT" then rank.PACT else rank.NATO
end

-- Titles shown under the commander name. Requirement is checked server-side.
export type Title =
	{ Id: string, Name: string, Requirement: string, Level: number?, Victories: number?, Event: string? }

Progression.Titles = {
	{ Id = "RECRUIT", Name = "RECRUIT", Requirement = "DEFAULT" },
	{ Id = "TANKER", Name = "TANKER", Requirement = "REACH LEVEL 5", Level = 5 },
	{ Id = "FIELD_COMMANDER", Name = "FIELD COMMANDER", Requirement = "WIN 10 MATCHES", Victories = 10 },
	{ Id = "STRATEGIST", Name = "STRATEGIST", Requirement = "REACH LEVEL 20", Level = 20 },
	{ Id = "IRON_FIST", Name = "IRON FIST", Requirement = "WIN 50 MATCHES", Victories = 50 },
	{ Id = "WINTER_WOLF", Name = "WINTER WOLF", Requirement = "OPERATION IRON WINTER REWARD", Event = "IRON_WINTER" },
} :: { Title }

export type Insignia = { Id: string, Name: string, Short: string, Color: Color3, Level: number }

Progression.Insignia = {
	{ Id = "BORDER_CAV", Name = "1ST BORDER CAVALRY", Short = "1BC", Color = Color3.fromRGB(88, 120, 152), Level = 1 },
	{ Id = "ARMORED_7", Name = "7TH ARMOURED BRIGADE", Short = "7AB", Color = Color3.fromRGB(112, 132, 84), Level = 1 },
	{
		Id = "GUARDS_TANK",
		Name = "GUARDS TANK DIVISION",
		Short = "GTD",
		Color = Color3.fromRGB(164, 74, 62),
		Level = 3,
	},
	{ Id = "RECON_44", Name = "RECON BATTALION 44", Short = "R44", Color = Color3.fromRGB(190, 150, 70), Level = 8 },
	{ Id = "ARTY_3", Name = "3RD FIELD ARTILLERY", Short = "3FA", Color = Color3.fromRGB(124, 118, 102), Level = 12 },
} :: { Insignia }

export type Achievement = { Id: string, Name: string, Description: string, Stat: string, Target: number }

Progression.Achievements = {
	{
		Id = "FIRST_BLOOD",
		Name = "FIRST DEPLOYMENT",
		Description = "Play your first match.",
		Stat = "matches",
		Target = 1,
	},
	{ Id = "FIRST_WIN", Name = "FIRST VICTORY", Description = "Win a match.", Stat = "victories", Target = 1 },
	{ Id = "VETERAN", Name = "VETERAN", Description = "Play 50 matches.", Stat = "matches", Target = 50 },
	{
		Id = "CONQUEROR",
		Name = "CONQUEROR",
		Description = "Capture 100 sectors.",
		Stat = "sectorsCaptured",
		Target = 100,
	},
	{
		Id = "TANK_ACE",
		Name = "TANK ACE",
		Description = "Destroy 250 enemy units.",
		Stat = "unitsDestroyed",
		Target = 250,
	},
	{
		Id = "CARTOGRAPHER",
		Name = "CARTOGRAPHER",
		Description = "Play every map in the Fulda sector.",
		Stat = "mapsPlayedCount",
		Target = 7,
	},
	{
		Id = "TEAM_PLAYER",
		Name = "TEAM PLAYER",
		Description = "Complete 25 team battles.",
		Stat = "teamBattles",
		Target = 25,
	},
} :: { Achievement }

return Progression
