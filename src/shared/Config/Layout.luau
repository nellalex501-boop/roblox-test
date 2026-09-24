--!strict
-- Single source of truth for where every lobby zone sits.
--
-- World axes: +X east, -Z north, Y up. Ground level is Y = 0. The central
-- spawn faces north toward the Operations Center.
--
-- Every zone is described by the centre of its entrance side ("Facade") and
-- the direction pointing into the zone ("Inward"). Layout.frame(zone) turns
-- that into a CFrame whose local axes are:
--   -Z  into the zone        +Z  out toward the road/plaza
--   +X  to the right when standing outside looking at the entrance
-- Zone builders work entirely in that local space, so a zone can be moved or
-- rotated here without touching its builder.

export type ZoneKind = "Building" | "Open"

export type Zone = {
	Id: string,
	DisplayName: string,
	Subtitle: string,
	Kind: ZoneKind,
	Facade: Vector3,
	Inward: Vector3,
	Width: number,
	Depth: number,
	Height: number,
	Entrances: { { Offset: number, Width: number, Height: number } },
	Locator: boolean,
}

export type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

local Layout = {}

Layout.GroundY = 0
Layout.StudsToMeters = 0.3

Layout.Plaza = { MinX = -66, MaxX = 66, MinZ = -50, MaxZ = 50 } :: Rect

-- Central landmark: raised dais with the theatre map.
Layout.Dais = {
	Center = Vector3.new(0, 0, -4),
	Radius = 23,
	StepHeight = 0.6,
	Steps = 2,
}

-- Assembly point in front of (south of) the dais. Players spawn facing north.
Layout.Spawn = {
	Center = Vector3.new(0, 0, 27),
	Count = 8,
	Spacing = 6,
	ArcDepth = 3,
}

Layout.RoadWidth = 12
Layout.SidewalkWidth = 3

-- Paved roads as axis-aligned rectangles (drawn in this order).
Layout.Roads = {
	{ Name = "NorthRoad", MinX = -150, MaxX = 196, MinZ = -64, MaxZ = -52 },
	{ Name = "SouthRoad", MinX = -150, MaxX = 150, MinZ = 52, MaxZ = 64 },
	{ Name = "WestRoad", MinX = -80, MaxX = -68, MinZ = -64, MaxZ = 64 },
	{ Name = "EastRoad", MinX = 68, MaxX = 80, MinZ = -64, MaxZ = 64 },
	{ Name = "OutsideRoad", MinX = 204, MaxX = 216, MinZ = -260, MaxZ = 260 },
} :: { Rect & { Name: string } }

Layout.Perimeter = { MinX = -190, MaxX = 192, MinZ = -172, MaxZ = 176 } :: Rect

-- Main gate sits where the north road leaves the base on the east side.
Layout.Gate = {
	Center = Vector3.new(192, 0, -58),
	Width = 16,
}

