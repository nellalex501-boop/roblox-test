--!strict
-- Battle map catalogue. The same data drives the Map Room wall displays,
-- the table miniature, the central theatre map markers and the map UI.
--
-- Preview coordinates are normalised 0..1 (0,0 = north-west corner).

export type Point = { number }
export type Polyline = { Point }
export type Box = { number } -- { x, y, w, h }

export type Preview = {
	Roads: { Polyline },
	Highways: { Polyline }?,
	Rail: { Polyline }?,
	Rivers: { Polyline }?,
	RiverWidth: number?,
	Water: { Box }?,
	Forests: { Box },
	Urban: { Box },
	Landmark: { x: number, y: number, label: string },
	Sectors: { Point },
	Spawns: { NATO: Point, PACT: Point },
}

export type MapInfo = {
	Id: string,
	Name: string,
	Tagline: string,
	Size: string,
	Dimensions: string,
	Terrain: string,
	Players: string,
	Recommended: { string },
	Landmark: string,
	Description: string,
	TheaterPos: Point,
	Preview: Preview,
}

local Maps = {}

Maps.Order = {
	"TRAIN_STATION",
	"CATHEDRAL",
	"RIVER_CROSSING",
	"INDUSTRIAL_HEART",
	"AIRBASE",
	"DAM",
	"HIGHWAY",
}

-- Map shown as a 3D miniature on the Map Room planning table.
Maps.Featured = "RIVER_CROSSING"

