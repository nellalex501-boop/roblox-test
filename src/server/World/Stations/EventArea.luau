--!strict
-- Event Area stations. Permanent: the briefing desk in the event HQ tent.
-- Event-driven (rebuilt by EventService when the operation changes): gate
-- banner text, the billboard, the limited-unit display and the dressing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent.Parent
local Common = require(script.Parent.Common)
local Garage = require(script.Parent.Garage)
local Kit = require(World.Kit)
local EventDressings = require(World.EventDressings)
local Interactions = require(ReplicatedStorage.Lobby.Interactions)
local Events = require(ReplicatedStorage.Lobby.Config.Events)
local Units = require(ReplicatedStorage.Lobby.Config.Units)
local Theme = require(ReplicatedStorage.Lobby.Config.Theme)
local Format = require(ReplicatedStorage.Lobby.Util.Format)

local W = Theme.World
local EventArea = {}

EventArea.DisplayPad = Vector3.new(16, 0.6, -22)

local function briefingDesk(parent: Instance, frame: CFrame)
	local model = Kit.model(parent, "BriefingDesk")
	local base = frame * CFrame.new(0, 0.5, -46)
	local desk = Kit.part(
		model,
		Vector3.new(8, 3, 3.4),
		base * CFrame.new(0, 1.5, 0),
		W.Olive,
		Enum.Material.Metal,
		{ Name = "FieldDesk" }
	)
	Kit.part(
		model,
		Vector3.new(8.4, 0.2, 3.8),
		base * CFrame.new(0, 3.1, 0),
		W.OliveDark,
		Enum.Material.Metal,
		{ Name = "DeskTop" }
	)
	-- field radio, typewriter and a lamp
	local radio = Kit.part(
		model,
		Vector3.new(2.2, 1.6, 1.4),
		base * CFrame.new(-2.6, 4, -0.6),
		Color3.fromRGB(70, 78, 60),
		Enum.Material.Metal,
		{
			Name = "FieldRadio",
		}
	)
	Kit.part(
		model,
		Vector3.new(0.1, 3, 0.1),
		base * CFrame.new(-3.4, 5.9, -0.9),
		W.Charcoal,
		nil,
		{ Name = "RadioAntenna", Decor = true }
	)
	Kit.anchor(radio, "Sound", "RadioChatter")
	-- typewriter at the front edge between the radio and the monitor:
	-- body, key bank, platen roller and a sheet of paper in it
	local typewriter = base * CFrame.new(-0.3, 3.2, 0.55)
	Kit.part(
		model,
		Vector3.new(1.9, 0.7, 1.3),
		typewriter * CFrame.new(0, 0.35, 0),
		W.Charcoal,
		Enum.Material.Metal,
		{ Name = "Typewriter", Decor = true }
	)
	Kit.part(
		model,
		Vector3.new(1.6, 0.08, 0.5),
		typewriter * CFrame.new(0, 0.74, 0.3),
		Color3.fromRGB(38, 38, 36),
		Enum.Material.SmoothPlastic,
		{ Name = "Keys", Decor = true }
	)
	Kit.cylinder(
		model,
		2.1,
		0.28,
		typewriter * CFrame.new(0, 0.84, -0.45),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.SmoothPlastic,
		{ Name = "Platen", Decor = true }
	)
	Kit.part(
		model,
		Vector3.new(1.2, 0.9, 0.02),
		typewriter * CFrame.new(0, 1.32, -0.5) * CFrame.Angles(math.rad(-12), 0, 0),
		W.Paper,
		Enum.Material.SmoothPlastic,
		{ Name = "Sheet", Decor = true }
	)
	-- the monitor at the right, well back from the front edge
	local screen = Common.crt(model, base * CFrame.new(2.4, 3.2, -0.8), 2.4, "Event")
	local _, content = Common.screen(screen, "EventScreen", 70)
	Common.line(content, "Header", "OPS CHANNEL", 0, 0.21, Common.Phosphor)
	Common.line(content, "Title", "BRIEFING", 0.32, 0.24, Common.Amber, nil, Enum.TextXAlignment.Center)
	Common.line(content, "Hint", "[E] READ", 0.74, 0.21, Common.Phosphor, nil, Enum.TextXAlignment.Center)
	Interactions.attach(desk, "Event", "CURRENT", "OPERATION BRIEFING")
	return model