Layout.Zones = {
	OperationsCenter = {
		Id = "OperationsCenter",
		DisplayName = "OPERATIONS CENTER",
		Subtitle = "MATCHMAKING · DEPLOYMENT",
		Kind = "Building",
		Facade = Vector3.new(0, 0, -72),
		Inward = Vector3.new(0, 0, -1),
		Width = 100,
		Depth = 64,
		Height = 26,
		Entrances = { { Offset = 0, Width = 16, Height = 13 } },
		Locator = true,
	},
	MapRoom = {
		Id = "MapRoom",
		DisplayName = "MAP ROOM",
		Subtitle = "THEATRE PLANNING · MAP SELECTION",
		Kind = "Building",
		Facade = Vector3.new(-100, 0, -72),
		Inward = Vector3.new(0, 0, -1),
		Width = 52,
		Depth = 48,
		Height = 18,
		Entrances = { { Offset = 0, Width = 12, Height = 11 } },
		Locator = true,
	},
	CommandHQ = {
		Id = "CommandHQ",
		DisplayName = "COMMAND HQ",
		Subtitle = "COMMANDER PROFILE · RECORDS",
		Kind = "Building",
		Facade = Vector3.new(88, 0, -20),
		Inward = Vector3.new(1, 0, 0),
		Width = 48,
		Depth = 44,
		Height = 20,
		Entrances = { { Offset = 0, Width = 10, Height = 11 } },
		Locator = true,
	},
	Garage = {
		Id = "Garage",
		DisplayName = "GARAGE",
		Subtitle = "UNIT COLLECTION · MOTOR POOL",
		Kind = "Building",
		Facade = Vector3.new(-88, 0, -2),
		Inward = Vector3.new(-1, 0, 0),
		Width = 84,
		Depth = 64,
		Height = 26,
		Entrances = {
			{ Offset = -26, Width = 20, Height = 18 },
			{ Offset = 0, Width = 20, Height = 18 },
			{ Offset = 26, Width = 20, Height = 18 },
		},
		Locator = true,
	},
	Leaderboards = {
		Id = "Leaderboards",
		DisplayName = "LEADERBOARDS",
		Subtitle = "HALL OF COMMANDERS",
		Kind = "Open",
		Facade = Vector3.new(110, 0, 68),
		Inward = Vector3.new(0, 0, 1),
		Width = 72,
		Depth = 40,
		Height = 18,
		Entrances = { { Offset = 0, Width = 72, Height = 18 } },
		Locator = true,
	},
	EventArea = {
		Id = "EventArea",
		DisplayName = "EVENTS",
		Subtitle = "CURRENT OPERATION",
		Kind = "Open",
		Facade = Vector3.new(-100, 0, 68),
		Inward = Vector3.new(0, 0, 1),
		Width = 76,
		Depth = 56,
		Height = 16,
		Entrances = { { Offset = 0, Width = 14, Height = 12 } },
		Locator = true,
	},
	MissionBoard = {
		Id = "MissionBoard",
		DisplayName = "MISSIONS",
		Subtitle = "CURRENT OPERATIONS BOARD",
		Kind = "Open",
		-- far enough behind the spawn that the default third-person camera
		-- (~12 studs behind the player) never ends up under the shelter roof
		Facade = Vector3.new(0, 0, 44.5),
		Inward = Vector3.new(0, 0, 1),
		Width = 22,
		Depth = 5,
		Height = 10,
		Entrances = { { Offset = 0, Width = 22, Height = 10 } },
		Locator = true,
	},
	SocialArea = {
		Id = "SocialArea",
		DisplayName = "CANTEEN",
		Subtitle = "SOCIAL AREA",
		Kind = "Open",
		Facade = Vector3.new(-6, 0, 67),
		Inward = Vector3.new(0, 0, 1),
		Width = 84,
		Depth = 72,
		Height = 16,
		Entrances = { { Offset = 0, Width = 84, Height = 16 } },
		Locator = true,
	},
} :: { [string]: Zone }

-- Order used by signposts and the HUD locator list.
Layout.ZoneOrder = {
	"OperationsCenter",
	"MapRoom",
	"CommandHQ",
	"Garage",
	"Leaderboards",
	"MissionBoard",
	"EventArea",
	"SocialArea",
}

-- CFrame at a zone's entrance side (see header comment for axis meaning).
function Layout.frame(zone: Zone): CFrame
	return CFrame.lookAt(zone.Facade, zone.Facade + zone.Inward)
end

-- World position just outside a zone's main entrance; used as the
-- navigation target for the HUD locator and the navigation tests.
function Layout.entrancePoint(zone: Zone, index: number?): Vector3
	local entrance = zone.Entrances[index or 1]
	local offset = if entrance then entrance.Offset else 0
	local frame = Layout.frame(zone)
	return (frame * CFrame.new(offset, 0, 4)).Position
end

-- Axis-aligned footprint of a zone in world space.
function Layout.footprint(zone: Zone): Rect
	local frame = Layout.frame(zone)
	local corners = {
		frame * Vector3.new(-zone.Width / 2, 0, 0),
		frame * Vector3.new(zone.Width / 2, 0, 0),
		frame * Vector3.new(-zone.Width / 2, 0, -zone.Depth),
		frame * Vector3.new(zone.Width / 2, 0, -zone.Depth),
	}
	local rect = { MinX = math.huge, MaxX = -math.huge, MinZ = math.huge, MaxZ = -math.huge }
	for _, corner in corners do
		rect.MinX = math.min(rect.MinX, corner.X)
		rect.MaxX = math.max(rect.MaxX, corner.X)
		rect.MinZ = math.min(rect.MinZ, corner.Z)
		rect.MaxZ = math.max(rect.MaxZ, corner.Z)
	end
	return rect
end

return Layout
