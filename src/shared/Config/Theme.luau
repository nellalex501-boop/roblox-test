--!strict
-- Shared visual language for the lobby world and every lobby interface.
-- World colours are muted late-Cold-War tones; UI tokens mirror a dark
-- command-terminal look so lobby panels match the in-game RTS HUD.

local Theme = {}

Theme.World = {
	Olive = Color3.fromRGB(86, 94, 58),
	OliveDark = Color3.fromRGB(64, 72, 46),
	OliveLight = Color3.fromRGB(112, 120, 80),
	DarkGreen = Color3.fromRGB(46, 58, 42),
	ConcreteLight = Color3.fromRGB(172, 168, 156),
	Concrete = Color3.fromRGB(148, 145, 136),
	ConcreteDark = Color3.fromRGB(114, 112, 106),
	DarkGrey = Color3.fromRGB(64, 66, 66),
	Charcoal = Color3.fromRGB(40, 42, 42),
	Asphalt = Color3.fromRGB(56, 57, 58),
	AsphaltLight = Color3.fromRGB(74, 75, 76),
	Brown = Color3.fromRGB(104, 78, 56),
	BrownDark = Color3.fromRGB(72, 55, 41),
	Wood = Color3.fromRGB(128, 96, 66),
	Beige = Color3.fromRGB(196, 184, 150),
	BeigeDark = Color3.fromRGB(164, 150, 116),
	MutedRed = Color3.fromRGB(138, 60, 50),
	MutedBlue = Color3.fromRGB(64, 88, 114),
	Brick = Color3.fromRGB(126, 72, 58),
	BrickDark = Color3.fromRGB(98, 56, 46),
	Roof = Color3.fromRGB(70, 66, 64),
	Grass = Color3.fromRGB(90, 104, 60),
	GrassDark = Color3.fromRGB(70, 84, 48),
	Foliage = Color3.fromRGB(62, 80, 46),
	FoliageDark = Color3.fromRGB(44, 60, 38),
	Dirt = Color3.fromRGB(110, 94, 70),
	-- a lighter blue-grey reads as glass (and daylight from inside) instead
	-- of a hole in the wall
	Glass = Color3.fromRGB(84, 100, 110),
	GlassLit = Color3.fromRGB(150, 138, 104),
	OffWhite = Color3.fromRGB(226, 222, 206),
	Paper = Color3.fromRGB(224, 216, 190),
	Cork = Color3.fromRGB(150, 112, 74),
	HazardYellow = Color3.fromRGB(188, 156, 66),
	Steel = Color3.fromRGB(112, 114, 112),
	SteelDark = Color3.fromRGB(78, 80, 80),
	SignGreen = Color3.fromRGB(38, 58, 44),
	Snow = Color3.fromRGB(228, 232, 234),
	Lamp = Color3.fromRGB(255, 220, 170),
	LampRed = Color3.fromRGB(190, 60, 50),
	CrtGreen = Color3.fromRGB(150, 200, 130),
	CrtAmber = Color3.fromRGB(230, 172, 84),
	Screen = Color3.fromRGB(18, 24, 20),
	Rubber = Color3.fromRGB(34, 34, 34),
}

Theme.UI = {
	Backdrop = Color3.fromRGB(6, 8, 7),
	Background = Color3.fromRGB(14, 17, 15),
	Panel = Color3.fromRGB(21, 26, 22),
	PanelRaised = Color3.fromRGB(30, 36, 31),
	PanelHover = Color3.fromRGB(40, 47, 40),
	Border = Color3.fromRGB(96, 102, 82),
	BorderDim = Color3.fromRGB(56, 62, 52),
	Text = Color3.fromRGB(218, 214, 194),
	TextDim = Color3.fromRGB(142, 140, 120),
	TextFaint = Color3.fromRGB(96, 98, 84),
	Accent = Color3.fromRGB(214, 164, 78),
	AccentDim = Color3.fromRGB(128, 100, 52),
	Phosphor = Color3.fromRGB(158, 198, 132),
	Danger = Color3.fromRGB(178, 78, 64),
	Success = Color3.fromRGB(122, 162, 98),
	Nato = Color3.fromRGB(88, 120, 152),
	Pact = Color3.fromRGB(164, 74, 62),
}

-- Accent colours used to colour-code the physical matchmaking stations.
Theme.ModeColors = {
	QUICK = Color3.fromRGB(190, 150, 70),
	DUEL = Color3.fromRGB(88, 120, 152),
	TEAM = Color3.fromRGB(112, 132, 84),
	LARGE = Color3.fromRGB(160, 76, 62),
	PRIVATE = Color3.fromRGB(124, 118, 102),
}

local FAMILY = {
	Header = Enum.Font.Oswald,
	Body = Enum.Font.RobotoCondensed,
	Mono = Enum.Font.RobotoMono,
	Document = Enum.Font.SpecialElite,
	Marker = Enum.Font.PermanentMarker,
}

export type FontRole = "Header" | "Body" | "Mono" | "Document" | "Marker"

-- FontFace helper. FontFace (not the legacy Font enum property) is used
-- everywhere so the same code works in Studio and in headless builds.
function Theme.font(role: FontRole, weight: Enum.FontWeight?): Font
	local family = Font.fromEnum(FAMILY[role]).Family
	return Font.new(family, weight or Enum.FontWeight.Regular)
end

return Theme