end

-- Applies the active event to the area: texts, limited unit, dressing.
-- Safe to call repeatedly (clears the previous event's content first).
function EventArea.apply(zoneModel: Instance, frame: CFrame, event: Events.Event, now: number)
	local days = Events.daysRemaining(event, now)
	local banner = zoneModel:FindFirstChild("EventBanner", true)
	if banner then
		local title = banner:FindFirstChild("Title", true)
		if title and title:IsA("TextLabel") then
			title.Text = event.Codename
		end
	end
	local billboard = zoneModel:FindFirstChild("Billboard", true)
	if billboard and billboard:IsA("BasePart") then
		local old = billboard:FindFirstChild("EventBillboard")
		if old then
			old:Destroy()
		end
		local gui = Kit.surface(billboard, Enum.NormalId.Front, 24, 1)
		gui.Name = "EventBillboard"
		local bg = Kit.frame(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), W.Charcoal)
		local band = Kit.frame(bg, UDim2.fromScale(0, 0), UDim2.fromScale(0.035, 1), event.Palette.Primary)
		band.Name = "Band"
		Kit.text(bg, {
			Name = "Label",
			Text = event.Label,
			Color = event.Palette.Primary,
			Position = UDim2.fromScale(0.07, 0.07),
			Size = UDim2.fromScale(0.86, 0.13),
			Font = Theme.font("Body", Enum.FontWeight.Bold),
			XAlign = Enum.TextXAlignment.Left,
		})
		Kit.text(bg, {
			Name = "Title",
			Text = event.Title,
			Color = event.Palette.Text,
			Position = UDim2.fromScale(0.07, 0.2),
			Size = UDim2.fromScale(0.86, 0.36),
			Font = Theme.font("Header", Enum.FontWeight.Bold),
			XAlign = Enum.TextXAlignment.Left,
		})
		Kit.text(bg, {
			Name = "Tagline",
			Text = event.Tagline,
			Color = W.OffWhite,
			Position = UDim2.fromScale(0.07, 0.57),
			Size = UDim2.fromScale(0.86, 0.12),
			Font = Theme.font("Body"),
			XAlign = Enum.TextXAlignment.Left,
		})
		local available = if event.EndsAt > 0 then "AVAILABLE: " .. Format.days(days) else "STAND BY FOR ORDERS"
		Kit.text(bg, {
			Name = "Days",
			Text = available,
			Color = Theme.UI.Accent,
			Position = UDim2.fromScale(0.07, 0.75),
			Size = UDim2.fromScale(0.86, 0.16),
			Font = Theme.font("Mono", Enum.FontWeight.Bold),
			XAlign = Enum.TextXAlignment.Left,
		})
	end
	-- event content (limited units + dressing) lives in the Dressing model
	local dressing = zoneModel:FindFirstChild("Dressing")
	if dressing then
		dressing:ClearAllChildren()
		for i, unitId in event.LimitedUnits do
			if Units.List[unitId] then
				local pad = EventArea.DisplayPad
				local vehicleFrame = frame
					* CFrame.new(pad.X, pad.Y, pad.Z + (i - 1) * 14)
					* CFrame.Angles(0, math.rad(200), 0)
				local camoId = Units.List[unitId].Camo or (if event.Dressing == "Winter" then "WINTER" else "FACTORY")
				local camo = Units.Camos.List[camoId] or Units.Camos.List.FACTORY
				Garage.display(dressing, unitId, vehicleFrame, { Base = camo.Colors[1], Accent = camo.Colors[2] })
			end
		end
		local dress = EventDressings[event.Dressing]
		if dress and dressing:IsA("Model") then
			dress(dressing, frame)
		end
	end
	zoneModel:SetAttribute("EventId", event.Id)
end

function EventArea.build(zoneModel: Instance, frame: CFrame, now: number)
	local folder = Kit.folder(zoneModel, "Stations")
	briefingDesk(folder, frame)
	EventArea.apply(zoneModel, frame, Events.current(now), now)
end

return EventArea
