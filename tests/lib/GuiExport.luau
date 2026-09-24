--!nocheck
-- Serialises Roblox GUI trees (SurfaceGui / ScreenGui) to JSON so
-- tools/render/gui.js can lay them out in a browser with Roblox rules.
-- Used for preview images only; this is an approximation of Roblox's GUI
-- renderer, not the engine.

local roblox = require("@lune/roblox")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local GuiExport = {}

local function safe(inst, prop, default)
	local ok, value = pcall(function()
		return inst[prop]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

local function udim2(u)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end

local function udim(u)
	return { u.Scale, u.Offset }
end

local function rgb(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function font(inst)
	local face = safe(inst, "FontFace", nil)
	if face then
		return { family = face.Family, weight = face.Weight.Name, style = face.Style.Name }
	end
	return { family = "rbxasset://fonts/families/SourceSansPro.json", weight = "Regular", style = "Normal" }
end

local function sequence(seq)
	local out = {}
	for _, kp in seq.Keypoints do
		local v = kp.Value
		if typeof(v) == "Color3" then
			table.insert(out, { kp.Time, rgb(v) })
		else
			table.insert(out, { kp.Time, v })
		end
	end
	return out
end

local MODIFIERS = {
	UICorner = function(inst)
		return { r = udim(inst.CornerRadius) }
	end,
	UIStroke = function(inst)
		return {
			color = rgb(inst.Color),
			thickness = inst.Thickness,
			transparency = inst.Transparency,
			mode = inst.ApplyStrokeMode.Name,
		}
	end,
	UIPadding = function(inst)
		return {
			l = udim(inst.PaddingLeft),
			r = udim(inst.PaddingRight),
			t = udim(inst.PaddingTop),
			b = udim(inst.PaddingBottom),
		}
	end,
	UIListLayout = function(inst)
		return {
			dir = inst.FillDirection.Name,
			pad = udim(inst.Padding),
			h = inst.HorizontalAlignment.Name,
			v = inst.VerticalAlignment.Name,
			sort = inst.SortOrder.Name,
			wraps = safe(inst, "Wraps", false),
		}
	end,
	UIGridLayout = function(inst)
		return {
			cell = udim2(inst.CellSize),
			pad = udim2(inst.CellPadding),
			dir = inst.FillDirection.Name,
			h = inst.HorizontalAlignment.Name,
			v = inst.VerticalAlignment.Name,
			sort = inst.SortOrder.Name,
		}
	end,
	UIAspectRatioConstraint = function(inst)
		return { ratio = inst.AspectRatio, kind = inst.AspectType.Name, axis = inst.DominantAxis.Name }
	end,
	UITextSizeConstraint = function(inst)
		return { max = inst.MaxTextSize, min = inst.MinTextSize }
	end,
	UISizeConstraint = function(inst)
		return { min = { inst.MinSize.X, inst.MinSize.Y }, max = { inst.MaxSize.X, inst.MaxSize.Y } }
	end,
	UIScale = function(inst)
		return { scale = inst.Scale }
	end,
	UIGradient = function(inst)
		return {
			color = sequence(inst.Color),
			transparency = sequence(inst.Transparency),
			rotation = inst.Rotation,
			offset = { inst.Offset.X, inst.Offset.Y },
			enabled = inst.Enabled,
		}
	end,
}

function GuiExport.node(inst)
	local class = inst.ClassName
	local modifier = MODIFIERS[class]
	if modifier then
		local ok, data = pcall(modifier, inst)
		if ok then
			data.c = class
			return data
		end
		return nil
	end
	if not inst:IsA("GuiBase2d") then
		return nil
	end
	local node = { c = class, n = inst.Name, kids = {} }
	if inst:IsA("GuiObject") then
		node.pos = udim2(inst.Position)
		node.size = udim2(inst.Size)
		node.anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y }
		node.rot = safe(inst, "Rotation", 0)
		node.bg = rgb(safe(inst, "BackgroundColor3", roblox.Color3.new(1, 1, 1)))
		node.bgT = safe(inst, "BackgroundTransparency", 0)
		node.border = safe(inst, "BorderSizePixel", 0)
		node.borderColor = rgb(safe(inst, "BorderColor3", roblox.Color3.fromRGB(27, 42, 53)))
		node.visible = safe(inst, "Visible", true)
		node.z = safe(inst, "ZIndex", 1)
		node.order = safe(inst, "LayoutOrder", 0)
		node.clip = safe(inst, "ClipsDescendants", false)
		node.auto = safe(inst, "AutomaticSize", roblox.Enum.AutomaticSize.None).Name
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			node.text = safe(inst, "Text", "")
			node.textColor = rgb(safe(inst, "TextColor3", roblox.Color3.new(0, 0, 0)))
			node.textT = safe(inst, "TextTransparency", 0)
			node.strokeColor = rgb(safe(inst, "TextStrokeColor3", roblox.Color3.new(0, 0, 0)))
			node.strokeT = safe(inst, "TextStrokeTransparency", 1)
			node.scaled = safe(inst, "TextScaled", false)
			node.textSize = safe(inst, "TextSize", 14)
			node.wrapped = safe(inst, "TextWrapped", false)
			node.xAlign = safe(inst, "TextXAlignment", roblox.Enum.TextXAlignment.Center).Name
			node.yAlign = safe(inst, "TextYAlignment", roblox.Enum.TextYAlignment.Center).Name
			node.rich = safe(inst, "RichText", false)
			node.lineHeight = safe(inst, "LineHeight", 1)
			node.font = font(inst)
		end
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			node.image = safe(inst, "Image", "")
			node.imageColor = rgb(safe(inst, "ImageColor3", roblox.Color3.new(1, 1, 1)))
			node.imageT = safe(inst, "ImageTransparency", 0)
		end
		if inst:IsA("CanvasGroup") then
			node.groupT = safe(inst, "GroupTransparency", 0)
		end
		if inst:IsA("ScrollingFrame") then
			node.canvas = udim2(safe(inst, "CanvasSize", roblox.UDim2.new()))
		end
	end
	for _, child in inst:GetChildren() do
		local childNode = GuiExport.node(child)
		if childNode then
			table.insert(node.kids, childNode)
		end
	end
	return node
end

-- Object-space basis of each face as seen by a reader facing it:
-- u = reader's right, up, n = outward normal.
local FACES = {
	Front = { u = Vector3.new(-1, 0, 0), up = Vector3.new(0, 1, 0), n = Vector3.new(0, 0, -1), dims = "XY" },
	Back = { u = Vector3.new(1, 0, 0), up = Vector3.new(0, 1, 0), n = Vector3.new(0, 0, 1), dims = "XY" },
	Right = { u = Vector3.new(0, 0, -1), up = Vector3.new(0, 1, 0), n = Vector3.new(1, 0, 0), dims = "ZY" },
	Left = { u = Vector3.new(0, 0, 1), up = Vector3.new(0, 1, 0), n = Vector3.new(-1, 0, 0), dims = "ZY" },
	Top = { u = Vector3.new(1, 0, 0), up = Vector3.new(0, 0, -1), n = Vector3.new(0, 1, 0), dims = "XZ" },
	Bottom = { u = Vector3.new(1, 0, 0), up = Vector3.new(0, 0, 1), n = Vector3.new(0, -1, 0), dims = "XZ" },
}

-- Every SurfaceGui under root with its world placement.
function GuiExport.surfaces(root)
	local out = {}
	for _, gui in root:GetDescendants() do
		if gui:IsA("SurfaceGui") then
			local part = gui.Parent
			if part and part:IsA("BasePart") then
				local face = FACES[gui.Face.Name]
				local size = part.Size
				local w = if face.dims == "ZY" then size.Z else size.X
				local h = if face.dims == "XZ" then size.Z else size.Y
				local depth = if face.dims == "XY" then size.Z else (if face.dims == "ZY" then size.X else size.Y)
				local offset = face.n * (depth / 2 + 0.03)
				local plane = part.CFrame * CFrame.fromMatrix(offset, face.u, face.up, face.n)
				local pps = safe(gui, "PixelsPerStud", 50)
				table.insert(out, {
					id = #out + 1,
					name = part:GetFullName(),
					w = w,
					h = h,
					px = { math.floor(w * pps + 0.5), math.floor(h * pps + 0.5) },
					c = { plane:GetComponents() },
					light = safe(gui, "LightInfluence", 1),
					tree = GuiExport.node(gui),
				})
			end
		end
	end
	return out
end

return GuiExport
