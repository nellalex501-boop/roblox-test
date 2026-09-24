--!strict
-- Vehicle previews in ViewportFrames (unit registry, paint shop) using the
-- models the server publishes in ReplicatedStorage.LobbyUnitPreviews, and
-- repainting of models whose parts carry the "Paint" attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Units = require(Lobby:WaitForChild("Config"):WaitForChild("Units"))
local Kit = require(script.Parent.Kit)

local UnitPreview = {}

UnitPreview.FolderName = "LobbyUnitPreviews"

local spinning: { [ViewportFrame]: { model: Model, pivot: CFrame, angle: number } } = {}
local spinConnection: RBXScriptConnection? = nil

function UnitPreview.paint(model: Instance, camoId: string)
	local camo = Units.Camos.List[camoId]
	if not camo then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local slot = d:GetAttribute("Paint")
			if slot == "Base" then
				d.Color = camo.Colors[1]
			elseif slot == "Accent" then
				d.Color = camo.Colors[2]
			end
		end
	end
end

local function ensureSpin()
	if spinConnection then
		return
	end
	spinConnection = RunService.RenderStepped:Connect(function(dt: number)
		for viewport, spin in spinning do
			if not viewport.Parent then
				spinning[viewport] = nil
			elseif viewport.Visible then
				spin.angle += dt * 0.35
				spin.model:PivotTo(spin.pivot * CFrame.Angles(0, spin.angle, 0))
			end
		end
	end)
end

-- Fills `parent` with a ViewportFrame showing the unit. Returns the frame
-- (or a text placeholder when no preview model exists).
function UnitPreview.mount(parent: Instance, unitId: string, camoId: string?): GuiObject
	local folder = ReplicatedStorage:FindFirstChild(UnitPreview.FolderName)
	local source = folder and folder:FindFirstChild(unitId)
	if not source or not source:IsA("Model") then
		return Kit.text(parent, {
			Name = "NoPreview",
			Text = "NO IMAGERY ON FILE",
			FontFace = Kit.Fonts.Mono,
			TextSize = Kit.Text.Small,
			TextColor3 = Kit.Colors.TextFaint,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
	end
	local viewport: ViewportFrame = Kit.new("ViewportFrame", {
		Name = "Viewport",
		BackgroundColor3 = Kit.Colors.Backdrop,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(150, 150, 140),
		LightColor = Color3.fromRGB(255, 244, 222),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
		Parent = parent,
	})
	local model = source:Clone()
	if camoId then
		UnitPreview.paint(model, camoId)
	end
	local world = Kit.new("WorldModel", { Parent = viewport })
	model.Parent = world
	local boxCf, size = model:GetBoundingBox()
	local pivot = CFrame.new(boxCf.Position)
	-- wrap in a holder pivoting at the model centre so it spins in place
	local holder = Instance.new("Model")
	holder.Name = "Spin"
	holder.Parent = world
	model.Parent = holder
	holder.WorldPivot = pivot
	local camera = Kit.new("Camera", { FieldOfView = 30, Parent = viewport })
	local radius = size.Magnitude * 0.5
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local eye = pivot.Position + Vector3.new(0.7, 0.45, 0.8).Unit * distance
	camera.CFrame = CFrame.lookAt(eye, pivot.Position)
	viewport.CurrentCamera = camera
	spinning[viewport] = { model = holder, pivot = pivot * CFrame.Angles(0, math.rad(-35), 0), angle = 0 }
	ensureSpin()
	return viewport
end

-- Repaints the model shown in a mounted viewport.
function UnitPreview.repaint(viewport: Instance, camoId: string)
	if viewport:IsA("ViewportFrame") then
		local spin = spinning[viewport]
		if spin then
			UnitPreview.paint(spin.model, camoId)
		end
	end
end

return UnitPreview
