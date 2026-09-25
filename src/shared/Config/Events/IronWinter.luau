--!strict
-- Seasonal event: OPERATION IRON WINTER.
-- To run a different event, add a module next to this one and list it in
-- Events/init.luau. The permanent Event Area structure stays; only the
-- dressing named by `Dressing` and the texts below change.

local Types = require(script.Parent.Parent.EventTypes)

local event: Types.Event = {
	Id = "IRON_WINTER",
	Label = "CURRENT OPERATION",
	Title = "IRON WINTER",
	Codename = "OPERATION IRON WINTER",
	Tagline = "THE FULDA SECTOR FREEZES OVER",
	Description = "An early winter has frozen the Fulda. Ice opens new river crossings and Warsaw Pact armor is massing in whitewash. Hold the line until the thaw.",
	-- Unix timestamps (UTC): 2026-09-15 00:00 → 2026-10-17 00:00.
	StartsAt = 1789430400,
	EndsAt = 1792195200,
	FeaturedMap = "RIVER_CROSSING",
	FeaturedMapName = "FROZEN RIVER CROSSING",
	LimitedUnits = { "T80BV_ZIMA" },
	Dressing = "Winter",
	Palette = {
		Primary = Color3.fromRGB(190, 204, 212),
		Secondary = Color3.fromRGB(88, 110, 128),
		Text = Color3.fromRGB(232, 236, 238),
	},
	Challenges = {
		{
			Id = "IW_RIVER_WINS",
			Text = "Win 2 matches on Frozen River Crossing",
			Target = 2,
			Points = 150,
			Tracker = { Type = "Stat", Stat = "victoriesByMap.RIVER_CROSSING" },
		},
		{
			Id = "IW_SECTORS",
			Text = "Capture 25 sectors",
			Target = 25,
			Points = 250,
			Tracker = { Type = "Stat", Stat = "sectorsCaptured" },
		},
		{
			Id = "IW_DESTROY",
			Text = "Destroy 40 enemy units",
			Target = 40,
			Points = 200,
			Tracker = { Type = "Stat", Stat = "unitsDestroyed" },
		},
		{
			Id = "IW_BRIEFING",
			Text = "Read the Iron Winter briefing",
			Target = 1,
			Points = 50,
			Tracker = { Type = "Interaction", Kind = "Event" },
		},
		{
			Id = "IW_INSPECT",
			Text = "Inspect the T-80BV 'Zima'",
			Target = 1,
			Points = 50,
			Tracker = { Type = "Interaction", Kind = "UnitInspect", Id = "T80BV_ZIMA" },
		},
	},
	Rewards = {
		{ Points = 100, Name = "500 CREDITS", Kind = "Credits", Value = 500 },
		{ Points = 250, Name = "WINTER WHITEWASH CAMO", Kind = "Camo", Value = "WINTER" },
		{ Points = 450, Name = "TITLE: WINTER WOLF", Kind = "Title", Value = "WINTER_WOLF" },
		{ Points = 650, Name = "T-80BV 'ZIMA'", Kind = "Unit", Value = "T80BV_ZIMA" },
	},
}

return event
