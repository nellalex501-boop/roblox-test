--!strict
-- One registry for every physical interaction in the lobby.
--
-- The world builder marks an object as interactable with
-- Interactions.attach(part, kind, id, objectText). That creates a single
-- ProximityPrompt configured from the kind below and tags the part. The
-- client InteractionController routes a triggered prompt to the panel named
-- by its kind; the server uses the same kind for mission tracking.
-- Adding a new system = add a kind here + register a panel on the client.

export type KindDef = {
	ActionText: string,
	Panel: string,
	Tab: string?,
	MaxDistance: number?,
	HoldDuration: number?,
}

local Interactions = {}

Interactions.Tag = "LobbyInteractable"
Interactions.PromptName = "LobbyPrompt"

Interactions.Attributes = {
	Kind = "InteractionKind",
	Id = "InteractionId",
}

Interactions.Kinds = {
	Matchmaking = { ActionText = "JOIN MATCH", Panel = "Matchmaking", MaxDistance = 9 },
	MapInfo = { ActionText = "VIEW MAP", Panel = "Maps", MaxDistance = 11 },
	TheaterMap = { ActionText = "VIEW THEATRE MAP", Panel = "Maps", Tab = "THEATRE", MaxDistance = 14 },
	Profile = { ActionText = "USE TERMINAL", Panel = "Profile", Tab = "PROFILE" },
	Statistics = { ActionText = "VIEW RECORDS", Panel = "Profile", Tab = "STATISTICS" },
	Customize = { ActionText = "CUSTOMIZE", Panel = "Profile", Tab = "CUSTOMIZE" },
	Achievements = { ActionText = "VIEW ACHIEVEMENTS", Panel = "Profile", Tab = "ACHIEVEMENTS" },
	UnitInspect = { ActionText = "INSPECT VEHICLE", Panel = "Garage", Tab = "INSPECT", MaxDistance = 12 },
	UnitCollection = { ActionText = "OPEN UNIT REGISTRY", Panel = "Garage", Tab = "COLLECTION" },
	UnitCosmetics = { ActionText = "OPEN PAINT SHOP", Panel = "Garage", Tab = "PAINT" },
	Leaderboard = { ActionText = "VIEW LEADERBOARD", Panel = "Leaderboards", MaxDistance = 14 },
	Missions = { ActionText = "OPEN MISSIONS", Panel = "Missions", MaxDistance = 10 },
	Event = { ActionText = "VIEW OPERATION", Panel = "Event", MaxDistance = 10 },
} :: { [string]: KindDef }

Interactions.DefaultMaxDistance = 8

-- Creates the prompt on `part` and tags it. Safe to call in edit mode
-- (baking) and at runtime. Returns the prompt.
function Interactions.attach(part: BasePart, kind: string, id: string, objectText: string): ProximityPrompt
	local def = Interactions.Kinds[kind]
	assert(def, "Unknown interaction kind: " .. kind)

	local existing = part:FindFirstChild(Interactions.PromptName)
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Interactions.PromptName
	prompt.ActionText = def.ActionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = def.HoldDuration or 0
	prompt.MaxActivationDistance = def.MaxDistance or Interactions.DefaultMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part

	part:SetAttribute(Interactions.Attributes.Kind, kind)
	part:SetAttribute(Interactions.Attributes.Id, id)
	part:AddTag(Interactions.Tag)
	return prompt
end

-- Reads kind/id from a prompt's parent part.
function Interactions.describe(prompt: ProximityPrompt): (string?, string?)
	local parent = prompt.Parent
	if not parent then
		return nil, nil
	end
	local kind = parent:GetAttribute(Interactions.Attributes.Kind)
	local id = parent:GetAttribute(Interactions.Attributes.Id)
	if type(kind) ~= "string" then
		return nil, nil
	end
	return kind, if type(id) == "string" then id else ""
end

return Interactions
