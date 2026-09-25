--!strict
-- Event schedule. The Event Area and event UI always show the event that is
-- active *now*; when none is, a standby briefing is shown instead.
--
-- Replacing an event: add a module (copy IronWinter.luau), give it new
-- dates/texts, and add it to `Schedule`. Set `Override` to an event id to
-- preview an event outside its dates (e.g. while building it in Studio).

local Types = require(script.Parent.EventTypes)

export type Event = Types.Event
export type Challenge = Types.Challenge
export type RewardTier = Types.RewardTier

local Events = {}

Events.Schedule = {
	require(script.IronWinter) :: Event,
}

Events.Override = nil :: string?

Events.Standby = {
	Id = "STANDBY",
	Label = "NO ACTIVE OPERATION",
	Title = "STAND BY",
	Codename = "NEXT OPERATION PENDING",
	Tagline = "AWAITING ORDERS FROM THEATER COMMAND",
	Description = "No special operation is running. Check back soon for the next seasonal operation.",
	StartsAt = 0,
	EndsAt = 0,
	FeaturedMap = nil,
	FeaturedMapName = nil,
	LimitedUnits = {},
	Dressing = "Standby",
	Palette = {
		Primary = Color3.fromRGB(150, 148, 136),
		Secondary = Color3.fromRGB(80, 84, 76),
		Text = Color3.fromRGB(220, 216, 200),
	},
	Challenges = {},
	Rewards = {},
} :: Event

function Events.current(now: number): Event
	for _, event in Events.Schedule do
		if Events.Override == event.Id then
			return event
		end
	end
	for _, event in Events.Schedule do
		if now >= event.StartsAt and now < event.EndsAt then
			return event
		end
	end
	return Events.Standby
end

-- Whole days left, rounded up (an event ending in 22.5 days shows 23).
function Events.daysRemaining(event: Event, now: number): number
	if event.EndsAt <= 0 then
		return 0
	end
	return math.max(0, math.ceil((event.EndsAt - now) / 86400))
end

return Events
