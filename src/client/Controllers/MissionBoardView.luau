--!strict
-- Personalises the physical mission board for the local player: the typed
-- "[ ]" boxes on the orders pinned to the cork board are ticked ("[X]")
-- for completed missions and struck through once collected. Local only;
-- other players see their own progress.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Missions = require(Lobby:WaitForChild("Config"):WaitForChild("Missions"))
local State = require(script.Parent.Parent.State)

local MissionBoardView = {}

local labels: { [string]: { TextLabel } } = {}

local function collect()
	table.clear(labels)
	local root = workspace:FindFirstChild("ColdWarLobby")
	if not root then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") and d.Name:sub(1, 8) == "Mission_" then
			local id = d.Name:sub(9)
			if Missions.List[id] then
				labels[id] = labels[id] or {}
				table.insert(labels[id], d)
			end
		end
	end
end

-- Text for one mission line given its state.
function MissionBoardView.lineFor(id: string, view: { [string]: any }?): string
	local mission = Missions.List[id]
	if not mission then
		return ""
	end
	if not view then
		return "[ ] " .. mission.Text
	end
	if view.claimed then
		return "[X] " .. mission.Text .. " — DONE"
	elseif view.complete then
		return "[X] " .. mission.Text
	elseif (view.progress or 0) > 0 and (view.target or 1) > 1 then
		return ("[ ] %s (%d/%d)"):format(mission.Text, view.progress, view.target)
	end
	return "[ ] " .. mission.Text
end

function MissionBoardView.apply()
	local data = State.missions
	if next(labels) == nil then
		collect()
	end
	local views: { [string]: { [string]: any } } = {}
	for _, view in (data and data.missions) or {} do
		views[view.id] = view
	end
	for id, list in labels do
		local text = MissionBoardView.lineFor(id, views[id])
		for _, label in list do
			if label.Parent and label.Text ~= text then
				label.Text = text
			end
		end
	end
end

function MissionBoardView.start()
	State.changed:Connect(function(key)
		if key == "missions" then
			MissionBoardView.apply()
		end
	end)
	-- the lobby may still be streaming in when the client starts
	task.spawn(function()
		for _ = 1, 30 do
			if workspace:FindFirstChild("ColdWarLobby") then
				break
			end
			task.wait(1)
		end
		collect()
		MissionBoardView.apply()
		-- with streaming enabled the board may stream in (or back in) later
		local root = workspace:FindFirstChild("ColdWarLobby")
		if root then
			root.DescendantAdded:Connect(function(d)
				if d:IsA("TextLabel") and d.Name:sub(1, 8) == "Mission_" then
					task.defer(function()
						collect()
						MissionBoardView.apply()
					end)
				end
			end)
		end
	end)
end

return MissionBoardView
