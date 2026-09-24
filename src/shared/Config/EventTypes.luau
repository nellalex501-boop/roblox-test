--!strict
-- Shared type definitions for seasonal events (see Config/Events).

export type Tracker = {
	Type: "Stat" | "Distinct" | "Interaction",
	Stat: string?,
	Kind: string?,
	Id: string?,
	DistinctIds: boolean?,
}

export type Challenge = { Id: string, Text: string, Target: number, Points: number, Tracker: Tracker }

export type RewardTier = { Points: number, Name: string, Kind: string, Value: any }

export type Event = {
	Id: string,
	Label: string,
	Title: string,
	Codename: string,
	Tagline: string,
	Description: string,
	StartsAt: number,
	EndsAt: number,
	FeaturedMap: string?,
	FeaturedMapName: string?,
	LimitedUnits: { string },
	Dressing: string,
	Palette: { Primary: Color3, Secondary: Color3, Text: Color3 },
	Challenges: { Challenge },
	Rewards: { RewardTier },
}

return {}
