--!strict
-- Server side of the interaction system.
--
-- Every ProximityPrompt trigger arrives here through
-- ProximityPromptService (server-authoritative: the engine checks range),
-- is recorded on the commander profile (drives orientation missions and
-- event challenges) and re-broadcast to listeners. Also answers
-- "is this player standing at a station of kind X" for actions that must
-- happen physically (e.g. joining a matchmaking queue).

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Trackers = require(script.Parent.Parent.Core.Trackers)
local CommanderService = require(script.Parent.CommanderService)

local InteractionService = {}

InteractionService.Cooldown = 0.75
InteractionService.RangeSlack = 6

local lastTrigger: { [Player]: { [ProximityPrompt]: number } } = {}
local listeners: { (Player, string, string, ProximityPrompt) -> () } = {}

function InteractionService.onInteraction(handler: (Player, string, string, ProximityPrompt) -> ())
	table.insert(listeners, handler)
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame.Position
	end
	return nil
end

-- True if the player stands within prompt range (+slack) of a station of
-- `kind` (optionally with a specific id).
function InteractionService.isNear(player: Player, kind: string, id: string?, extraRange: number?): boolean
	local position = rootPosition(player)
	if not position then
		return false
	end
	for _, part in CollectionService:GetTagged(Interactions.Tag) do
		if part:IsA("BasePart") and part:GetAttribute(Interactions.Attributes.Kind) == kind then
			if id == nil or part:GetAttribute(Interactions.Attributes.Id) == id then
				local prompt = part:FindFirstChild(Interactions.PromptName)
				local range = if prompt and prompt:IsA("ProximityPrompt") then prompt.MaxActivationDistance else 10
				if
					(part.CFrame.Position - position).Magnitude
					<= range + (extraRange or InteractionService.RangeSlack)
				then
					return true
				end
			end
		end
	end
	return false
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	if prompt.Name ~= Interactions.PromptName then
		return
	end
	local kind, id = Interactions.describe(prompt)
	if not kind then
		return
	end
	local now = os.clock()
	local perPlayer = lastTrigger[player]
	if not perPlayer then
		perPlayer = {}
		lastTrigger[player] = perPlayer
	end
	if perPlayer[prompt] and now - perPlayer[prompt] < InteractionService.Cooldown then
		return
	end
	perPlayer[prompt] = now
	InteractionService.record(player, kind, id or "", prompt)
end

-- Records an interaction on the profile (missions, event challenges) and
-- tells the listeners. Prompts call it; so do server-validated actions
-- that stand for a physical interaction (viewing a vehicle in the Garage
-- showroom counts as inspecting it).
function InteractionService.record(player: Player, kind: string, id: string, prompt: ProximityPrompt?)
	CommanderService.update(player, function(profile)
		Trackers.recordInteraction(profile, kind, id)
		return true
	end)
	for _, handler in listeners do
		task.spawn(handler, player, kind, id, prompt :: any)
	end
end

function InteractionService.start()
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastTrigger[player] = nil
	end)
end

return InteractionService
