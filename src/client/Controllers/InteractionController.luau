--!strict
-- Client side of the interaction system.
--
-- Lobby prompts use ProximityPromptStyle.Custom, so this draws their UI: a
-- small terminal-style plate above the station with the input glyph
-- (keyboard key, gamepad button image, or a tap target on touch), the
-- action and the station name, plus a hold bar for hold prompts. When a
-- prompt triggers, the station's kind is looked up in the shared
-- Interactions registry and the matching panel opens with that context.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
local Interactions = require(Lobby:WaitForChild("Interactions"))
local Signal = require(Lobby:WaitForChild("Util"):WaitForChild("Signal"))
local Kit = require(script.Parent.Parent.UI.Kit)
local Sound = require(script.Parent.Parent.UI.Sound)
local WindowManager = require(script.Parent.Parent.UI.WindowManager)

local UI = Kit.Colors

local InteractionController = {}

-- Fired on the client for every lobby interaction (kind, id, part).
InteractionController.triggered = Signal.new() :: Signal.Signal<string, string, BasePart?>

local plates: { [ProximityPrompt]: BillboardGui } = {}
local holdTweens: { [ProximityPrompt]: Tween } = {}

local function glyph(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): (string?, string?)
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local ok, image = pcall(function()
			return UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		end)
		if ok and type(image) == "string" and image ~= "" then
			return nil, image
		end
		return "X", nil
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP", nil
	end
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	end)
	return if ok and type(text) == "string" and text ~= "" then text else prompt.KeyboardKeyCode.Name, nil
end

local function buildPlate(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): BillboardGui?
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local player = Players.LocalPlayer
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local billboard: BillboardGui = Kit.new("BillboardGui", {
		Name = "LobbyPromptPlate",
		Adornee = part,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(280, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0),
		MaxDistance = prompt.MaxActivationDistance + 6,
		Active = true,
		ResetOnSpawn = false,
		ClipsDescendants = false,
	})
	local plate = Kit.frame(billboard, {
		Name = "Plate",
		BackgroundColor3 = UI.Background,
		BackgroundTransparency = 0.08,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
	})
	Kit.stroke(plate, UI.Border, 1)
	Kit.corner(plate, 3)
	Kit.frame(plate, { Name = "Accent", BackgroundColor3 = UI.Accent, Size = UDim2.new(0, 3, 1, 0) })
	-- input glyph
	local keyBox: TextButton = Kit.new("TextButton", {
		Name = "Key",
		AutoButtonColor = false,
		BackgroundColor3 = UI.PanelRaised,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(if touch then 56 else 40, 40),
		Text = "",
		FontFace = Kit.Fonts.MonoBold,
		TextSize = if touch then 14 else 20,
		TextColor3 = UI.Accent,
		Active = true,
		Parent = plate,
	})
	Kit.stroke(keyBox, UI.Accent, 1)
	Kit.corner(keyBox, 3)
	local text, image = glyph(prompt, inputType)
	if image then
		Kit.new("ImageLabel", {
			Name = "Glyph",
			BackgroundTransparency = 1,
			Image = image,
			Size = UDim2.fromScale(0.8, 0.8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = keyBox,
		})
	else
		keyBox.Text = text or ""
	end
	-- hold progress (only visible for hold prompts)
	local hold = Kit.frame(keyBox, {
		Name = "Hold",
		BackgroundColor3 = UI.Accent,
		BackgroundTransparency = 0.6,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 0,
	})
	hold.Visible = prompt.HoldDuration > 0
	local left = 12 + keyBox.Size.X.Offset + 12
	Kit.text(plate, {
		Name = "Action",
		Text = prompt.ActionText,
		FontFace = Kit.Fonts.Header,
		TextSize = 18,
		TextColor3 = UI.Text,
		Position = UDim2.fromOffset(left, 8),
		Size = UDim2.new(1, -(left + 10), 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.text(plate, {
		Name = "Object",
		Text = prompt.ObjectText,
		FontFace = Kit.Fonts.Mono,
		TextSize = 12,
		TextColor3 = UI.TextDim,
		Position = UDim2.fromOffset(left, 32),
		Size = UDim2.new(1, -(left + 10), 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	-- tapping / clicking the plate works like pressing the key
	do
		keyBox.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldBegin()
			end
		end)
		keyBox.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldEnd()
			end
		end)
	end
	billboard.Parent = player:WaitForChild("PlayerGui")
	-- pop in
	plate.Size = UDim2.fromScale(0.9, 0.9)
	TweenService:Create(plate, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 1) }):Play()
	return billboard
end

local function hide(prompt: ProximityPrompt)
	local plate = plates[prompt]
	if plate then
		plates[prompt] = nil
		plate:Destroy()
	end
	local t = holdTweens[prompt]
	if t then
		t:Cancel()
		holdTweens[prompt] = nil
	end
end

local function isLobbyPrompt(prompt: ProximityPrompt): boolean
	return prompt.Name == Interactions.PromptName and prompt.Style == Enum.ProximityPromptStyle.Custom
end

function InteractionController.contextFor(prompt: ProximityPrompt): (string?, WindowManager.Context?)
	local kind, id = Interactions.describe(prompt)
	if not kind then
		return nil, nil
	end
	local def = Interactions.Kinds[kind]
	if not def then
		return nil, nil
	end
	local part = prompt.Parent
	return def.Panel,
		{
			kind = kind,
			id = id,
			tab = def.Tab,
			part = if part and part:IsA("BasePart") then part else nil,
			range = prompt.MaxActivationDistance,
		}
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or not isLobbyPrompt(prompt) then
		return
	end
	local panel, context = InteractionController.contextFor(prompt)
	if not panel or not context then
		return
	end
	hide(prompt)
	InteractionController.triggered:Fire(context.kind or "", context.id or "", context.part)
	WindowManager.open(panel, context)
end

function InteractionController.start()
	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
			if not isLobbyPrompt(prompt) or WindowManager.isOpen() then
				return
			end
			hide(prompt)
			local plate = buildPlate(prompt, inputType)
			if plate then
				plates[prompt] = plate
			end
		end
	)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		hide(prompt)
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		local plate = plates[prompt]
		local hold = plate and plate:FindFirstChild("Hold", true)
		if hold and hold:IsA("Frame") and prompt.HoldDuration > 0 then
			hold.Size = UDim2.fromScale(0, 1)
			local t = TweenService:Create(hold, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
				Size = UDim2.fromScale(1, 1),
			})
			holdTweens[prompt] = t
			t:Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		local t = holdTweens[prompt]
		if t then
			t:Cancel()
			holdTweens[prompt] = nil
		end
		local plate = plates[prompt]
		local hold = plate and plate:FindFirstChild("Hold", true)
		if hold and hold:IsA("Frame") then
			hold.Size = UDim2.fromScale(0, 1)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	WindowManager.opened:Connect(function()
		for prompt in plates do
			hide(prompt)
		end
	end)
	Sound.preload()
end

return InteractionController