Maps.List = {
	TRAIN_STATION = {
		Id = "TRAIN_STATION",
		Name = "TRAIN STATION",
		Tagline = "RAIL HUB OF A BORDER TOWN",
		Size = "SMALL",
		Dimensions = "1.6 × 1.6 KM",
		Terrain = "URBAN · RAIL YARD",
		Players = "2–4",
		Recommended = { "1V1", "2V2" },
		Landmark = "HAUPTBAHNHOF",
		Description = "Tight streets around a marshalling yard. Whoever holds the station controls every road through town.",
		TheaterPos = { 0.36, 0.30 },
		Preview = {
			Roads = {
				{ { 0.5, 0 }, { 0.5, 1 } },
				{ { 0, 0.22 }, { 1, 0.18 } },
				{ { 0, 0.8 }, { 1, 0.78 } },
				{ { 0.26, 0 }, { 0.3, 1 } },
				{ { 0.74, 0 }, { 0.72, 1 } },
			},
			Rail = {
				{ { 0, 0.44 }, { 1, 0.44 } },
				{ { 0, 0.5 }, { 1, 0.52 } },
				{ { 0.18, 0.5 }, { 0.36, 0.56 }, { 0.8, 0.56 } },
			},
			Forests = { { 0, 0, 0.18, 0.34 }, { 0.84, 0.6, 0.16, 0.4 }, { 0.02, 0.86, 0.2, 0.14 } },
			Urban = {
				{ 0.32, 0.06, 0.14, 0.3 },
				{ 0.54, 0.04, 0.16, 0.32 },
				{ 0.32, 0.6, 0.16, 0.16 },
				{ 0.54, 0.6, 0.16, 0.16 },
				{ 0.76, 0.24, 0.1, 0.14 },
			},
			Landmark = { x = 0.5, y = 0.4, label = "HAUPTBAHNHOF" },
			Sectors = { { 0.14, 0.5 }, { 0.4, 0.22 }, { 0.5, 0.47 }, { 0.62, 0.7 }, { 0.86, 0.44 } },
			Spawns = { NATO = { 0.06, 0.92 }, PACT = { 0.94, 0.08 } },
		},
	},
	CATHEDRAL = {
		Id = "CATHEDRAL",
		Name = "CATHEDRAL",
		Tagline = "OLD TOWN BENEATH A GOTHIC SPIRE",
		Size = "MEDIUM",
		Dimensions = "2.0 × 2.0 KM",
		Terrain = "URBAN · OLD TOWN",
		Players = "2–4",
		Recommended = { "2V2", "1V1" },
		Landmark = "CATHEDRAL SPIRE",
		Description = "A walled old town around the cathedral square. The spire overlooks every approach.",
		TheaterPos = { 0.44, 0.54 },
		Preview = {
			Roads = {
				{ { 0.24, 0.24 }, { 0.76, 0.24 }, { 0.76, 0.76 }, { 0.24, 0.76 }, { 0.24, 0.24 } },
				{ { 0.5, 0 }, { 0.5, 1 } },
				{ { 0, 0.5 }, { 1, 0.5 } },
				{ { 0.1, 0.1 }, { 0.24, 0.24 } },
				{ { 0.76, 0.76 }, { 0.92, 0.94 } },
			},
			Rivers = { { { 0, 0.9 }, { 0.36, 0.86 }, { 0.7, 0.92 }, { 1, 0.88 } } },
			RiverWidth = 0.035,
			Forests = { { 0, 0, 0.16, 0.2 }, { 0.82, 0.02, 0.18, 0.2 }, { 0.84, 0.56, 0.16, 0.2 } },
			Urban = {
				{ 0.28, 0.28, 0.18, 0.18 },
				{ 0.54, 0.28, 0.18, 0.18 },
				{ 0.28, 0.54, 0.18, 0.18 },
				{ 0.54, 0.54, 0.18, 0.18 },
				{ 0.06, 0.56, 0.12, 0.16 },
				{ 0.58, 0.04, 0.14, 0.14 },
			},
			Landmark = { x = 0.5, y = 0.5, label = "CATHEDRAL" },
			Sectors = { { 0.5, 0.5 }, { 0.24, 0.24 }, { 0.76, 0.24 }, { 0.24, 0.76 }, { 0.76, 0.76 }, { 0.5, 0.08 } },
			Spawns = { NATO = { 0.06, 0.94 }, PACT = { 0.94, 0.06 } },
		},
	},
	RIVER_CROSSING = {
		Id = "RIVER_CROSSING",
		Name = "RIVER CROSSING",
		Tagline = "CONTESTED BRIDGES OVER THE FULDA",
		Size = "MEDIUM",
		Dimensions = "2.4 × 2.4 KM",
		Terrain = "RIVER · FARMLAND",
		Players = "4–8",
		Recommended = { "2V2", "4V4" },
		Landmark = "TWIN BRIDGES",
		Description = "Two bridges, one ford and open farmland. Engineers and artillery decide who crosses first.",
		TheaterPos = { 0.54, 0.42 },
		Preview = {
			Roads = {
				{ { 0, 0.34 }, { 0.44, 0.36 }, { 1, 0.4 } },
				{ { 0, 0.7 }, { 0.5, 0.7 }, { 1, 0.66 } },
				{ { 0.2, 0 }, { 0.24, 1 } },
				{ { 0.8, 0 }, { 0.76, 1 } },
			},
			Rivers = { { { 0.44, 0 }, { 0.5, 0.28 }, { 0.42, 0.52 }, { 0.56, 0.8 }, { 0.5, 1 } } },
			RiverWidth = 0.05,
			Forests = {
				{ 0.02, 0.04, 0.16, 0.2 },
				{ 0.62, 0.46, 0.14, 0.14 },
				{ 0.06, 0.8, 0.14, 0.16 },
				{ 0.84, 0.82, 0.16, 0.18 },
			},
			Urban = { { 0.26, 0.28, 0.1, 0.1 }, { 0.6, 0.6, 0.12, 0.1 }, { 0.84, 0.12, 0.1, 0.1 } },
			Landmark = { x = 0.47, y = 0.36, label = "NORTH BRIDGE" },
			Sectors = { { 0.47, 0.36 }, { 0.52, 0.7 }, { 0.3, 0.33 }, { 0.66, 0.64 }, { 0.22, 0.86 }, { 0.8, 0.14 } },
			Spawns = { NATO = { 0.05, 0.5 }, PACT = { 0.95, 0.5 } },
		},
	},
	INDUSTRIAL_HEART = {
		Id = "INDUSTRIAL_HEART",
		Name = "INDUSTRIAL HEART",
		Tagline = "STEELWORKS AND CHEMICAL PLANTS",
		Size = "LARGE",
		Dimensions = "3.2 × 3.2 KM",
		Terrain = "INDUSTRIAL",
		Players = "8",
		Recommended = { "4V4" },
		Landmark = "BLAST FURNACES",
		Description = "A sprawling steelworks with rail spurs, slag heaps and a canal. Close-quarters armour hell.",
		TheaterPos = { 0.28, 0.66 },
		Preview = {
			Roads = {
				{ { 0, 0.3 }, { 1, 0.3 } },
				{ { 0, 0.66 }, { 1, 0.66 } },
				{ { 0.3, 0 }, { 0.3, 1 } },
				{ { 0.68, 0 }, { 0.68, 1 } },
			},
			Rail = { { { 0, 0.48 }, { 0.3, 0.48 }, { 0.5, 0.4 }, { 1, 0.4 } }, { { 0.5, 0.4 }, { 0.5, 0.9 } } },
			Water = { { 0.84, 0, 0.06, 1 } },
			Forests = { { 0, 0, 0.14, 0.14 }, { 0, 0.84, 0.18, 0.16 } },
			Urban = {
				{ 0.34, 0.08, 0.3, 0.18 },
				{ 0.08, 0.34, 0.18, 0.1 },
				{ 0.36, 0.44, 0.1, 0.18 },
				{ 0.54, 0.46, 0.12, 0.16 },
				{ 0.34, 0.7, 0.3, 0.22 },
				{ 0.72, 0.34, 0.1, 0.28 },
			},
			Landmark = { x = 0.5, y = 0.17, label = "BLAST FURNACES" },
			Sectors = {
				{ 0.5, 0.17 },
				{ 0.16, 0.39 },
				{ 0.41, 0.53 },
				{ 0.6, 0.54 },
				{ 0.49, 0.8 },
				{ 0.77, 0.48 },
				{ 0.16, 0.8 },
			},
			Spawns = { NATO = { 0.06, 0.6 }, PACT = { 0.94, 0.2 } },
		},
	},
	AIRBASE = {
		Id = "AIRBASE",
		Name = "AIRBASE",
		Tagline = "FORWARD NATO AIRFIELD",
		Size = "LARGE",
		Dimensions = "3.6 × 3.6 KM",
		Terrain = "AIRFIELD · OPEN PLAINS",
		Players = "6–8",
		Recommended = { "4V4", "2V2" },
		Landmark = "CONTROL TOWER",
		Description = "Long sightlines across the runway, hardened aircraft shelters and a fuel farm worth fighting for.",
		TheaterPos = { 0.18, 0.40 },
		Preview = {
			Roads = {
				{ { 0.3, 0.64 }, { 0.3, 0.8 }, { 0.62, 0.8 } },
				{ { 0.7, 0.22 }, { 0.7, 0.4 } },
				{ { 0, 0.9 }, { 1, 0.9 } },
			},
			Highways = { { { 0.14, 0.72 }, { 0.86, 0.3 } } },
			Forests = { { 0, 0, 0.3, 0.18 }, { 0.8, 0.6, 0.2, 0.26 }, { 0, 0.34, 0.12, 0.2 } },
			Urban = {
				{ 0.24, 0.8, 0.06, 0.05 },
				{ 0.34, 0.82, 0.06, 0.05 },
				{ 0.44, 0.82, 0.06, 0.05 },
				{ 0.64, 0.16, 0.12, 0.08 },
				{ 0.52, 0.6, 0.08, 0.1 },
			},
			Landmark = { x = 0.56, y = 0.64, label = "CONTROL TOWER" },
			Sectors = { { 0.5, 0.51 }, { 0.2, 0.68 }, { 0.8, 0.33 }, { 0.37, 0.84 }, { 0.7, 0.2 }, { 0.56, 0.64 } },
			Spawns = { NATO = { 0.06, 0.94 }, PACT = { 0.94, 0.06 } },
		},
	},
	DAM = {
		Id = "DAM",
		Name = "DAM",
		Tagline = "HYDROELECTRIC DAM IN A FORESTED VALLEY",
		Size = "MEDIUM",
		Dimensions = "2.2 × 2.2 KM",
		Terrain = "VALLEY · FOREST",
		Players = "2–4",
		Recommended = { "1V1", "2V2" },
		Landmark = "DAM WALL",
		Description = "A single road across the dam wall links two forested ridges. Losing the dam splits your front.",
		TheaterPos = { 0.62, 0.72 },
		Preview = {
			Roads = {
				{ { 0, 0.38 }, { 1, 0.38 } },
				{ { 0.3, 0.38 }, { 0.22, 0.6 }, { 0.34, 0.8 }, { 0.26, 1 } },
				{ { 0.7, 0.38 }, { 0.8, 0.62 }, { 0.7, 0.84 }, { 0.78, 1 } },
			},
			Water = { { 0, 0, 1, 0.34 } },
			Rivers = { { { 0.5, 0.38 }, { 0.46, 0.6 }, { 0.54, 0.8 }, { 0.5, 1 } } },
			RiverWidth = 0.035,
			Forests = {
				{ 0.02, 0.44, 0.18, 0.5 },
				{ 0.36, 0.5, 0.06, 0.4 },
				{ 0.58, 0.46, 0.08, 0.4 },
				{ 0.84, 0.44, 0.16, 0.54 },
			},
			Urban = { { 0.44, 0.34, 0.12, 0.06 }, { 0.12, 0.26, 0.08, 0.06 } },
			Landmark = { x = 0.5, y = 0.36, label = "DAM WALL" },
			Sectors = { { 0.5, 0.37 }, { 0.16, 0.38 }, { 0.84, 0.38 }, { 0.3, 0.8 }, { 0.72, 0.84 } },
			Spawns = { NATO = { 0.1, 0.94 }, PACT = { 0.9, 0.94 } },
		},
	},
	HIGHWAY = {
		Id = "HIGHWAY",
		Name = "HIGHWAY",
		Tagline = "AUTOBAHN INTERCHANGE ACROSS ROLLING HILLS",
		Size = "LARGE",
		Dimensions = "3.0 × 3.0 KM",
		Terrain = "OPEN · HILLS",
		Players = "4–8",
		Recommended = { "2V2", "4V4" },
		Landmark = "AUTOBAHN INTERCHANGE",
		Description = "Fast roads and rolling hills. Control the interchange to shift forces along the whole front.",
		TheaterPos = { 0.46, 0.18 },
		Preview = {
			Roads = {
				{ { 0.5, 0 }, { 0.5, 1 } },
				{ { 0.5, 0.42 }, { 0.6, 0.36 }, { 0.62, 0.46 }, { 0.5, 0.5 } },
				{ { 0.5, 0.5 }, { 0.38, 0.56 }, { 0.36, 0.46 }, { 0.5, 0.42 } },
				{ { 0.1, 0.9 }, { 0.3, 0.8 }, { 0.5, 0.82 } },
			},
			Highways = { { { 0, 0.52 }, { 1, 0.42 } } },
			Forests = {
				{ 0.04, 0.06, 0.2, 0.2 },
				{ 0.7, 0.62, 0.2, 0.18 },
				{ 0.3, 0.08, 0.1, 0.12 },
				{ 0.78, 0.04, 0.16, 0.18 },
			},
			Urban = { { 0.62, 0.52, 0.08, 0.06 }, { 0.14, 0.62, 0.12, 0.1 } },
			Landmark = { x = 0.5, y = 0.46, label = "INTERCHANGE" },
			Sectors = { { 0.5, 0.46 }, { 0.14, 0.5 }, { 0.86, 0.44 }, { 0.5, 0.12 }, { 0.5, 0.86 }, { 0.2, 0.66 } },
			Spawns = { NATO = { 0.04, 0.8 }, PACT = { 0.96, 0.2 } },
		},
	},
} :: { [string]: MapInfo }

