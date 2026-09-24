--!strict
-- Place preparation before the services start.
--
-- * The default Studio template puts a Baseplate (top at y = 0) and a
--   SpawnLocation at the origin. Both collide with the lobby (z-fighting
--   with the grass, a spawn inside the plaza dais), so they are moved -
--   not deleted - into ServerStorage.LobbyDisplacedTemplate.
-- * A lobby baked in edit mode (Builder.Build() from the command bar) is
--   reused when its LobbyVersion matches; otherwise the lobby is rebuilt.
-- * Characters that loaded before the lobby existed are moved to a spawn.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Builder = require(script.Parent.Parent.World.Builder)
local LightingSetup = require(script.Parent.Parent.World.LightingSetup)

local Setup = {}

Setup.DisplacedFolderName = "LobbyDisplacedTemplate"

local function isTemplatePiece(child: Instance): boolean
	if child:IsA("SpawnLocation") then
		return true
	end
	return child:IsA("BasePart") and child.Name == "Baseplate"
end

-- Returns the names of the template pieces that were moved.
function Setup.prepareWorkspace(): { string }
	local moved = {}
	local holder: Instance? = nil
	for _, child in workspace:GetChildren() do
		if child.Name ~= Builder.RootName and isTemplatePiece(child) then
			if not holder then
				holder = ServerStorage:FindFirstChild(Setup.DisplacedFolderName)
				if not holder then
					local folder = Instance.new("Folder")
					folder.Name = Setup.DisplacedFolderName
					folder.Parent = ServerStorage
					holder = folder
				end
			end
			child.Parent = holder
			table.insert(moved, child.Name)
		end
	end
	if #moved > 0 then
		local where = "ServerStorage." .. Setup.DisplacedFolderName
		print(("[Lobby] Moved template %s to %s"):format(table.concat(moved, ", "), where))
	end
	return moved
end

-- Returns the lobby model and whether a baked copy was reused.
function Setup.ensureWorld(): (Model, boolean)
	local existing = workspace:FindFirstChild(Builder.RootName)
	if
		existing
		and existing:IsA("Model")
		and existing:GetAttribute("LobbyVersion") == Builder.Version
		and existing:GetAttribute("BuildMode") == "Full"
	then
		LightingSetup.apply()
		return existing, true
	end
	if existing then
		warn(
			("[Lobby] Baked lobby is version %s (current %d) - rebuilding"):format(
				tostring(existing:GetAttribute("LobbyVersion")),
				Builder.Version
			)
		)
	end
	return Builder.Build(), false
end

local function spawnPads(world: Instance): { SpawnLocation }
	local pads: { SpawnLocation } = {}
	for _, d in world:GetDescendants() do
		if d:IsA("SpawnLocation") then
			table.insert(pads, d)
		end
	end
	return pads
end

-- Called once right after the lobby is ready: any character that exists
-- already spawned before it (on the template spawn or in the void), so it
-- is moved onto a lobby spawn pad.
function Setup.relocateCharacters(world: Instance): number
	local pads = spawnPads(world)
	if #pads == 0 then
		return 0
	end
	local moved = 0
	for index, player in Players:GetPlayers() do
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local pad = pads[(index - 1) % #pads + 1]
			character:PivotTo(pad.CFrame * CFrame.new(0, 3.5, 0))
			moved += 1
		end
	end
	return moved
end

return Setup
