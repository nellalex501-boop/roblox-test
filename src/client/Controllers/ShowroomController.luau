--!strict
-- The vehicle on the Garage turntable, as this player sees it. Each player
-- picks the vehicle on show in the showroom viewer; the client puts its own
-- copy of the preview model (ReplicatedStorage.LobbyUnitPreviews) on the
-- deck, painted with the chosen scheme, and hides the server's featured
-- vehicle locally. The deck and the vehicle turn slowly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Units = require(Lobby:WaitForChild("Config"):WaitForChild("Units"))
local UnitPreview = require(script.Parent.Parent.UI.UnitPreview)

local ShowroomController = {}

ShowroomController.SpinSpeed = math.rad(5) -- degrees per second, both deck and vehicle
ShowroomController.DefaultUnit = "M1_ABRAMS"
-- the vehicle's nose starts toward the doors, slightly turned
ShowroomController.StartAngle = math.pi * 0.85

type Stage = { deck: BasePart, deckBase: CFrame, top: CFrame, featured: Model? }

local stage: Stage? = nil
local display: Model? = nil
local displayPivot = CFrame.identity -- the display model's pivot at the origin
local current = { unit = ShowroomController.DefaultUnit, camo = nil :: string? }
local angle = 0
local connection: RBXScriptConnection? = nil

-- Finds the turntable deck and the featured vehicle in the lobby.
local function findStage(): Stage?
	local root = workspace:FindFirstChild("ColdWarLobby")
	if not root then
		return nil
	end
	local deck: BasePart? = nil
	local featured: Model? = nil
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Showroom") == "Turntable" then
			deck = d
		elseif d:IsA("Model") and d:GetAttribute("ShowroomFeatured") then
			featured = d
		end
	end
	if not deck then
		return nil
	end
	local base = deck.CFrame
	-- the deck is an upright cylinder (axis along its local X); its top is
	-- half its length above the centre
	local top = CFrame.new(base.Position + Vector3.new(0, deck.Size.X / 2, 0))
	return { deck = deck, deckBase = base, top = top, featured = featured }
end

local function place()
	local s = stage
	local model = display
	if not s then
		return
	end
	local turn = CFrame.Angles(0, angle, 0)
	s.deck.CFrame = CFrame.new(s.deckBase.Position) * turn * (s.deckBase - s.deckBase.Position)
	if model then
		model:PivotTo(s.top * turn * CFrame.Angles(0, ShowroomController.StartAngle, 0) * displayPivot)
	end
end

-- Shows `unitId` on the turntable (painted with `camoId` when given).
-- Returns the local display model.
function ShowroomController.show(unitId: string, camoId: string?): Model?
	if not Units.List[unitId] then
		return nil
	end
	current.unit = unitId
	current.camo = camoId
	local s = stage
	if not s then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild(UnitPreview.FolderName)
	local source = folder and folder:FindFirstChild(unitId)
	if not source or not source:IsA("Model") then
		return nil
	end
	local old = display
	if old then
		old:Destroy()
	end
	local model = source:Clone()
	model.Name = "ShowroomVehicle"
	model:SetAttribute("UnitId", unitId)
	if camoId then
		UnitPreview.paint(model, camoId)
	end
	displayPivot = model:GetPivot()
	model.Parent = s.deck.Parent
	display = model
	place()
	return model
end

-- Repaints the vehicle on show (a live preview; nothing is saved).
function ShowroomController.paint(camoId: string)
	current.camo = camoId
	local model = display
	if model then
		UnitPreview.paint(model, camoId)
	end
end

function ShowroomController.current(): string
	return current.unit
end

function ShowroomController.model(): Model?
	return display
end

function ShowroomController.stage(): BasePart?
	local s = stage
	return if s then s.deck else nil
end

function ShowroomController.step(dt: number)
	angle = (angle + dt * ShowroomController.SpinSpeed) % (math.pi * 2)
	place()
end

function ShowroomController.start()
	task.spawn(function()
		-- the lobby may still be streaming in; look for the stage a while
		for _ = 1, 60 do
			stage = findStage()
			if stage then
				break
			end
			task.wait(0.5)
		end
		local s = stage
		if not s then
			return
		end
		local featured = s.featured
		if featured then
			-- hidden for this player only; their own pick takes its place
			featured.Parent = nil
		end
		ShowroomController.show(current.unit, current.camo)
		if connection then
			connection:Disconnect()
		end
		connection = RunService.Heartbeat:Connect(ShowroomController.step)
	end)
end

return ShowroomController