-- Regional theatre map shown on the central plaza table.
-- Coordinates are normalised to the table (0,0 = north-west).
Maps.Theater = {
	Title = "THEATRE OF OPERATIONS — FULDA SECTOR",
	Border = { { 0.66, 0 }, { 0.62, 0.2 }, { 0.7, 0.42 }, { 0.64, 0.64 }, { 0.72, 0.86 }, { 0.68, 1 } },
	Rivers = {
		{ { 0.3, 1 }, { 0.36, 0.72 }, { 0.5, 0.48 }, { 0.52, 0.26 }, { 0.6, 0 } },
		{ { 0.78, 1 }, { 0.84, 0.6 }, { 0.8, 0.3 }, { 0.9, 0 } },
	},
	Highways = {
		{ { 0, 0.62 }, { 0.3, 0.5 }, { 0.5, 0.36 }, { 0.62, 0.3 }, { 1, 0.22 } },
		{ { 0.4, 1 }, { 0.44, 0.56 }, { 0.48, 0.2 }, { 0.46, 0 } },
	},
	Forests = {
		{ 0.04, 0.08, 0.18, 0.18 },
		{ 0.06, 0.74, 0.16, 0.18 },
		{ 0.56, 0.62, 0.1, 0.22 },
		{ 0.74, 0.08, 0.14, 0.14 },
		{ 0.84, 0.66, 0.14, 0.2 },
	},
	Towns = {
		{ x = 0.47, y = 0.46, label = "FULDA" },
		{ x = 0.52, y = 0.12, label = "BAD HERSFELD" },
		{ x = 0.58, y = 0.3, label = "HÜNFELD" },
		{ x = 0.86, y = 0.18, label = "EISENACH" },
		{ x = 0.2, y = 0.56, label = "LAUTERBACH" },
	},
	-- Blue = NATO lines, red = Warsaw Pact axes of advance.
	FrontNato = { { 0.58, 0.04 }, { 0.56, 0.3 }, { 0.6, 0.52 }, { 0.56, 0.8 }, { 0.6, 0.98 } },
	AxesPact = {
		{ { 0.92, 0.3 }, { 0.74, 0.34 }, { 0.62, 0.4 } },
		{ { 0.94, 0.72 }, { 0.78, 0.66 }, { 0.66, 0.7 } },
	},
}

function Maps.get(id: string): MapInfo?
	return Maps.List[id]
end

return Maps
